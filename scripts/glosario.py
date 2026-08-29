#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
glosario.py — indice "termino -> donde se decide".

La cabecera se escribe a mano una vez: los terminos de verdad opacos, los que
inventamos nosotros y no significan nada fuera de este repo. Todo lo de abajo se
genera desde las decisiones, asi que no envejece — si el vocabulario cambia, se
regenera y ya. Un glosario escrito entero a mano se queda frio en tres meses.

Uso:
    python3 scripts/glosario.py --repo . --dry-run
    python3 scripts/glosario.py --repo . --apply

Lee las tres formas en que viven las decisiones en la casa:
  1. decisions/*.md o docs/decisions/*.md  (un fichero por ADR, con frontmatter)
  2. docs/DECISIONS.md monolitico con cabeceras "### "
  3. DECISIONS.md monolitico con cabeceras "## ADR-NNN"
"""
import os, re, sys, io, unicodedata

MARCA_M0 = '<!-- GLOSARIO:manual:inicio -->'
MARCA_M1 = '<!-- GLOSARIO:manual:fin -->'
MARCA_G0 = '<!-- GLOSARIO:generado:inicio - no editar a mano -->'
MARCA_G1 = '<!-- GLOSARIO:generado:fin -->'

# Palabras que salen en mayusculas por enfasis o por estructura del documento,
# no por ser terminos. Sin esto el glosario se llena de "NOTA" y "IMPORTANTE".
STOP = set('''
NO SI OK TODO FIXME NOTA NOTAS OJO AVISO ADR ADRS PERO PARA POR CON SIN DEL LAS LOS UNA UNO
IMPORTANTE ATENCION CUIDADO PENDIENTE HECHO SOLO ANTES DESPUES AHORA HOY AYER MISMO
DECISION DECISIONES ESTADO FECHA TITULO RESUMEN CONTEXTO ALTERNATIVAS CONSECUENCIAS
QUE COMO CUANDO DONDE PORQUE SIEMPRE NUNCA JAMAS NADA NADIE ALGO CADA OTRO OTRA
AND OR NOT THE FOR WITH FROM THIS THAT WHEN WHERE
II III IV VI VII VIII IX XI XII
SELECT INSERT UPDATE DELETE CREATE DROP ALTER TABLE INDEX VIEW JOIN LEFT RIGHT INNER OUTER
FROM WHERE ORDER BY GROUP HAVING LIMIT OFFSET UNION CASE THEN ELSE END NULL TRUE FALSE
COUNT SUM AVG MIN MAX DISTINCT VALUES INTO SET EXISTS
GET POST PUT PATCH HEAD HTTP HTTPS URL URI JSON XML UTF ASCII
ERROR WARN WARNING INFO DEBUG TRACE FATAL PASS FAIL SKIP
CLAUDE README LICENSE MIT
'''.split())

STOP_CC = set(['PowerBi'])


def norm(s):
    return unicodedata.normalize('NFC', s)


def ancla(cab):
    # misma formula que indexar_doc.py: si cambia una, cambian las dos
    return re.sub(r'[^a-z0-9\s-]', '', cab.lower()).strip().replace(' ', '-')


def estado_de(txt, fm):
    if fm.get('estado'):
        return fm['estado'].strip().lower()
    m = re.search(r'(?im)^\s*\*\*Estado:?\*\*[:\s]*(.+)$', txt)
    s = (m.group(1) if m else '').lower()
    if 'supersed' in s or 'superad' in s or 'obsolet' in s or 'reemplaz' in s:
        return 'superado'
    if 'descart' in s or 'rechaz' in s or 'anulad' in s or 'revertid' in s:
        return 'descartado'
    return 'vigente'


def leer_frontmatter(txt):
    if not txt.startswith('---'):
        return {}, txt
    fin = txt.find('\n---', 3)
    if fin < 0:
        return {}, txt
    fm = {}
    for ln in txt[3:fin].splitlines():
        if ':' in ln:
            k, v = ln.split(':', 1)
            fm[k.strip()] = v.strip().strip('"').strip("'")
    return fm, txt[fin + 4:]


def cargar(repo):
    """Devuelve (lista de decisiones, etiqueta de la fuente)."""
    for sub in ('decisions', 'docs/decisions'):
        d = os.path.join(repo, sub)
        if os.path.isdir(d):
            out = []
            for n in sorted(os.listdir(d)):
                if not n.endswith('.md') or n.startswith('_'):
                    continue
                p = os.path.join(d, n)
                txt = norm(io.open(p, encoding='utf-8', errors='replace').read())
                fm, cuerpo = leer_frontmatter(txt)
                ref = fm.get('id') or n[:4]
                tit = fm.get('titulo') or ''
                if not tit:
                    m = re.search(r'(?m)^#\s+(.+)$', cuerpo)
                    tit = re.sub(r'^[A-Z]-?\d+\s*[^\w]*\s*', '', m.group(1)) if m else n
                out.append(dict(ref=ref, titulo=tit, estado=estado_de(cuerpo, fm),
                                enlace='%s/%s' % (sub, n), texto=cuerpo))
            if out:
                return out, sub + '/'
    for rel in ('docs/DECISIONS.md', 'DECISIONS.md', 'docs/decisions.md'):
        p = os.path.join(repo, rel)
        if not os.path.isfile(p):
            continue
        txt = norm(io.open(p, encoding='utf-8', errors='replace').read())
        # fuera el indice generado, o indexariamos el indice
        txt = re.sub(r'(?s)<!-- INDICE:inicio.*?<!-- INDICE:fin -->', '', txt)
        niv = '###' if len(re.findall(r'(?m)^###\s', txt)) > len(re.findall(r'(?m)^##\s', txt)) else '##'
        partes = re.split(r'(?m)^%s\s+(.+)$' % niv, txt)
        out = []
        for i in range(1, len(partes), 2):
            cab, cuerpo = partes[i].strip(), partes[i + 1]
            if re.search(r'\[(FECHA|T[IIS]TULO|YYYY|AAAA)', cab, re.I):
                continue          # la plantilla, no una decision
            m = re.match(r'^(ADR|D)-?(\d+)\s*[^\w]*\s*(.*)$', cab)
            if m:
                ref, tit = '%s-%s' % (m.group(1), m.group(2)), m.group(3)
            else:
                # la fecha puede ir suelta o entre corchetes: "### [2026-08-28] Titulo"
                f = (re.match(r'^\[?(\d{4}-\d{2}-\d{2})', cab)
                     or re.search(r'(\d{4}-\d{2}-\d{2})', cab))
                ref = f.group(1) if f else '?'
                tit = re.sub(r'^\[?\d{4}-\d{2}-\d{2}[^\]]*\]?\s*[^\w(]*\s*', '', cab)
            out.append(dict(ref=ref, titulo=tit or cab, estado=estado_de(cuerpo, {}),
                            enlace='%s#%s' % (rel, ancla(cab)), texto=cuerpo))
        if out:
            return out, rel
    return [], None


RE_TICK = re.compile(r'`([^`\n]{2,40})`')
RE_SIGLA = re.compile(u'(?<![A-Za-z0-9_])([A-ZÁÉÍÓÚÑ][A-ZÁÉÍÓÚÑ0-9]{1,7})(?![A-Za-z0-9_])')
RE_CAMEL = re.compile(u'(?<![A-Za-z0-9_])([A-ZÁÉÍÓÚÑ][a-záéíóúñ]+(?:[A-ZÁÉÍÓÚÑ][a-záéíóúñ0-9]+)+)(?![A-Za-z0-9_])')
RE_SNAKE = re.compile(r'(?<![A-Za-z0-9_`])([a-z][a-z0-9]*(?:_[a-z0-9]+){1,4})(?![A-Za-z0-9_])')


def terminos(txt, siglas_ok=None):
    t = set()
    for m in RE_TICK.finditer(txt):
        v = m.group(1).strip()
        if v.startswith('-') or v.count(' ') > 2:
            continue                              # flags de CLI y frases enteras
        if re.search(u'[\u2192=|,;:<>{}]|->', v):
            continue                              # "A -> B" es una relacion, no un termino
        if re.match(r'^#?[0-9A-Fa-f]{3,8}$', v):
            continue                              # #E1251B es un color, no vocabulario
        if v.endswith('/') or v.count('/') > 1:
            continue                              # /api/v3/orders/search es una ruta ajena
        if re.search(r'\w\.(py|md|sh|sql|json|ya?ml|txt|log|csv|tsv|ts|tsx|jsx?|css|html?|toml|ini|cfg|xlsx?|pbix|pbip)$', v, re.I):
            continue                              # un fichero no es vocabulario: es un fichero
        if re.search(r'\.(dev|com|net|io|app|org|es|ai)$', v):
            continue                              # un host tampoco
        if re.match(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)[A-Za-z0-9]{10,}$', v):
            continue                              # 1L4qEG0N2uBH6ih8 es un id, no un termino
        if re.search(r'[A-Za-z]', v):
            t.add(v)
    for m in RE_SIGLA.finditer(txt):
        v = m.group(1)
        if v in STOP or re.match(r'^[A-Z]\d{1,3}$', v) or re.match(r'^[0-9A-F]{6}$', v):
            continue          # E5 es una celda de Excel; E6E6E6, un color
        if siglas_ok is None or v in siglas_ok:
            t.add(v)
    for m in RE_CAMEL.finditer(txt):
        if m.group(1) not in STOP_CC:
            t.add(m.group(1))
    for m in RE_SNAKE.finditer(txt):
        t.add(m.group(1))
    return t


def clave(s):
    b = unicodedata.normalize('NFD', s.lower())
    b = ''.join(c for c in b if unicodedata.category(c) != 'Mn')
    return (re.sub(r'[^a-z0-9]', '', b), s)


def elegir_siglas(decs):
    todo = '\n'.join(d['titulo'] + '\n' + d['texto'] for d in decs)
    arriba = {}
    for m in RE_SIGLA.finditer(todo):
        arriba[m.group(1)] = arriba.get(m.group(1), 0) + 1
    abajo = {}
    for m in re.finditer(u'(?<![A-Za-z0-9_])([a-záéíóúñ]{2,8})(?![A-Za-z0-9_])', todo):
        abajo[m.group(1)] = abajo.get(m.group(1), 0) + 1
    return set(k for k, n in arriba.items() if n >= abajo.get(k.lower(), 0))


def construir(decs):
    siglas_ok = elegir_siglas(decs)
    ac = {}
    for d in decs:
        vivo = d['estado'] not in ('superado', 'descartado')
        en_tit = terminos(d['titulo'], siglas_ok)
        for t in terminos(d['titulo'] + '\n' + d['texto'], siglas_ok):
            e = ac.setdefault(t, dict(vivos=[], muertos=[], titulo=False))
            (e['vivos'] if vivo else e['muertos']).append(d)
            if t in en_tit:
                e['titulo'] = True
    # Se queda lo que titula una decision o lo que se repite lo bastante. El listón
    # de repeticion escala con el corpus: salir en 2 de 240 decisiones no significa
    # nada, salir en 2 de 30 si. Titular una decision siempre cuenta — si el termino
    # dio nombre a algo que hubo que decidir, es vocabulario del proyecto.
    uml = max(2, int(round(len(decs) / 40.0)))
    out = dict((t, e) for t, e in ac.items()
               if len(e['vivos']) + len(e['muertos']) >= uml or e['titulo'])
    # Un termino contenido en otro mas especifico y con las mismas decisiones
    # detras es ruido (`fct` dentro de `fct_ofertas`): sobra el corto.
    refs = dict((t, set(d['ref'] for d in e['vivos'] + e['muertos']))
                for t, e in out.items())
    largos = sorted(out, key=len, reverse=True)
    sobran = set()
    for corto in out:
        for largo in largos:
            if corto != largo and corto in largo and refs[corto] and refs[corto] <= refs[largo]:
                sobran.add(corto)
                break
    for t in sobran:
        del out[t]
    return out


def render(term, total):
    L = [MARCA_G0, '']
    L.append(u'## Dónde se decide cada término (%d)' % len(term))
    L.append('')
    L.append(u'> **No leas este bloque entero** — está ordenado alfabéticamente para buscar dentro')
    L.append(u'> (`grep -i termino docs/glosario.md`), no para leerse. Sale de las %d decisiones del' % total)
    L.append(u'> repo con `python3 scripts/glosario.py --repo . --apply`, así que **no se edita a mano**:')
    L.append(u'> lo que escribas aquí se pierde en la siguiente regeneración. La parte que se mantiene')
    L.append(u'> a mano es la de arriba. Un término marcado *(histórico)* solo vive en decisiones')
    L.append(u'> superadas: si lo ves en el código, quedó algo por limpiar.')
    L.append('')
    for t in sorted(term, key=clave):
        e = term[t]
        lista = e['vivos'] or e['muertos']
        refs = lista[:6]
        cit = ', '.join('[%s](%s)' % (d['ref'], d['enlace']) for d in refs)
        extra = ' +%d' % (len(lista) - len(refs)) if len(lista) > len(refs) else ''
        marca = '' if e['vivos'] else u' *(histórico)*'
        L.append(u'- **%s**%s — %s%s' % (t, marca, cit, extra))
    L.append('')
    L.append(MARCA_G1)
    return '\n'.join(L)


CABECERA = u'''# Glosario — %(nombre)s

%(m0)s

## Términos propios

> Los que inventamos nosotros y no significan nada fuera de este repo. Se escriben
> a mano y son pocos a propósito: si esta lista crece, es que estamos bautizando
> cosas que no hacía falta bautizar.

_(pendiente de escribir)_

%(m1)s
'''


def main():
    repo = '.'
    if '--repo' in sys.argv:
        repo = sys.argv[sys.argv.index('--repo') + 1]
    apply = '--apply' in sys.argv
    out = os.path.join(repo, 'docs', 'glosario.md')
    for carpeta in ('docs', ''):
        d = os.path.join(repo, carpeta) if carpeta else repo
        if not os.path.isdir(d):
            continue
        # macOS no distingue mayusculas: isfile('docs/GLOSARIO.md') dice que si
        # cuando en disco pone 'glosario.md'. Se lista para quedarse con la caja
        # real del fichero; si no, git veria un renombrado que nadie hizo.
        hay = [n for n in os.listdir(d) if n.lower() in ('glosario.md', 'glossary.md')]
        if hay:
            out = os.path.join(d, sorted(hay)[0])
            break

    decs, base = cargar(repo)
    if not decs:
        print('sin decisiones que leer en %s' % repo)
        return 1
    term = construir(decs)
    # Un repo joven no tiene vocabulario propio todavia: crear el fichero solo
    # deja un documento vacio que la revision de frescura marcara como frio para
    # siempre. Cuando acumule decisiones, /higiene lo creara solo.
    if len(term) < 5 and not os.path.isfile(out):
        print(u'%s: solo %d terminos en %d decisiones — todavia no hay glosario que hacer'
              % (os.path.basename(os.path.abspath(repo)), len(term), len(decs)))
        return 0
    gen = render(term, len(decs))

    viejo = norm(io.open(out, encoding='utf-8', errors='replace').read()) if os.path.isfile(out) else ''

    if MARCA_G0 in viejo:
        i = viejo.index(MARCA_G0)
        j = viejo.index(MARCA_G1) + len(MARCA_G1) if MARCA_G1 in viejo else len(viejo)
        nuevo = viejo[:i] + gen + viejo[j:]
    elif viejo.strip():
        # Ya habia glosario a mano sin marcadores: se respeta entero y se le cuelga
        # lo generado debajo. Nunca se pisa texto que escribio una persona.
        cuerpo = viejo.rstrip()
        if MARCA_M0 not in cuerpo:
            cuerpo = MARCA_M0 + '\n' + cuerpo + '\n' + MARCA_M1
        nuevo = cuerpo + '\n\n' + gen + '\n'
    else:
        nombre = os.path.basename(os.path.abspath(repo))
        nuevo = CABECERA % dict(nombre=nombre, m0=MARCA_M0, m1=MARCA_M1) + '\n' + gen + '\n'

    if apply:
        d = os.path.dirname(out)
        if d and not os.path.isdir(d):
            os.makedirs(d)
        io.open(out, 'w', encoding='utf-8').write(nuevo)
        print('escrito %s | %d terminos | %d decisiones (%s)' % (out, len(term), len(decs), base))
    else:
        print('[dry-run] %s | %d terminos | %d decisiones (%s)' % (out, len(term), len(decs), base))
        for t in sorted(term, key=clave)[:60]:
            print('   %s' % t)
    return 0


if __name__ == '__main__':
    sys.exit(main())
