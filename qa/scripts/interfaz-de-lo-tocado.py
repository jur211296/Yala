#!/usr/bin/env python3
"""interfaz-de-lo-tocado.py — del diff a las clases de `YalaUITests` que pasan por lo tocado.

    python3 -I qa/scripts/interfaz-de-lo-tocado.py                      # diff contra origin/2.3, árbol de trabajo incluido
    python3 -I qa/scripts/interfaz-de-lo-tocado.py --formato only-testing
    python3 -I qa/scripts/interfaz-de-lo-tocado.py --base A --cabeza B --arbol-de B --json-a plan.json   # un merge pasado
    python3 -I qa/scripts/interfaz-de-lo-tocado.py --archivos Yala/App/Views/X.swift …                # sin git

**Por qué existe (2026-11-17, propuesta P2 de `docs/verificacion/`).** Hasta ese día la sesión elegía
a mano qué clases de interfaz correr en su gate, cruzando el diff con `codeGlobs` del índice de
cobertura, y el CI del PR no corría ninguna. El PR de categorías a un toque (#920) corrió
`CategoryQuickPick23UITests` y rompió `SplitCalculatorUITests` y `AccountCardPickersUITests`, que
también abren «Nuevo registro»: el índice no las une, pero las tres usan identificadores que se
declaran en `NewTransactionView.swift`, el fichero que el PR tocó.

**Seis capas, por orden de fuerza** (la capa de una clase es la más fuerte que la trajo):

1. `prueba` — el diff toca el fichero de la clase.
2. `ayudante` — el diff toca un miembro de `YalaUITests/Support/` y la clase lo llama.
3. `indice` — el fichero casa con `codeGlobs` de un área del índice y la clase sale en su
   `coverage` (`YalaUITests/<Clase>`). Un glob que cubre más de un cuarto de la app
   (`Yala/App/Views/**`) baja a la capa 6: casa con todo y no dice nada de lo tocado.
4. `identificador` — el fichero declara un identificador (un literal tipo `new_transaction_amount`,
   o el prefijo de uno interpolado, `"account_selector_row_\\(id)"`) que la clase usa, a pelo o a
   través de un ayudante de `Support/`.
5. `texto` — el diff cambia o quita un texto en español (`es.lproj/*.strings`, el idioma en que
   corren las pruebas) que la clase busca tal cual: la decisión 48 renombró «Favoritos» y la
   prueba que lo buscaba se quedó sin fila.
6. `anfitrion` — la clase usa identificadores de una vista que USA lo tocado (hasta dos saltos:
   lógica → view model → vista). Un componente nuevo cambia el alto de la pantalla que lo aloja.

**Orden.** La prueba tocada va siempre delante. El resto, por puntos sumados de todas sus señales,
que miden lo ESPECÍFICA que es cada una: un identificador vale `1/n` (`n` = clases que lo usan), un
miembro de `Support` `1/n` de sus llamadores, un área del índice `1/n` de sus clases, un texto
quitado `0,5`, y un anfitrión lo mismo que un identificador por `0,5` por salto. Uno que usan dos
clases dice mucho más que uno que usan cuarenta: un ayudante que llaman cien pruebas no tapa a la
que usa el botón que se movió. La capa que se informa es la más fuerte que la trajo. A igual
puntuación, la más barata primero.

**Techo.** `--techo-min` (30 por defecto, o `UI_TOCADO_TECHO_MIN`) son los minutos estimados de
interfaz que caben, con los segundos por clase de `qa/ci-ui-tiempos.json` (los del runner del CI;
sin dato, 46 s por caso, la media medida). `--techo-clases` añade un tope por número. Lo que no
cabe NO se calla: sale en el informe con su capa, su motivo y sus minutos. La primera clase entra
aunque sola pase del techo, para que un cambio caro no corra cero.

**Lo que no ve.** Un identificador que llega a la vista por variable (`.accessibilityIdentifier(id)`)
se ve en el fichero que escribe el literal, no en el que lo pinta. Un texto que no está en
`es.lproj` (los literales de `L10n.swift` con su valor por defecto) no entra en la capa 5. Un
fichero de la app que no trae ninguna clase sale en «sin clase»: es un hueco del índice o lógica
sin pantalla, y se dice.

Salida en stdout según `--formato`: `clases` (una por línea), `only-testing`
(`-only-testing:YalaUITests/<Clase>`), `json` o `informe`. El informe legible va a stderr salvo
con `--formato informe`. `--json-a FICHERO` deja además el plan completo.

**Solo local.** Lo usa el paso 3 de `/gate` en la Mini o la Max. El CI del PR NO corre interfaz:
Jürgen lo decidió el 2026-11-17 por el coste del runner macOS, que se paga por minuto (medido: el
techo se llena en 137 de 143 PRs con pantallas, ~59 min de macOS por PR). La suite entera sigue en
la nocturna.

Exit: 0 = plan hecho (puede estar vacío, y lo dice) · 2 = uso, git o árbol ilegible.

Banco: `qa/scripts/interfaz-de-lo-tocado-test.sh` (sintético + casos reales de noviembre).
"""
import argparse
import fnmatch
import json
import os
import re
import subprocess
import sys
from collections import defaultdict

CAPAS = ['prueba', 'ayudante', 'indice', 'identificador', 'texto', 'anfitrion']
POR_CASO = 46            # s por caso sin dato medido (qa.yml, «POR QUE OCHO»)
GLOB_ANCHO = 0.25        # un glob que casa con más de esta fracción de la app es «ancho»
MAX_ANFITRIONES = 40     # un tipo que usan más ficheros es un componente común: no se sigue
MIN_PREFIJO = 6          # un prefijo de identificador interpolado más corto no discrimina
PUNTOS_PRUEBA = 100.0    # la prueba tocada va siempre delante
PESO_DEBAJO = 4.0        # un identificador que el cambio empuja vale por cuatro

# Un identificador: dos o más trozos unidos por _ o -, sin espacios (`fab_manual`, `tarjeta-dos-lineas`).
ID_RE = re.compile(r'[A-Za-z][A-Za-z0-9]*(?:[_-][A-Za-z0-9]+)+[_-]?')
# Lo que tiene forma de identificador y no lo es: un locale (`en_US`, `es-419`) o un formato de fecha
# (`yyyy-MM-dd`). Con la especificidad, un falso raro puntúa como un identificador raro: se quitan.
NO_ID_RE = re.compile(r'[a-z]{2,3}(?:[_-][A-Z][a-z]{3})?(?:[_-](?:[A-Z]{2}|\d{3}))?|[yMdHhmsSaEZ_-]+')
CLASE_RE = re.compile(r'^\s*(?:(?:final|public|internal|open|@MainActor)\s+)*class\s+(\w+)\s*:\s*XCTestCase\b', re.M)
CASO_RE = re.compile(r'^\s*(?:@MainActor\s+)?func\s+test\w*\s*\(', re.M)
TIPO_RE = re.compile(r'^(?:@\w+\s+)*(?:(?:public|private|fileprivate|internal|final)\s+)*(?:struct|class|enum|actor)\s+([A-Z]\w+)', re.M)
DECL_MIEMBRO_RE = re.compile(
    r'\s*(?:@\w+\s+)*(?:(?:public|private|fileprivate|static|internal|override|final|nonisolated)\s+)*(?:func|var|let)\s+(\w+)')
TEXTO_ES_RE = re.compile(r'-\s*"(?:[^"\\]|\\.)*"\s*=\s*"((?:[^"\\]|\\.)*)"\s*;')


def uso(msg):
    print(f'interfaz-de-lo-tocado: {msg}', file=sys.stderr)
    sys.exit(2)


def git(*args, repo='.'):
    r = subprocess.run(['git', '-C', repo, *args], capture_output=True, text=True)
    if r.returncode != 0:
        uso(f'git {" ".join(args)} falló: {r.stderr.strip()}')
    return r.stdout


def leer(ruta):
    try:
        with open(ruta, encoding='utf-8', errors='replace') as f:
            return f.read()
    except OSError:
        return ''


def sin_comentarios(src):
    """Quita // y /* */ sin tocar las cadenas de una línea (aquí las cadenas son lo que se busca)."""
    out, i, n = [], 0, len(src)
    while i < n:
        c = src[i]
        if c == '"':
            j = i + 1
            while j < n and src[j] not in '"\n':
                j += 2 if src[j] == '\\' else 1
            out.append(src[i:j + 1]); i = j + 1
        elif src.startswith('//', i):
            j = src.find('\n', i)
            i = n if j < 0 else j
        elif src.startswith('/*', i):
            j = src.find('*/', i + 2)
            fin = n if j < 0 else j + 2
            out.append('\n' * src.count('\n', i, fin)); i = fin
        else:
            out.append(c); i += 1
    return ''.join(out)


def literales(src):
    """(contenido, interpolado) de cada literal de una línea; el interpolado se corta en su `\\(`."""
    for m in re.finditer(r'"((?:[^"\\\n]|\\.)*)"', sin_comentarios(src)):
        cuerpo = m.group(1)
        k = cuerpo.find('\\(')
        yield (cuerpo[:k], True) if k >= 0 else (cuerpo, False)


def es_id(txt):
    return ID_RE.fullmatch(txt) is not None and NO_ID_RE.fullmatch(txt) is None


def es_prefijo(txt):
    return len(txt) >= MIN_PREFIJO and txt[-1] in '_-' and es_id(txt)


def ids_de_app(src):
    """Identificadores que declara un fichero de la app: exactos y prefijos de interpolados."""
    exactos, prefijos = set(), set()
    for txt, interpolado in literales(src):
        if interpolado:
            if es_prefijo(txt):
                prefijos.add(txt)
        elif es_id(txt):
            exactos.add(txt)
    return exactos, prefijos


def tokens_de_prueba(src):
    """Identificadores dentro de los literales de una prueba (también dentro de un predicado)."""
    out = set()
    for txt, interpolado in literales(src):
        out.update(t for t in ID_RE.findall(txt) if es_id(t))
        if interpolado and es_prefijo(txt):
            out.add(txt)
    return out


def casa_id(token, exactos, prefijos):
    """Qué identificador de la app casa con un token de prueba, o None."""
    if token in exactos:
        return token
    for p in prefijos:
        if token.startswith(p) or (es_prefijo(token) and p.startswith(token)):
            return p
    if es_prefijo(token):
        for e in exactos:
            if e.startswith(token):
                return token
    return None


def miembros_de(src):
    """[(miembro, cuerpo, línea inicial)] de un fichero de Support: cada `func`/`var`/`let` del
    nivel del tipo (no las variables locales de un cuerpo) hasta el siguiente."""
    out, actual, prof = [], None, 0
    limpio = re.sub(r'"(?:[^"\\\n]|\\.)*"', '""', sin_comentarios(src)).split('\n')
    for n, (ln, ln_limpia) in enumerate(zip(src.split('\n'), limpio), 1):
        m = DECL_MIEMBRO_RE.match(ln) if prof <= 1 else None
        if m:
            if actual:
                out.append(actual)
            actual = [m.group(1), [ln], n]
        elif actual:
            actual[1].append(ln)
        prof = max(0, prof + ln_limpia.count('{') - ln_limpia.count('}'))
    if actual:
        out.append(actual)
    return [(nombre, '\n'.join(cuerpo), ini) for nombre, cuerpo, ini in out]


def zona_desplazada(src, lineas):
    """Identificadores que el cambio EMPUJA: los que se pintan después de la línea tocada.

    En SwiftUI el orden del cuerpo es el orden en pantalla. Del miembro (`var`/`func` del tipo) que
    contiene la primera línea tocada se toma lo que viene después, y de cada miembro del mismo
    fichero al que llama ahí, su cuerpo entero (dos niveles). Lo mismo un nivel arriba: en quien
    llama a ese miembro, lo que viene después de la llamada. Sin líneas (`--archivos`), vacío.
    """
    if not lineas:
        return set(), set()
    miembros = miembros_de(src)
    cuerpo_de = {}
    for nombre, cuerpo, ini in miembros:
        cuerpo_de.setdefault(nombre, (cuerpo, ini))
    nombres = sorted(cuerpo_de, key=len, reverse=True)
    ref = re.compile(r'\b(' + '|'.join(map(re.escape, nombres)) + r')\b') if nombres else None
    exactos, prefijos = set(), set()

    def sumar(texto, nivel, vistos):
        ex, pr = ids_de_app(texto)
        exactos.update(ex); prefijos.update(pr)
        if nivel == 0 or ref is None:
            return
        for n in set(ref.findall(sin_comentarios(texto))):
            if n not in vistos:
                vistos.add(n)
                sumar(cuerpo_de[n][0], nivel - 1, vistos)

    for n in sorted(lineas):
        dueno = [(m, c, i) for m, c, i in miembros if i <= n]
        if not dueno:
            continue
        nombre, cuerpo, ini = dueno[-1]
        if n - ini >= cuerpo.count('\n') + 1:
            continue
        resto = '\n'.join(cuerpo.split('\n')[n - ini:])
        sumar(resto, 2, {nombre})
        # Un nivel arriba: quien pinta este miembro, después de pintarlo.
        llamada = re.compile(rf'\b{re.escape(nombre)}\b')
        for otro, c2, _ in miembros:
            if otro == nombre:
                continue
            m = llamada.search(sin_comentarios(c2))
            if m:
                sumar(sin_comentarios(c2)[m.end():], 1, {nombre, otro})
        break   # la primera línea tocada manda: lo de debajo de ella ya incluye lo de debajo de las demás
    return exactos, prefijos


class Disco:
    """Lee el árbol de una carpeta."""

    def __init__(self, raiz):
        self.raiz = raiz
        self.nombre = raiz

    def listar(self, top):
        base = os.path.join(self.raiz, top)
        return sorted(os.path.relpath(os.path.join(d, f), self.raiz)
                      for d, _, fs in os.walk(base) for f in fs) if os.path.isdir(base) else []

    def leer(self, rel):
        ruta = os.path.join(self.raiz, rel)
        return leer(ruta) if os.path.isfile(ruta) else None


class DeGit:
    """Lee el árbol de un commit sin extraerlo (el banco y la medición sobre PRs ya mergeados)."""

    def __init__(self, repo, ref):
        self.repo, self.ref = repo, ref
        self.nombre = f'{ref} (de git)'
        sha = git('rev-parse', '--verify', f'{ref}^{{commit}}', repo=repo).strip()
        self.ficheros = git('ls-tree', '-r', '--name-only', sha, repo=repo).split('\n')
        self.sha = sha
        self._cache = {}

    def listar(self, top):
        return [f for f in self.ficheros if f.startswith(top + '/')]

    def precargar(self, rels):
        faltan = [r for r in rels if r not in self._cache]
        if not faltan:
            return
        entrada = ''.join(f'{self.sha}:{r}\n' for r in faltan).encode()
        out = subprocess.run(['git', '-C', self.repo, 'cat-file', '--batch'], input=entrada,
                             capture_output=True).stdout
        i = 0
        for r in faltan:
            fin = out.index(b'\n', i)
            cab = out[i:fin].split()
            if len(cab) < 3 or cab[1] == b'missing':
                self._cache[r] = None
                i = fin + 1
                continue
            n = int(cab[2])
            self._cache[r] = out[fin + 1:fin + 1 + n].decode('utf-8', 'replace')
            i = fin + 1 + n + 1

    def leer(self, rel):
        self.precargar([rel])
        return self._cache[rel]


class Arbol:
    """Lo que hay en el árbol: clases de prueba, ayudantes, fuentes de la app, índice y tiempos."""

    def __init__(self, lector):
        self.lector = lector
        pruebas = [r for r in lector.listar('YalaUITests') if r.endswith('.swift')]
        if not pruebas:
            uso(f'no hay YalaUITests/*.swift en {lector.nombre}')
        self.app = sorted(r for top in ('Yala', 'YalaWidgets') for r in lector.listar(top) if r.endswith('.swift'))
        if hasattr(lector, 'precargar'):
            lector.precargar(pruebas + self.app + ['qa/coverage-index.json', 'qa/ci-ui-tiempos.json'])
        self.clases_de = {}        # fichero de prueba -> [clases]
        self.casos = {}            # clase -> nº de casos
        self.fuente_prueba = {}    # fichero de prueba -> fuente
        self.ayudantes = {}        # fichero de Support -> fuente
        for rel in pruebas:
            src = lector.leer(rel) or ''
            if '/Support/' in f'/{rel}':
                self.ayudantes[rel] = src
            clases = CLASE_RE.findall(src)
            if not clases:
                continue
            self.clases_de[rel] = clases
            self.fuente_prueba[rel] = src
            n = max(1, len(CASO_RE.findall(src)) // len(clases))
            for c in clases:
                self.casos[c] = n
        # Miembros de Support con sus tokens, para el salto «prueba → ayudante → identificador».
        self.tokens_miembro = defaultdict(set)
        for src in self.ayudantes.values():
            for nombre, cuerpo, _ in miembros_de(src):
                self.tokens_miembro[nombre].update(tokens_de_prueba(cuerpo))
        self._llamadores = {}
        self.indice = self._json('qa/coverage-index.json').get('areas', [])
        self.tiempos = self._json('qa/ci-ui-tiempos.json').get('suites', {})
        self._fuente_app = {}
        self._tipos = None
        # Tokens de cada prueba con su vía (directo o el ayudante que la trae), y su frecuencia.
        self.tokens = {}
        self.df = defaultdict(int)
        for rel, src in self.fuente_prueba.items():
            toks = dict.fromkeys(tokens_de_prueba(src), 'directo')
            for nombre, tm in self.tokens_miembro.items():
                if tm and rel in self.llamadores(nombre):
                    for t in tm:
                        toks.setdefault(t, f'vía {nombre}')
            self.tokens[rel] = toks
            for t in toks:
                self.df[t] += len(self.clases_de[rel])

    def _json(self, rel):
        txt = self.lector.leer(rel)
        if txt is None:
            return {}
        try:
            return json.loads(txt)
        except ValueError as e:
            uso(f'{rel} ilegible: {e}')

    def fuente(self, rel):
        if rel not in self._fuente_app:
            self._fuente_app[rel] = self.lector.leer(rel) or ''
        return self._fuente_app[rel]

    def llamadores(self, miembro):
        """Ficheros de prueba que llaman a un miembro de Support (`.x` o `x(`)."""
        if miembro not in self._llamadores:
            pat = re.compile(rf'(?:\.{re.escape(miembro)}\b|(?<![\w.]){re.escape(miembro)}\s*\()')
            self._llamadores[miembro] = {r for r, s in self.fuente_prueba.items() if pat.search(s)}
        return self._llamadores[miembro]

    def segundos(self, clase):
        s = self.tiempos.get(clase)
        if isinstance(s, (int, float)):
            return float(s), 'medido'
        n = self.casos.get(clase, 1)
        return float(n * POR_CASO), f'{n} casos × {POR_CASO} s'

    def tipos(self):
        """(tipo -> fichero que lo declara, tipo -> ficheros de la app que lo nombran)."""
        if self._tipos is None:
            decl = {}
            for rel in self.app:
                for t in TIPO_RE.findall(sin_comentarios(self.fuente(rel))):
                    decl.setdefault(t, rel)
            usos = defaultdict(set)
            if decl:
                pat = re.compile(r'\b(' + '|'.join(sorted(map(re.escape, decl), key=len, reverse=True)) + r')\b')
                for rel in self.app:
                    for t in set(pat.findall(sin_comentarios(self.fuente(rel)))):
                        if decl[t] != rel:
                            usos[t].add(rel)
            self._tipos = (decl, usos)
        return self._tipos


class Diff:
    """Ficheros tocados, líneas tocadas (en la versión nueva) y textos en español que cambian o se van."""

    def __init__(self, archivos, lineas=None, textos=None, origen=''):
        self.archivos = sorted(set(archivos))
        self.lineas = lineas or {}
        self.textos = textos or set()
        self.origen = origen

    @staticmethod
    def de_git(repo, base, cabeza):
        if cabeza:
            origen = f'{base}..{cabeza}'
            nombres = git('diff', '--name-only', base, cabeza, repo=repo).split('\n')
            parche = git('diff', '-U0', '--no-color', base, cabeza, repo=repo)
        else:
            mb = git('merge-base', base, 'HEAD', repo=repo).strip()
            origen = f'{base} (desde {mb[:9]}) contra el árbol de trabajo'
            nombres = git('diff', '--name-only', mb, repo=repo).split('\n')
            nombres += git('ls-files', '--others', '--exclude-standard', repo=repo).split('\n')
            parche = git('diff', '-U0', '--no-color', mb, repo=repo)
        lineas, textos = leer_parche(parche)
        return Diff([n for n in nombres if n], lineas, textos, origen)


def leer_parche(parche):
    """Líneas tocadas por fichero (numeración nueva) y valores quitados de `es.lproj/*.strings`."""
    lineas, textos = defaultdict(set), set()
    viejo = nuevo = None
    for ln in parche.split('\n'):
        if ln.startswith('--- '):
            viejo = ln[6:] if ln.startswith('--- a/') else None
        elif ln.startswith('+++ '):
            nuevo = ln[6:] if ln.startswith('+++ b/') else None
        elif ln.startswith('@@') and nuevo:
            m = re.match(r'@@ -\d+(?:,\d+)? \+(\d+)(?:,(\d+))? @@', ln)
            if m:
                ini, cnt = int(m.group(1)), int(m.group(2) or 1)
                # Una hunk que solo borra (cnt 0) toca la línea en la que estaba lo borrado.
                lineas[nuevo].update(range(max(ini, 1), ini + max(cnt, 1)))
        elif ln.startswith('-') and viejo and '/es.lproj/' in viejo and viejo.endswith('.strings'):
            m = TEXTO_ES_RE.match(ln)
            if m and len(m.group(1).strip()) >= 3 and '%' not in m.group(1):
                textos.add(m.group(1))
    return lineas, textos


def es_codigo_app(rel):
    return rel.endswith('.swift') and rel.split('/', 1)[0] in ('Yala', 'YalaWidgets')


def glob_casa(glob, rel):
    if glob.endswith('/**'):
        return rel.startswith(glob[:-2])
    return fnmatch.fnmatch(rel, glob) or fnmatch.fnmatch(rel, glob.replace('**/', '*/'))


def planear(arbol, diff, techo_min, techo_clases):
    hallazgos = {}   # clase -> {capa, puntos, motivos, ficheros}
    avisos = set()

    def anotar(clase, capa, puntos, motivo, fichero):
        h = hallazgos.setdefault(clase, {'capa': capa, 'puntos': 0.0, 'motivos': [], 'ficheros': set()})
        h['puntos'] += puntos
        if CAPAS.index(capa) < CAPAS.index(h['capa']):
            h['capa'] = capa
            h['motivos'].insert(0, motivo)
        elif motivo not in h['motivos']:
            h['motivos'].append(motivo)
        del h['motivos'][4:]
        h['ficheros'].add(fichero)

    acreditados = defaultdict(set)   # clase -> identificadores que ya puntuaron (uno puntúa una vez)

    def por_ids(ids, capa, peso, origen, fichero):
        exactos, prefijos = ids
        if not exactos and not prefijos:
            return
        for rel, toks in arbol.tokens.items():
            usados = {}
            for t, via in toks.items():
                k = casa_id(t, exactos, prefijos)
                if k:
                    usados.setdefault(k, (t, via))
            if not usados:
                continue
            ej = sorted(usados, key=lambda k: arbol.df[usados[k][0]])[:3]
            vias = sorted({v for _, v in usados.values() if v != 'directo'})
            motivo = f'{origen}: {", ".join(ej)}' + (' …' if len(usados) > 3 else '') + (f' ({vias[0]})' if vias and len(vias) == len(usados) else '')
            for c in arbol.clases_de[rel]:
                nuevos = [k for k in usados if k not in acreditados[c]]
                acreditados[c].update(nuevos)
                # Tope de 1 por fuente: muchos identificadores únicos de una vista vecina no pesan más que
                # uno solo empujado por el cambio. La especificidad ordena DENTRO de cada fuente.
                pts = min(1.0, sum(1.0 / max(1, arbol.df[usados[k][0]]) for k in nuevos))
                anotar(c, capa, peso * pts, motivo, fichero)

    tocados_app = [f for f in diff.archivos if es_codigo_app(f)]

    # 1 · prueba tocada
    for f in diff.archivos:
        for c in arbol.clases_de.get(f, []):
            anotar(c, 'prueba', PUNTOS_PRUEBA, f'toca {os.path.basename(f)}', f)

    # 2 · ayudante de Support tocado, por miembro
    for f in diff.archivos:
        if f not in arbol.ayudantes:
            continue
        miembros = miembros_de(arbol.ayudantes[f])
        tocadas = diff.lineas.get(f, set())
        nombres = set()
        for n in tocadas:
            dueno = [m for m, _, ini in miembros if ini <= n]
            if dueno:
                nombres.add(dueno[-1])
        if not nombres:
            nombres = {m for m, _, _ in miembros}
            avisos.add(f'{f}: sin líneas tocadas que caigan en un miembro; cuenta el fichero entero ({len(nombres)} miembros)')
        for m in sorted(nombres):
            llam = arbol.llamadores(m)
            for rel in llam:
                for c in arbol.clases_de[rel]:
                    anotar(c, 'ayudante', 1.0 / len(llam), f'llama a {m} ({os.path.basename(f)})', f)

    # 3 · índice de cobertura
    total_app = max(1, len(arbol.app))
    for area in arbol.indice:
        clases = list(dict.fromkeys(re.findall(r'YalaUITests/(?:\w+/)*?(\w+UITests)\b', area.get('coverage') or '')))
        clases = [c for c in clases if c in arbol.casos]
        if not clases:
            continue
        # Un área suma una vez, la toquen uno o diez ficheros: lo que dice es «estas clases cubren esto».
        estrechos, anchos = [], []
        for f in diff.archivos:
            globs = [g for g in area.get('codeGlobs', []) if glob_casa(g, f)]
            if not globs:
                continue
            if all(sum(1 for a in arbol.app if glob_casa(g, a)) / total_app > GLOB_ANCHO for g in globs):
                anchos.append((f, globs[0]))
            else:
                estrechos.append(f)
        for c in clases:
            for f in estrechos:
                anotar(c, 'indice', 1.0 / len(clases) if f == estrechos[0] else 0.0, f'índice {area["area"]}', f)
            if anchos and not estrechos:
                for f, g in anchos:
                    # Fichero marcado: un glob ancho no saca a un fichero de «sin clase».
                    anotar(c, 'anfitrion', 0.001 if f == anchos[0][0] else 0.0, f'índice {area["area"]} (glob ancho {g})', f'ancho:{f}')

    # 4 · identificadores que declara lo tocado: primero los que quedan DEBAJO del cambio (un hueco
    # nuevo los empuja, que es como se rompieron las del 16-nov), luego el resto del fichero.
    for f in tocados_app:
        src = arbol.fuente(f)
        abajo = zona_desplazada(src, diff.lineas.get(f, set()))
        por_ids(abajo, 'identificador', PESO_DEBAJO, f'debajo de lo tocado en {os.path.basename(f)}', f)
        por_ids(ids_de_app(src), 'identificador', 1.0, os.path.basename(f), f)

    # 5 · textos en español que cambian o se van
    for rel, src in arbol.fuente_prueba.items():
        vistos = sorted(t for t in diff.textos if f'"{t}"' in src or f"'{t}'" in src)
        for c in (arbol.clases_de[rel] if vistos else []):
            anotar(c, 'texto', 0.5 * len(vistos), f'busca «{vistos[0]}», que cambia', 'es.lproj')

    # 6 · vistas anfitrionas de lo tocado, hasta dos saltos
    if tocados_app:
        decl, usos = arbol.tipos()
        por_fichero = defaultdict(list)
        for t, rel in decl.items():
            por_fichero[rel].append(t)
        for f in tocados_app:
            frontera, vistos = {f}, {f}
            for salto in (1, 2):
                siguiente = set()
                for g in frontera:
                    for t in por_fichero.get(g, []):
                        u = usos.get(t, set())
                        if len(u) > MAX_ANFITRIONES:
                            avisos.add(f'{t} lo usan {len(u)} ficheros: componente común, no se siguen sus anfitriones')
                            continue
                        siguiente |= u - vistos
                for h in sorted(siguiente - set(tocados_app)):
                    por_ids(ids_de_app(arbol.fuente(h)), 'anfitrion', 0.5 ** salto, f'{os.path.basename(h)} (usa {os.path.basename(f)})', f)
                vistos |= siguiente
                # Una vista ya es la pantalla: se sigue solo lo que no es vista (lógica → view model → vista).
                frontera = {h for h in siguiente if '/Views/' not in h}
                if not frontera:
                    break

    con_clase = set()
    for h in hallazgos.values():
        con_clase |= h['ficheros']
    sin_clase = [f for f in tocados_app if f not in con_clase]

    filas = []
    for c, h in hallazgos.items():
        seg, como = arbol.segundos(c)
        filas.append({'clase': c, 'capa': h['capa'], 'puntos': round(h['puntos'], 4), 'segundos': round(seg),
                      'estimacion': como, 'motivos': h['motivos']})
    # Puntos por minuto: el techo es de minutos, y una clase de 27 min que puntúa como cuatro de 2 min
    # no puede dejarlas fuera. La prueba tocada va delante igual (sus 100 puntos).
    filas.sort(key=lambda x: (-x['puntos'] / max(1.0, x['segundos'] / 60) ** 0.5, x['segundos'], x['clase']))

    dentro, fuera, usado = [], [], 0.0
    for x in filas:
        cabe_n = techo_clases is None or len(dentro) < techo_clases
        cabe_min = usado + x['segundos'] <= techo_min * 60 or not dentro
        if cabe_n and cabe_min:
            dentro.append(x)
            usado += x['segundos']
        else:
            x['fuera_por'] = 'techo de clases' if not cabe_n else 'techo de minutos'
            fuera.append(x)
    return {
        'diff': diff.origen,
        'ficheros_tocados': len(diff.archivos),
        'ficheros_app_tocados': len(tocados_app),
        'techo_min': techo_min,
        'techo_clases': techo_clases,
        'minutos_estimados': round(usado / 60, 1),
        'minutos_fuera': round(sum(x['segundos'] for x in fuera) / 60, 1),
        'clases': dentro,
        'fuera': fuera,
        'sin_clase': sin_clase,
        'avisos': sorted(avisos),
    }


def informe(plan):
    o = [f'Interfaz de lo tocado — {plan["diff"]}',
         f'  {plan["ficheros_tocados"]} ficheros tocados, {plan["ficheros_app_tocados"]} de la app.']
    fila = '    {clase:<46} {capa:<13} {min:5.1f} min  {motivo}'
    if not plan['clases']:
        o.append('  Ninguna clase de YalaUITests pasa por lo tocado: no hay interfaz que correr.')
    else:
        techo = f'techo {plan["techo_min"]:g} min' + (f', {plan["techo_clases"]} clases' if plan['techo_clases'] else '')
        o.append(f'  Corren {len(plan["clases"])} clases, ~{plan["minutos_estimados"]} min estimados ({techo}):')
        o += [fila.format(clase=x['clase'], capa=x['capa'], min=x['segundos'] / 60, motivo=x['motivos'][0]) for x in plan['clases']]
    if plan['fuera']:
        o.append(f'  FUERA por el techo: {len(plan["fuera"])} clases, ~{plan["minutos_fuera"]} min. No corren; '
                 'si el cambio las toca de verdad, súbelas con --techo-min o córrelas a mano:')
        o += [fila.format(clase=x['clase'], capa=x['capa'], min=x['segundos'] / 60, motivo=x['motivos'][0]) for x in plan['fuera']]
    if plan['sin_clase']:
        o.append('  Ficheros de la app por los que no pasa ninguna clase (hueco del índice, o lógica sin pantalla):')
        o += [f'    {f}' for f in plan['sin_clase']]
    o += [f'  Aviso: {a}' for a in plan['avisos']]
    return '\n'.join(o)


def main():
    ap = argparse.ArgumentParser(description='Clases de YalaUITests que pasan por lo tocado.')
    ap.add_argument('--base', default='origin/2.3', help='rama o commit base (default origin/2.3)')
    ap.add_argument('--cabeza', help='commit cabeza; sin él, el árbol de trabajo (con lo no versionado)')
    ap.add_argument('--archivos', nargs='+', help='lista de ficheros en vez de git (sin líneas ni textos)')
    ap.add_argument('--repo', default='.', help='repo donde correr git (default .)')
    ap.add_argument('--raiz', help='carpeta donde leer pruebas, app e índice (default la raíz del repo)')
    ap.add_argument('--arbol-de', help='leer pruebas, app e índice de este commit en vez de la carpeta')
    ap.add_argument('--techo-min', type=float, default=None)
    ap.add_argument('--techo-clases', type=int, default=None)
    ap.add_argument('--formato', choices=['clases', 'only-testing', 'json', 'informe'], default='clases')
    ap.add_argument('--json-a', help='además, el plan completo en JSON en este fichero')
    a = ap.parse_args()

    techo = a.techo_min
    if techo is None:
        try:
            techo = float(os.environ.get('UI_TOCADO_TECHO_MIN') or 30)
        except ValueError:
            uso('UI_TOCADO_TECHO_MIN no es un número')
    if techo <= 0:
        uso('el techo de minutos tiene que ser > 0')
    if a.techo_clases is not None and a.techo_clases < 1:
        uso('--techo-clases tiene que ser ≥ 1')
    if a.archivos:
        diff = Diff(a.archivos, origen='lista de ficheros')
        top = None
    else:
        top = git('rev-parse', '--show-toplevel', repo=a.repo).strip()
        diff = Diff.de_git(top, a.base, a.cabeza)
    if a.arbol_de:
        lector = DeGit(top or a.repo, a.arbol_de)
    else:
        lector = Disco(a.raiz or top or os.getcwd())
    plan = planear(Arbol(lector), diff, techo, a.techo_clases)

    if a.json_a:
        with open(a.json_a, 'w', encoding='utf-8') as f:
            json.dump(plan, f, ensure_ascii=False, indent=2)
    texto = informe(plan)
    if a.formato == 'informe':
        print(texto)
        return
    print(texto, file=sys.stderr)
    if a.formato == 'json':
        print(json.dumps(plan, ensure_ascii=False, indent=2))
    else:
        for x in plan['clases']:
            print(f'-only-testing:YalaUITests/{x["clase"]}' if a.formato == 'only-testing' else x['clase'])


if __name__ == '__main__':
    main()
