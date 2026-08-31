#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
indice_readme.py — regenera el indice del README: pregunta -> donde se responde.

El bloque decia "generado, no editar a mano" y NO habia generador: se escribio a
mano una vez y se quedo frio. Un indice que no se regenera es peor que no tenerlo,
porque el marcador prohibe arreglarlo a mano y nada lo arregla solo.

Resuelve cada documento contra el disco: si existe, enlaza; si no, dice pendiente.
Las filas que no son de la lista canonica SE CONSERVAN — si alguien anadio una
pregunta propia, no se la comemos.

    python3 scripts/indice_readme.py --repo . --dry-run
    python3 scripts/indice_readme.py --repo . --apply
"""
import io, os, re, sys, unicodedata

M0 = '<!-- INDICE:inicio — generado por scripts/indice_readme.py, no editar a mano -->'
M1 = '<!-- INDICE:fin -->'
RE_M0 = re.compile(r'<!-- INDICE:inicio[^>]*-->')

PREGUNTAS = [
    (u'¿Dónde quedó todo? ¿Qué sigue?',        ['STATE.md', 'docs/state.md', 'docs/ESTADO.md']),
    (u'¿Por qué se decidió X? ¿Qué manda hoy?', ['DECISIONS.md', 'docs/DECISIONS.md']),
    (u'¿Qué pasó el día X?',                    ['CHANGELOG.md', 'docs/CHANGELOG.md']),
    (u'¿Qué hitos y fechas hay?',               ['ROADMAP.md', 'docs/roadmap.md']),
    (u'¿Cómo se trabaja aquí? Reglas duras',    ['CLAUDE.md']),
    (u'¿Esto ya nos mordió antes?',             ['docs/aprendizajes-tecnicos.md']),
    (u'¿Qué hago si se cae en producción?',     ['docs/runbook.md']),
    (u'¿Qué credenciales y dependencias hay?',  ['docs/accesos.md']),
    (u'¿Qué significa este término?',           ['docs/glosario.md', 'docs/glossary.md']),
    (u'¿Cómo arranco de cero en otra máquina?', ['HANDOVER.md', 'HANDOFF.md',
                                                 'docs/HANDOVER.md', 'docs/HANDOFF.md']),
]


def real(repo, rel):
    """La ruta con su CAJA REAL, o None. macOS no distingue mayusculas: isfile()
    dice que si con otro nombre y acabariamos enlazando a algo que no se llama asi."""
    d, n = os.path.split(rel)
    base = os.path.join(repo, d) if d else repo
    if not os.path.isdir(base):
        return None
    hit = next((x for x in os.listdir(base) if x.lower() == n.lower()), None)
    if not hit:
        return None
    p = os.path.join(base, hit)
    return (os.path.join(d, hit) if d else hit) if os.path.isfile(p) else None


def tiene_indice(p):
    try:
        cab = io.open(p, encoding='utf-8', errors='replace').read(4000)
    except Exception:
        return False
    return bool(re.search(r'INDICE:inicio|##\s+Índice|##\s+Indice', cab))


def construir(repo):
    L = [M0, '', u'## Índice — dónde se responde cada pregunta', '',
         u'| Pregunta | Dónde |', '|---|---|']
    for q, cands in PREGUNTAS:
        r = next((x for x in (real(repo, c) for c in cands) if x), None)
        L.append(u'| %s | %s |' % (q, (u'[`%s`](./%s)' % (r, r)) if r else u'— *(pendiente)*'))
    return L


def extras(viejo):
    """Filas que alguien anadio y no son de la lista canonica: se conservan."""
    canon = set(q for q, _ in PREGUNTAS)
    out = []
    for m in re.finditer(r'(?m)^\|\s*(¿[^|]+?)\s*\|\s*(.+?)\s*\|$', viejo):
        if m.group(1).strip() not in canon and 'Pregunta' not in m.group(1):
            out.append(u'| %s | %s |' % (m.group(1).strip(), m.group(2).strip()))
    return out


def cola(repo):
    L = []
    dec = next((d for d in ('decisions', 'docs/decisions') if os.path.isdir(os.path.join(repo, d))), None)
    if dec:
        n = len([x for x in os.listdir(os.path.join(repo, dec)) if x.endswith('.md')])
        idx = real(repo, 'DECISIONS.md') or real(repo, 'docs/DECISIONS.md')
        L += ['', u'**Decisiones:** %d, una por fichero en [`%s/`](./%s/).' % (n, dec, dec)
              + (u' El índice con «qué manda hoy» está en [`%s`](./%s).' % (idx, idx) if idx else '')
              + u' **No cargues el índice entero para buscar una:** localízala y abre solo su fichero.']
    gordos = []
    for raiz, dirs, fich in os.walk(repo):
        dirs[:] = [d for d in dirs if d not in ('.git', 'node_modules', '.build', 'DerivedData')]
        for f in fich:
            if not f.endswith('.md'):
                continue
            p = os.path.join(raiz, f)
            try:
                kb = os.path.getsize(p) / 1024.0
            except OSError:
                continue
            if kb > 60:
                gordos.append((kb, os.path.relpath(p, repo), tiene_indice(p)))
    if gordos:
        gordos.sort(reverse=True)
        L += ['', u'> **Ficheros de más de 60 KB** — `✓` = lleva índice arriba, entra por ahí:',
              u'> ' + u' · '.join(u'%s `%s` (%d KB)' % (u'✓' if ok else u'✗', r, kb)
                                  for kb, r, ok in gordos[:12])]
    return L


def main():
    repo = sys.argv[sys.argv.index('--repo') + 1] if '--repo' in sys.argv else '.'
    apply = '--apply' in sys.argv
    rd = os.path.join(repo, 'README.md')
    viejo = unicodedata.normalize('NFC', io.open(rd, encoding='utf-8').read()) if os.path.isfile(rd) else ''

    m0 = RE_M0.search(viejo)
    dentro = viejo[m0.end():viejo.index(M1)] if (m0 and M1 in viejo) else ''
    bloque = '\n'.join(construir(repo) + extras(dentro) + cola(repo) + ['', M1])

    if m0 and M1 in viejo:
        nuevo = viejo[:m0.start()] + bloque + viejo[viejo.index(M1) + len(M1):]
    else:
        cab = re.match(r'(?s)\A(#[^\n]*\n)', viejo)
        i = cab.end() if cab else 0
        nuevo = viejo[:i] + '\n' + bloque + '\n' + viejo[i:]

    pend = bloque.count('(pendiente)')
    ext = len(extras(dentro))
    print('%s: %d preguntas · %d pendientes · %d filas propias conservadas'
          % (os.path.basename(os.path.abspath(repo)), len(PREGUNTAS), pend, ext))
    if apply:
        io.open(rd, 'w', encoding='utf-8').write(nuevo)
        print('  escrito %s (%d B)' % (rd, len(nuevo.encode())))
    return 0


if __name__ == '__main__':
    sys.exit(main())
