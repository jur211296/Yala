#!/usr/bin/env python3
"""Banco de scripts/memoria_al_pr.py. Trabaja en repos temporales; no toca el árbol ni ~/.claude.

Monta un remoto desnudo, un checkout principal y un worktree, y escribe transcripts sintéticos con
el formato de Claude Code. Cada caso es una situación medida en la flota.

Uso: python3 scripts/memoria_al_pr_test.py
"""
from __future__ import annotations

import datetime as dt
import json
import os
import subprocess
import sys
import tempfile
import time
import unittest
from pathlib import Path

AQUI = Path(__file__).resolve().parent
sys.path.insert(0, str(AQUI))
import memoria_al_pr as m  # noqa: E402

CARPETA = ".claude/agent-memory/frank/"
INDICE_BASE = "# Memoria de Frank — Yala\n\n## Cómo trabaja Jürgen\n- [Vieja](feedback_vieja.md) — una nota de la base\n"


def sh(args, cwd):
    r = subprocess.run(args, cwd=cwd, capture_output=True, text=True)
    if r.returncode != 0:
        raise AssertionError(f"{args}: {r.stderr}")
    return r.stdout


def iso(t: float) -> str:
    return dt.datetime.fromtimestamp(t, dt.timezone.utc).isoformat().replace("+00:00", "Z")


class Transcript:
    """Escribe un JSONL como los de ~/.claude/projects: tool_use del asistente y su tool_result."""

    def __init__(self, raiz: Path, cwd: Path, nombre: str = "s.jsonl"):
        self.dir = raiz / m.codificar(cwd)
        self.dir.mkdir(parents=True, exist_ok=True)
        self.f = self.dir / nombre
        self.cwd = str(cwd)
        self.n = 0
        self.t = time.time() - 120

    def uso(self, nombre: str, entrada: dict, t: float | None = None):
        self.n += 1
        t = self.t if t is None else t
        self.t = t + 1
        tid = f"toolu_{self.n}_{self.f.stem}"
        with self.f.open("a") as fh:
            fh.write(json.dumps({"type": "assistant", "timestamp": iso(t), "cwd": self.cwd, "message": {
                "content": [{"type": "tool_use", "id": tid, "name": nombre, "input": entrada}]}}) + "\n")
            fh.write(json.dumps({"type": "user", "timestamp": iso(t + 0.5), "cwd": self.cwd, "message": {
                "content": [{"type": "tool_result", "tool_use_id": tid, "content": "ok"}]}}) + "\n")

    def ahora(self):
        self.t = time.time()


class Banco(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp()).resolve()
        self.env_antes = dict(os.environ)
        os.environ.update({
            "GIT_CONFIG_GLOBAL": str(self.tmp / "gitconfig"), "GIT_CONFIG_NOSYSTEM": "1",
            "GIT_AUTHOR_NAME": "t", "GIT_AUTHOR_EMAIL": "t@t", "GIT_COMMITTER_NAME": "t",
            "GIT_COMMITTER_EMAIL": "t@t",
            "MEMORIA_PROYECTOS_DIR": str(self.tmp / "proyectos"),
            "MEMORIA_RESPALDO_DIR": str(self.tmp / "respaldo"),
        })
        (self.tmp / "gitconfig").write_text("")
        self.origen = self.tmp / "origen.git"
        sh(["git", "init", "-q", "--bare", "-b", "2.2", str(self.origen)], self.tmp)
        self.pr = self.tmp / "Yala"
        sh(["git", "clone", "-q", str(self.origen), str(self.pr)], self.tmp)
        sh(["git", "checkout", "-q", "-b", "2.2"], self.pr)
        (self.pr / CARPETA).mkdir(parents=True)
        (self.pr / CARPETA / "MEMORY.md").write_text(INDICE_BASE)
        (self.pr / CARPETA / "feedback_vieja.md").write_text("vieja\n")
        (self.pr / ".claude" / "settings.json").write_text(json.dumps({"agent": "frank"}))
        sh(["git", "add", "-A"], self.pr)
        sh(["git", "commit", "-q", "-m", "base"], self.pr)
        sh(["git", "push", "-q", "-u", "origin", "2.2"], self.pr)
        self.wt = self.tmp / "worktrees" / "Yala-encargo"
        sh(["git", "worktree", "add", "-q", "-b", "encargo/x", str(self.wt), "origin/2.2"], self.pr)
        self.proyectos = self.tmp / "proyectos"
        self.yo = Transcript(self.proyectos, self.wt)
        self.yo.uso("Bash", {"command": "git status"})  # el arranque de la sesión

    def tearDown(self):
        os.environ.clear()
        os.environ.update(self.env_antes)
        subprocess.run(["rm", "-rf", str(self.tmp)])

    # -------------------------------------------------------------------------------- ayudas
    def ctx(self):
        return m.contexto(self.wt)

    def nota_en_principal(self, nombre: str, texto: str, quien: Transcript, linea: str | None = None):
        ruta = self.pr / CARPETA / nombre
        ruta.write_text(texto)
        quien.ahora()
        quien.uso("Write", {"file_path": str(ruta), "content": texto})
        if linea:
            idx = self.pr / CARPETA / "MEMORY.md"
            with idx.open("a") as fh:
                fh.write(linea + "\n")
            quien.uso("Bash", {"command": f"printf '%s\\n' '{linea}' >> {idx}"})

    def push(self):
        sh(["git", "push", "-q", "-u", "origin", "encargo/x"], self.wt)

    def estado_principal(self) -> str:
        return sh(["git", "status", "--porcelain", "-uall", "--", CARPETA], self.pr)

    def en_commit(self) -> list[str]:
        return sh(["git", "diff", "--name-only", "origin/2.2..HEAD"], self.wt).split()

    # -------------------------------------------------------------------------------- casos
    def test_1_sesion_que_toco_notas(self):
        """Nota en el principal + su línea del índice + otra escrita en el worktree: viajan las tres."""
        self.nota_en_principal("feedback_a.md", "a\n", self.yo, "- [A](feedback_a.md) — nota A")
        (self.wt / CARPETA / "feedback_wt.md").write_text("wt\n")
        plan = m.llevar(self.ctx(), "frank", seco=False)
        self.assertEqual(plan["dudas"], [])
        self.assertIsNotNone(plan["commit"])
        self.assertEqual(sorted(self.en_commit()),
                         sorted([CARPETA + "MEMORY.md", CARPETA + "feedback_a.md", CARPETA + "feedback_wt.md"]))
        idx_wt = (self.wt / CARPETA / "MEMORY.md").read_text()
        self.assertIn("- [A](feedback_a.md) — nota A", idx_wt)
        self.assertTrue(idx_wt.startswith(INDICE_BASE))
        # Sin push, limpiar no toca nada: la rama remota no tiene la nota.
        res = m.limpiar(self.ctx(), "frank")
        self.assertTrue(res["dudas"])
        self.assertTrue((self.pr / CARPETA / "feedback_a.md").exists())
        self.assertIn("- [A](feedback_a.md) — nota A", (self.pr / CARPETA / "MEMORY.md").read_text())
        # Con push, el principal vuelve a limpio en esas rutas y queda respaldo.
        m.llevar(self.ctx(), "frank", seco=False)  # idempotente: no hay segundo commit
        self.assertEqual(len(sh(["git", "rev-list", "origin/2.2..HEAD"], self.wt).split()), 1)
        self.push()
        res = m.limpiar(self.ctx(), "frank")
        self.assertEqual(res["dudas"], [])
        self.assertEqual(self.estado_principal(), "")
        respaldo = Path(res["respaldo"])
        self.assertEqual((respaldo / CARPETA / "feedback_a.md").read_text(), "a\n")
        self.assertTrue((respaldo / "plan.json").exists())

    def test_2_sesion_sin_notas(self):
        """No tocó memoria: ni commit ni cambios; la nota suelta de otro se queda como estaba."""
        ajena = self.pr / CARPETA / "feedback_huerfana.md"
        ajena.write_text("de una sesión ya retirada\n")
        self.yo.uso("Bash", {"command": f"ls {self.pr}/{CARPETA}"})
        antes = self.estado_principal()
        plan = m.llevar(self.ctx(), "frank", seco=False)
        self.assertIsNone(plan["commit"])
        self.assertEqual(plan["notas"], [])
        self.assertEqual(plan["ajenas"], [CARPETA + "feedback_huerfana.md"])
        self.assertIn("no tocó notas", m.seccion_pr(plan))
        self.push()
        m.limpiar(self.ctx(), "frank")
        self.assertEqual(self.estado_principal(), antes)
        self.assertEqual(ajena.read_text(), "de una sesión ya retirada\n")

    def test_3_dos_sesiones_del_mismo_agente(self):
        """Otra sesión viva escribió B en el mismo principal: solo viaja A, y B sigue intacta."""
        otra_wt = self.tmp / "worktrees" / "Yala-otro"
        otra = Transcript(self.proyectos, otra_wt)
        self.nota_en_principal("feedback_a.md", "a\n", self.yo, "- [A](feedback_a.md) — nota A")
        self.nota_en_principal("feedback_b.md", "b\n", otra, "- [B](feedback_b.md) — nota B")
        idx_antes = (self.pr / CARPETA / "MEMORY.md").read_text()
        plan = m.llevar(self.ctx(), "frank", seco=False)
        self.assertEqual([n["ruta"] for n in plan["notas"]], [CARPETA + "feedback_a.md"])
        self.assertEqual([x["linea"] for x in plan["lineas"]], ["- [A](feedback_a.md) — nota A"])
        self.assertNotIn(CARPETA + "feedback_b.md", self.en_commit())
        self.assertNotIn("feedback_b.md", (self.wt / CARPETA / "MEMORY.md").read_text())
        self.push()
        m.limpiar(self.ctx(), "frank")
        self.assertFalse((self.pr / CARPETA / "feedback_a.md").exists())
        self.assertEqual((self.pr / CARPETA / "feedback_b.md").read_text(), "b\n")
        idx = (self.pr / CARPETA / "MEMORY.md").read_text()
        self.assertEqual(idx, idx_antes.replace("- [A](feedback_a.md) — nota A\n", ""))
        self.assertIn("- [B](feedback_b.md) — nota B", idx)

    def test_4_nota_escrita_por_las_dos_sesiones_es_duda(self):
        otra = Transcript(self.proyectos, self.tmp / "worktrees" / "Yala-otro")
        self.nota_en_principal("feedback_c.md", "c\n", self.yo)
        self.nota_en_principal("feedback_c.md", "c de la otra\n", otra)
        plan = m.llevar(self.ctx(), "frank", seco=False)
        self.assertEqual(plan["notas"], [])
        self.assertEqual([d["ruta"] for d in plan["dudas"]], [CARPETA + "feedback_c.md"])
        self.assertIn("En duda", m.seccion_pr(plan))
        self.push()
        m.limpiar(self.ctx(), "frank")
        self.assertEqual((self.pr / CARPETA / "feedback_c.md").read_text(), "c de la otra\n")

    def test_5_cambio_posterior_a_la_ultima_escritura_es_duda(self):
        self.nota_en_principal("feedback_d.md", "d\n", self.yo)
        ruta = self.pr / CARPETA / "feedback_d.md"
        futuro = time.time() + 60
        os.utime(ruta, (futuro, futuro))
        plan = m.llevar(self.ctx(), "frank", seco=False)
        self.assertEqual(plan["notas"], [])
        self.assertIn("cambió después", plan["dudas"][0]["motivo"])

    def test_6_leer_una_nota_no_es_escribirla(self):
        ajena = self.pr / CARPETA / "feedback_e.md"
        ajena.write_text("e\n")
        self.yo.ahora()
        self.yo.uso("Bash", {"command": f"cat {ajena} 2>/dev/null | head"})
        self.yo.uso("Read", {"file_path": str(ajena)})
        plan = m.llevar(self.ctx(), "frank", seco=True)
        self.assertEqual(plan["notas"], [])
        self.assertEqual(plan["ajenas"], [CARPETA + "feedback_e.md"])

    def test_7_movida_a_mano_desde_el_worktree(self):
        """El patrón medido el 6-nov: escribir en el worktree, `cp` al principal con variable y `rm`."""
        nombre = "reference_movida.md"
        (self.pr / CARPETA / nombre).write_text("movida\n")
        idx = self.pr / CARPETA / "MEMORY.md"
        linea = f"- [Movida]({nombre}) — se movió a mano"
        with idx.open("a") as fh:
            fh.write(linea + "\n")
        self.yo.ahora()
        self.yo.uso("Bash", {"command": f"F={CARPETA}{nombre}; cp $F {self.pr}/$F && printf '%s\\n' "
                                        f"'{linea}' >> {idx} && rm $F"})
        plan = m.llevar(self.ctx(), "frank", seco=False)
        self.assertEqual([n["ruta"] for n in plan["notas"]], [CARPETA + nombre])
        self.assertEqual(len(plan["lineas"]), 1)
        self.push()
        m.limpiar(self.ctx(), "frank")
        self.assertEqual(self.estado_principal(), "")

    def test_9_linea_del_indice_sin_prueba_se_queda(self):
        """La nota es mía, pero su línea del índice no la escribió esta sesión: la línea no viaja."""
        self.nota_en_principal("feedback_f.md", "f\n", self.yo)
        with (self.pr / CARPETA / "MEMORY.md").open("a") as fh:
            fh.write("- [F](feedback_f.md) — la puso otro\n")
        plan = m.llevar(self.ctx(), "frank", seco=False)
        self.assertEqual([n["ruta"] for n in plan["notas"]], [CARPETA + "feedback_f.md"])
        self.assertEqual(plan["lineas"], [])
        self.assertIn("no prueba", plan["dudas"][0]["motivo"])
        self.push()
        m.limpiar(self.ctx(), "frank")
        self.assertIn("la puso otro", (self.pr / CARPETA / "MEMORY.md").read_text())

    def test_10_cambio_en_el_principal_entre_llevar_y_limpiar(self):
        """Otra mano edita la nota después de llevarla: limpiar no la borra."""
        self.nota_en_principal("feedback_g.md", "g\n", self.yo)
        m.llevar(self.ctx(), "frank", seco=False)
        self.push()
        (self.pr / CARPETA / "feedback_g.md").write_text("g editada después\n")
        res = m.limpiar(self.ctx(), "frank")
        self.assertEqual((self.pr / CARPETA / "feedback_g.md").read_text(), "g editada después\n")
        self.assertIn("cambió en el principal", res["dudas"][0]["motivo"])

    def test_11_la_base_trae_otra_version(self):
        """La sesión editó una nota versionada en el principal, pero su rama ya trae otra: duda."""
        (self.wt / CARPETA / "feedback_vieja.md").write_text("vieja, versión nueva de la base\n")
        sh(["git", "commit", "-q", "-am", "la base avanzó"], self.wt)
        self.nota_en_principal("feedback_vieja.md", "vieja, editada en el principal\n", self.yo)
        plan = m.llevar(self.ctx(), "frank", seco=False)
        self.assertEqual(plan["notas"], [])
        self.assertIn("otra versión", plan["dudas"][0]["motivo"])
        self.assertEqual((self.wt / CARPETA / "feedback_vieja.md").read_text(), "vieja, versión nueva de la base\n")

    def test_12_versionada_editada_vuelve_a_head(self):
        """Una nota versionada que la sesión editó en el principal viaja y el principal vuelve a HEAD."""
        self.nota_en_principal("feedback_vieja.md", "vieja, mejorada\n", self.yo)
        plan = m.llevar(self.ctx(), "frank", seco=False)
        self.assertEqual([n["accion"] for n in plan["notas"]], ["copiar"])
        self.push()
        m.limpiar(self.ctx(), "frank")
        self.assertEqual((self.pr / CARPETA / "feedback_vieja.md").read_text(), "vieja\n")
        self.assertEqual((self.wt / CARPETA / "feedback_vieja.md").read_text(), "vieja, mejorada\n")
        self.assertEqual(self.estado_principal(), "")

    def test_13_push_viejo_no_limpia(self):
        """La rama ya estaba en el remoto, pero sin el commit de memoria: el principal no se toca."""
        self.push()
        self.nota_en_principal("feedback_h.md", "h\n", self.yo, "- [H](feedback_h.md) — nota H")
        m.llevar(self.ctx(), "frank", seco=False)
        res = m.limpiar(self.ctx(), "frank")
        self.assertEqual(len(res["dudas"]), 2)
        self.assertTrue((self.pr / CARPETA / "feedback_h.md").exists())
        self.assertIn("- [H](feedback_h.md) — nota H", (self.pr / CARPETA / "MEMORY.md").read_text())
        self.push()  # con el push al día, el mismo estado sirve para reintentar
        self.assertEqual(m.limpiar(self.ctx(), "frank")["dudas"], [])
        self.assertEqual(self.estado_principal(), "")

    def test_8_en_el_arbol_principal_no_hace_nada(self):
        self.assertIsNone(m.contexto(self.pr))


if __name__ == "__main__":
    unittest.main(verbosity=2)
