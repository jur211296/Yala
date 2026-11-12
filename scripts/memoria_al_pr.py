#!/usr/bin/env python3
"""La memoria de agente viaja con el PR de la sesión que la escribió.

Decisión de Jürgen del 9-nov-2026: la opción (a) de «Propuesta, no implementada» del ADR-095 de casa.
Al cerrar, una sesión de worktree lleva a su PR los cambios de `.claude/agent-memory/<agente>/`
que hizo ELLA, y nada de lo que escribió otra sesión viva del mismo agente.

Dos orígenes, porque se miden los dos:

- **El worktree.** Claude Code declara ahí la memoria de la sesión. El worktree y su índice son
  propios, así que todo cambio bajo la carpeta del agente es de esta sesión.
- **El checkout principal.** Llega cuando la sesión escribe con la ruta absoluta del principal, o
  mueve una nota allí a mano. Aquí sí hay que atribuir, y el criterio es el transcript de la
  propia sesión (`~/.claude/projects/<worktree codificado>/**/*.jsonl`):
    * prueba propia: un `Write`/`Edit`/`MultiEdit`/`NotebookEdit` a esa ruta, o un `Bash` que
      nombra la raíz del principal y el nombre de la nota con una operación que escribe;
    * duda: otra sesión activa desde que empezó ésta tiene la misma prueba sobre la nota, o el
      archivo cambió después de la última prueba propia, o la base trae otra versión.
  Lo dudoso no se copia ni se borra: se anota para el cuerpo del PR.
- **`MEMORY.md` va por líneas.** Una línea añadida al índice del principal se lleva si enlaza a
  una nota que esta sesión lleva y su transcript prueba que escribió esa línea.

Dos fases:

    python3 scripts/memoria_al_pr.py llevar [--seco]   # antes del push: copia y commitea
    python3 scripts/memoria_al_pr.py limpiar [--pr N]   # tras el push: deja limpio el principal

`limpiar` solo toca una ruta del principal cuando la rama remota ya tiene esa versión, y antes
deja respaldo en `~/Claude/flota/memoria-apartada/<repo>/`. Nunca usa `git stash`: la pila es
compartida por todos los worktrees.

Variables para las pruebas: MEMORIA_PROYECTOS_DIR (raíz de transcripts), MEMORIA_RESPALDO_DIR.
"""
from __future__ import annotations

import argparse
import datetime as dt
import difflib
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

INDICE = "MEMORY.md"
HERRAMIENTAS_QUE_ESCRIBEN = {"Write", "Edit", "MultiEdit", "NotebookEdit"}
# Operaciones de shell que escriben. Una redirección cuenta salvo `2>&1` o `>/dev/…`.
ESCRIBE_EN_BASH = re.compile(
    r"(^|[^0-9&>])>>?\s*(?!&|/dev/)|\bcp\b|\bmv\b|\btee\b|\binstall\b|\brsync\b|\bditto\b"
    r"|\btouch\b|\bsed\s+-i|\bperl\s+-\w*i|\bpython3?\b|\bln\b"
)
ENLACE = re.compile(r"\]\(([^)\s]+\.md)\)")
HOLGURA_S = 2.0


# ---------------------------------------------------------------------------------------- git
def git(args: list[str], cwd: Path, check: bool = True) -> str:
    r = subprocess.run(["git", *args], cwd=cwd, capture_output=True, text=True)
    if check and r.returncode != 0:
        raise RuntimeError(f"git {' '.join(args)}: {r.stderr.strip()}")
    return r.stdout


def blob_en(ref: str, rel: str, cwd: Path) -> str | None:
    out = git(["ls-tree", ref, "--", rel], cwd, check=False).split()
    return out[2] if len(out) >= 3 else None


def hash_de(ruta: Path) -> str | None:
    if not ruta.is_file():
        return None
    return git(["hash-object", "--no-filters", str(ruta)], ruta.parent).strip()


def sha_texto(texto: str) -> str:
    return hashlib.sha1(texto.encode()).hexdigest()[:12]


def sucios(repo: Path, carpeta: str) -> dict[str, str]:
    """{ruta relativa: XY} de `git status` bajo la carpeta, con los no versionados uno a uno."""
    out = git(["status", "--porcelain=v1", "-z", "-uall", "--", carpeta], repo)
    res: dict[str, str] = {}
    partes = out.split("\0")
    i = 0
    while i < len(partes):
        e = partes[i]
        i += 1
        if len(e) < 4:
            continue
        xy, rel = e[:2], e[3:]
        if "R" in xy or "C" in xy:
            i += 1  # el origen del renombrado viene en la entrada siguiente
        res[rel] = xy
    return res


# ---------------------------------------------------------------------------------- contexto
def contexto(desde: Path) -> dict | None:
    wt = Path(git(["rev-parse", "--show-toplevel"], desde).strip()).resolve()
    comun = Path(git(["rev-parse", "--path-format=absolute", "--git-common-dir"], wt).strip()).resolve()
    if comun == (wt / ".git").resolve():
        return None  # árbol principal: la memoria se commitea directo, no hay nada que llevar
    principal = comun.parent
    gitdir = Path(git(["rev-parse", "--path-format=absolute", "--git-dir"], wt).strip())
    return {"wt": wt, "principal": principal, "gitdir": gitdir}


def agentes(wt: Path, pedido: str | None) -> list[str]:
    if pedido:
        return [pedido]
    try:
        a = json.loads((wt / ".claude" / "settings.json").read_text()).get("agent")
        if a:
            return [a]
    except (OSError, ValueError):
        pass
    base = wt / ".claude" / "agent-memory"
    return sorted(p.name for p in base.iterdir() if p.is_dir()) if base.is_dir() else []


def codificar(ruta: Path) -> str:
    return re.sub(r"[^A-Za-z0-9]", "-", str(ruta))


def proyectos_dir() -> Path:
    return Path(os.environ.get("MEMORIA_PROYECTOS_DIR", Path.home() / ".claude" / "projects"))


def respaldo_dir(principal: Path) -> Path:
    base = os.environ.get("MEMORIA_RESPALDO_DIR")
    raiz = Path(base) if base else Path.home() / "Claude" / "flota" / "memoria-apartada"
    return raiz / principal.name


# ------------------------------------------------------------------------------- transcripts
def _ts(s: str | None) -> float | None:
    if not s:
        return None
    try:
        return dt.datetime.fromisoformat(s.replace("Z", "+00:00")).timestamp()
    except ValueError:
        return None


def eventos(archivo: Path) -> list[dict]:
    """Cada herramienta usada en un transcript, con su hora y la hora de su resultado."""
    usos: dict[str, dict] = {}
    resultados: dict[str, float] = {}
    try:
        lineas = archivo.read_text(errors="replace").splitlines()
    except OSError:
        return []
    for linea in lineas:
        try:
            o = json.loads(linea)
        except ValueError:
            continue
        m = o.get("message")
        if not isinstance(m, dict) or not isinstance(m.get("content"), list):
            continue
        t = _ts(o.get("timestamp"))
        for b in m["content"]:
            if not isinstance(b, dict):
                continue
            if b.get("type") == "tool_use" and b.get("id") and b["id"] not in usos and t is not None:
                usos[b["id"]] = {"nombre": b.get("name"), "entrada": b.get("input") or {},
                                 "t": t, "cwd": o.get("cwd") or ""}
            elif b.get("type") == "tool_result" and b.get("tool_use_id") and t is not None:
                resultados.setdefault(b["tool_use_id"], t)
    for k, u in usos.items():
        u["t_fin"] = resultados.get(k, u["t"])
    return list(usos.values())


def escribe(ev: dict, ruta: Path, principal: Path, en_texto: str | None = None) -> bool:
    """¿Este evento escribió `ruta` (del principal)? `en_texto` exige además ese texto en la entrada."""
    entrada = ev["entrada"]
    if en_texto and en_texto not in json.dumps(entrada, ensure_ascii=False):
        return False
    if ev["nombre"] in HERRAMIENTAS_QUE_ESCRIBEN:
        fp = entrada.get("file_path") or entrada.get("notebook_path") or ""
        return bool(fp) and os.path.realpath(fp) == str(ruta)
    if ev["nombre"] == "Bash":
        cmd = entrada.get("command") or ""
        en_principal = f"{principal}/" in cmd or os.path.realpath(ev["cwd"] or "/") == str(principal)
        return en_principal and ruta.name in cmd and bool(ESCRIBE_EN_BASH.search(cmd))
    return False


def cargar_transcripts(wt: Path) -> tuple[list[dict], list[tuple[Path, list[dict]]], float | None, Path]:
    raiz = proyectos_dir()
    propio_dir = raiz / codificar(wt)
    propios = sorted(propio_dir.rglob("*.jsonl")) if propio_dir.is_dir() else []
    mios = [e for f in propios for e in eventos(f)]
    inicio = min((e["t"] for e in mios), default=None)
    otros: list[tuple[Path, list[dict]]] = []
    if inicio is not None and raiz.is_dir():
        for f in raiz.rglob("*.jsonl"):
            if propio_dir in f.parents:
                continue
            try:
                if f.stat().st_mtime < inicio:
                    continue
            except OSError:
                continue
            otros.append((f, eventos(f)))
    return mios, otros, inicio, propio_dir


# ------------------------------------------------------------------------------------- plan
def planificar(ctx: dict, agente: str, base: str | None = None) -> dict:
    wt, principal = ctx["wt"], ctx["principal"]
    carpeta = f".claude/agent-memory/{agente}/"
    indice_rel = carpeta + INDICE
    mios, otros, inicio, propio_dir = cargar_transcripts(wt)

    plan = {"agente": agente, "carpeta": carpeta, "worktree": str(wt), "principal": str(principal),
            "transcripts": str(propio_dir), "notas": [], "lineas": [], "dudas": [], "ajenas": [],
            "del_worktree": [], "en_rama": []}

    # 1 · Lo del worktree: de esta sesión por construcción.
    sucio_wt = sucios(wt, carpeta)
    plan["del_worktree"] = sorted(sucio_wt)
    # Y lo que la rama ya lleva respecto de su base: un segundo `llevar` lo tiene que seguir contando.
    base = base or "origin/HEAD"
    corte = git(["merge-base", "HEAD", base], wt, check=False).strip()
    if corte:
        plan["en_rama"] = sorted(set(git(["diff", "--name-only", f"{corte}..HEAD", "--", carpeta], wt).split()))

    # 2 · Lo del principal: se atribuye por el transcript.
    sucio_pr = sucios(principal, carpeta)
    llevadas: set[str] = {Path(r).name for r in sucio_wt if not r.endswith(INDICE)}
    for rel, xy in sorted(sucio_pr.items()):
        if rel == indice_rel:
            continue
        ruta = principal / rel
        if xy not in ("??", " M", "M ", "MM", "A ", "AM"):
            plan["ajenas"].append(rel)
            continue
        if inicio is None:
            plan["dudas"].append({"ruta": rel, "motivo": "no se encontró el transcript de esta sesión"})
            continue
        pruebas = [e for e in mios if escribe(e, ruta, principal)]
        if not pruebas:
            plan["ajenas"].append(rel)
            continue
        ajenos = [f.name for f, evs in otros if any(escribe(e, ruta, principal) for e in evs)]
        if ajenos:
            plan["dudas"].append({"ruta": rel, "motivo": f"otra sesión también la escribió ({ajenos[0]})"})
            continue
        ultima = max(e["t_fin"] for e in pruebas)
        if ruta.stat().st_mtime > ultima + HOLGURA_S:
            plan["dudas"].append({"ruta": rel, "motivo": "cambió después de la última escritura de esta sesión"})
            continue
        if xy[0] in "MA":
            plan["dudas"].append({"ruta": rel, "motivo": "está preparada en el índice del principal"})
            continue
        h = hash_de(ruta)
        base_wt = blob_en("HEAD", rel, wt)
        base_pr = blob_en("HEAD", rel, principal)
        en_wt = hash_de(wt / rel)
        if rel in sucio_wt:
            accion = "ya-en-worktree" if en_wt == h else None
        elif base_wt == base_pr:
            accion = "copiar"
        elif base_wt == h:
            accion = "ya-en-base"
        else:
            accion = None
        if accion is None:
            plan["dudas"].append({"ruta": rel, "motivo": "el worktree o la base traen otra versión"})
            continue
        plan["notas"].append({"ruta": rel, "accion": accion, "hash": h})
        llevadas.add(ruta.name)

    # 3 · Las líneas del índice del principal.
    if indice_rel in sucio_pr and sucio_pr[indice_rel] in ("??", " M"):
        idx = principal / indice_rel
        base = git(["show", f"HEAD:{indice_rel}"], principal, check=False).splitlines() \
            if blob_en("HEAD", indice_rel, principal) else []
        actual = idx.read_text().splitlines()
        sm = difflib.SequenceMatcher(a=base, b=actual, autojunk=False)
        nuevas = [j for op, _a1, _a2, b1, b2 in sm.get_opcodes() if op in ("insert", "replace")
                  for j in range(b1, b2)]
        for j in nuevas:
            linea = actual[j]
            enlaces = {Path(x).name for x in ENLACE.findall(linea)}
            if not enlaces & llevadas:
                continue
            nota = sorted(enlaces & llevadas)[0]
            propia = any(escribe(e, idx, principal, nota) for e in mios)
            ajena = any(escribe(e, idx, principal, nota) for _f, evs in otros for e in evs)
            if propia and not ajena:
                # El ancla es la línea de la base más cercana por encima: la que el worktree también tiene.
                ancla = next((actual[k] for k in range(j - 1, -1, -1) if k not in nuevas), None)
                plan["lineas"].append({"linea": linea, "ancla": ancla})
            else:
                motivo = ("otra sesión también la escribió" if ajena
                          else "el transcript no prueba que la escribió esta sesión")
                plan["dudas"].append({"ruta": indice_rel, "motivo": f"línea de «{nota}»: {motivo}"})
    elif indice_rel in sucio_pr:
        plan["dudas"].append({"ruta": indice_rel, "motivo": f"estado {sucio_pr[indice_rel]!r} en el principal"})
    return plan


# ------------------------------------------------------------------------------------ llevar
def insertar_lineas(destino: Path, lineas: list[dict]) -> int:
    texto = destino.read_text() if destino.exists() else ""
    filas = texto.splitlines()
    puestas = 0
    for item in lineas:
        if item["linea"] in filas:
            continue
        ancla = item.get("ancla")
        if ancla is not None and ancla in filas:
            filas.insert(filas.index(ancla) + 1 + _consecutivas(filas, filas.index(ancla), lineas), item["linea"])
        else:
            filas.append(item["linea"])
        puestas += 1
    destino.parent.mkdir(parents=True, exist_ok=True)
    destino.write_text("\n".join(filas) + "\n")
    return puestas


def _consecutivas(filas: list[str], i: int, lineas: list[dict]) -> int:
    """Cuántas líneas ya insertadas siguen al ancla, para mantener el orden entre ellas."""
    propias = {x["linea"] for x in lineas}
    n = 0
    while i + 1 + n < len(filas) and filas[i + 1 + n] in propias:
        n += 1
    return n


def respaldar(plan: dict, principal: Path) -> Path:
    hora = dt.datetime.now().strftime("%Y%m%d-%H%M%S")
    destino = respaldo_dir(principal) / f"{hora}-cierre-{Path(plan['worktree']).name}"
    rutas = [n["ruta"] for n in plan["notas"]]
    if plan["lineas"]:
        rutas.append(plan["carpeta"] + INDICE)
    for rel in rutas:
        src = principal / rel
        if src.is_file():
            (destino / rel).parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(src, destino / rel)
    destino.mkdir(parents=True, exist_ok=True)
    (destino / "plan.json").write_text(json.dumps(plan, ensure_ascii=False, indent=2))
    return destino


def llevar(ctx: dict, agente: str, seco: bool, base: str | None = None) -> dict:
    plan = planificar(ctx, agente, base)
    wt, principal = ctx["wt"], ctx["principal"]
    plan["commit"] = None
    if seco:
        return plan
    if plan["notas"] or plan["lineas"]:
        plan["respaldo"] = str(respaldar(plan, principal))
    for n in plan["notas"]:
        if n["accion"] == "copiar":
            (wt / n["ruta"]).parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(principal / n["ruta"], wt / n["ruta"])
    if plan["lineas"]:
        insertar_lineas(wt / plan["carpeta"] / INDICE, plan["lineas"])
    if (wt / plan["carpeta"]).is_dir():
        git(["add", "-A", "--", plan["carpeta"]], wt)
    preparado = git(["diff", "--cached", "--name-only", "--", plan["carpeta"]], wt).split()
    if preparado:
        n = len(preparado)
        cuerpo = (f"Lleva al PR {n} cambio(s) de la memoria de {agente} que hizo esta sesión, "
                  "con el criterio de scripts/memoria_al_pr.py.")
        git(["commit", "--only", "-m", f"chore(memoria): notas de {agente} de esta sesión",
             "-m", cuerpo, "--", plan["carpeta"]], wt)
        plan["commit"] = git(["rev-parse", "HEAD"], wt).strip()
    (ctx["gitdir"] / f"memoria-al-pr-{agente}.json").write_text(json.dumps(plan, ensure_ascii=False, indent=2))
    return plan


# ----------------------------------------------------------------------------------- limpiar
def limpiar(ctx: dict, agente: str) -> dict:
    wt, principal = ctx["wt"], ctx["principal"]
    estado = ctx["gitdir"] / f"memoria-al-pr-{agente}.json"
    res = {"limpias": [], "lineas_quitadas": 0, "dudas": [], "respaldo": None}
    if not estado.exists():
        return res
    plan = json.loads(estado.read_text())
    res["respaldo"] = plan.get("respaldo")
    # Se mide contra la rama del PR en el remoto, no contra @{u}: una rama de encargo nace con
    # @{u} = origin/<base>, y la base no tiene lo que acaba de llevarse.
    rama = git(["symbolic-ref", "--short", "HEAD"], wt, check=False).strip()
    remota = f"origin/{rama}"
    git(["fetch", "--quiet", "origin", f"+refs/heads/{rama}:refs/remotes/{remota}"], wt, check=False)
    if not rama or not git(["rev-parse", "--verify", "--quiet", remota], wt, check=False).strip():
        res["dudas"].append({"ruta": plan["carpeta"], "motivo": "la rama no está en el remoto: haz push antes de limpiar"})
        return res

    for n in plan["notas"]:
        rel, ruta = n["ruta"], principal / n["ruta"]
        if not ruta.exists():
            continue
        if hash_de(ruta) != n["hash"]:
            res["dudas"].append({"ruta": rel, "motivo": "cambió en el principal después de llevarla; se queda"})
            continue
        if blob_en(remota, rel, wt) != n["hash"]:
            res["dudas"].append({"ruta": rel, "motivo": "la rama remota no tiene esta versión; se queda"})
            continue
        if blob_en("HEAD", rel, principal):
            git(["restore", "--source=HEAD", "--worktree", "--", rel], principal)
        else:
            ruta.unlink()
        res["limpias"].append(rel)

    if plan["lineas"]:
        rel = plan["carpeta"] + INDICE
        idx = principal / rel
        remoto = git(["show", f"{remota}:{rel}"], wt, check=False).splitlines()
        filas = idx.read_text().splitlines() if idx.exists() else []
        for item in plan["lineas"]:
            if item["linea"] not in remoto:
                res["dudas"].append({"ruta": rel, "motivo": "una línea del índice no llegó a la rama remota; se queda"})
                continue
            if item["linea"] in filas:
                filas.remove(item["linea"])
                res["lineas_quitadas"] += 1
        if res["lineas_quitadas"]:
            nuevo = "\n".join(filas) + ("\n" if filas else "")
            base = git(["show", f"HEAD:{rel}"], principal, check=False) if blob_en("HEAD", rel, principal) else None
            if base is not None and nuevo.rstrip("\n") == base.rstrip("\n"):
                git(["restore", "--source=HEAD", "--worktree", "--", rel], principal)
            else:
                tmp = idx.with_name(idx.name + ".memoria-al-pr")
                tmp.write_text(nuevo)
                os.replace(tmp, idx)
    if not res["dudas"]:
        estado.rename(estado.with_suffix(".hecho.json"))  # con dudas se conserva: un segundo limpiar reintenta
    return res


# ----------------------------------------------------------------------------------- informe
def seccion_pr(plan: dict) -> str:
    a = plan["agente"]
    out = [f"## Memoria de {a}", ""]
    llevadas = [n["ruta"] for n in plan["notas"]]
    del_principal = set(llevadas)
    wt = [r for r in plan["del_worktree"] if r not in del_principal]
    ya = [r for r in plan.get("en_rama", []) if r not in del_principal and r not in wt]
    if not (llevadas or wt or ya or plan["lineas"]):
        out.append("Esta sesión no tocó notas de memoria: no viaja ninguna.")
    else:
        out.append("Viajan en este PR, y solo porque las escribió esta sesión:")
        for r in ya:
            out.append(f"- `{r}` (ya commiteada en la rama)")
        for r in wt:
            out.append(f"- `{r}` (escrita en el worktree)")
        for n in plan["notas"]:
            extra = {"copiar": "", "ya-en-base": ", ya commiteada en la rama",
                     "ya-en-worktree": ", también escrita en el worktree"}[n["accion"]]
            out.append(f"- `{n['ruta']}` (estaba en el checkout principal{extra})")
        if plan["lineas"]:
            out.append(f"- {len(plan['lineas'])} línea(s) del índice `{INDICE}` que enlazan a esas notas")
    out += ["", "**Criterio.** Lo del worktree es de la sesión por construcción. Lo del checkout "
            "principal se atribuye por el transcript de la sesión: una escritura propia a esa ruta, "
            "sin escritura de otra sesión activa y sin cambios posteriores."]
    if plan["dudas"]:
        out += ["", "**En duda, sin copiar ni borrar** (se quedan como están en el checkout principal):"]
        out += [f"- `{d['ruta']}`: {d['motivo']}" for d in plan["dudas"]]
    if plan["ajenas"]:
        out += ["", f"Se quedan en el principal, sin prueba de esta sesión: {len(plan['ajenas'])} nota(s) "
                "de otras sesiones."]
    if plan.get("respaldo"):
        out += ["", f"**Si algo falla:** la copia de lo que se llevó del principal está en `{plan['respaldo']}`; "
                "se recupera copiándola de vuelta a su ruta. La rama del PR también la guarda."]
    return "\n".join(out)


def informe_limpieza(res: dict) -> str:
    out = [f"Checkout principal: {len(res['limpias'])} nota(s) devueltas a limpio, "
           f"{res['lineas_quitadas']} línea(s) del índice quitadas."]
    for d in res["dudas"]:
        out.append(f"- En duda, se queda: `{d['ruta']}`: {d['motivo']}")
    if res.get("respaldo"):
        out.append(f"Respaldo: `{res['respaldo']}`")
    return "\n".join(out)


def anexar_al_pr(pr: str, texto: str, cwd: Path) -> None:
    r = subprocess.run(["gh", "pr", "view", pr, "--json", "body", "--jq", ".body"],
                       cwd=cwd, capture_output=True, text=True)
    if r.returncode != 0:
        print(f"aviso: no pude leer el PR {pr}: {r.stderr.strip()}", file=sys.stderr)
        return
    cuerpo = r.stdout.rstrip("\n") + "\n\n### Memoria: limpieza del checkout principal\n\n" + texto + "\n"
    subprocess.run(["gh", "pr", "edit", pr, "--body", cuerpo], cwd=cwd, check=False)


# -------------------------------------------------------------------------------------- main
def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    p.add_argument("fase", choices=["llevar", "limpiar"])
    p.add_argument("--agente")
    p.add_argument("--seco", action="store_true", help="llevar: muestra el plan sin tocar nada")
    p.add_argument("--json", action="store_true", help="salida en JSON")
    p.add_argument("--pr", help="limpiar: añade el resultado al cuerpo de este PR")
    p.add_argument("--base", help="llevar: rama base del PR (por defecto, origin/HEAD)")
    a = p.parse_args(argv)

    ctx = contexto(Path.cwd())
    if ctx is None:
        print("No es un worktree: en el árbol principal la memoria se commitea directo. Nada que llevar.")
        return 0
    salida = []
    for ag in agentes(ctx["wt"], a.agente):
        if a.fase == "llevar":
            plan = llevar(ctx, ag, a.seco, a.base)
            salida.append(plan if a.json else seccion_pr(plan) + (
                f"\n\nCommit: {plan['commit']}" if plan.get("commit") else ""))
        else:
            res = limpiar(ctx, ag)
            texto = informe_limpieza(res)
            if a.pr:
                anexar_al_pr(a.pr, texto, ctx["wt"])
            salida.append(res if a.json else texto)
    print(json.dumps(salida, ensure_ascii=False, indent=2) if a.json else "\n\n".join(salida))
    return 0


if __name__ == "__main__":
    sys.exit(main())
