#!/usr/bin/env python3
"""Reorganiza CHANGELOG/DECISIONS en indice completo + cuerpo del mes en curso.

Generalizado desde el reorg_docs.py original de EFCL (ADR-113) para servir a cualquier repo.

Regla (estable, no ventana deslizante):
  <DOC>.md                = preambulo + indice COMPLETO + cuerpo del MES EN CURSO
  <hist>/<DOC>-AAAA-MM.md = cuerpo de cada mes ya cerrado

Nada se borra nunca. Re-ejecutable: el indice se reconstruye siempre sobre el corpus
completo (fichero vivo + historicos), deduplicado por clave.

Dialectos de DECISIONS soportados:
  ## ADR-064 · Titulo        + **Fecha:** 2026-08-10
  ## ADR-001 — Titulo · 2026-06-05
  ## D-001 — Titulo   [2026-04-24]
Un bloque sin fecha reconocible NUNCA se archiva: se queda en el fichero vivo.

Uso: python3 scripts/reorg_docs.py --repo . --dry-run | --apply
"""
import io, os, re, sys, glob, argparse, collections, datetime

FECHA_PATS = [r'\*\*Fecha:\*\*\s*(\d{4}-\d{2}-\d{2})', r'\[(\d{4}-\d{2}-\d{2})\]',
              r'·\s*(\d{4}-\d{2}-\d{2})', r'(\d{4}-\d{2}-\d{2})']
RE_CH = re.compile(r'^## (\d{4}-\d{2}-\d{2})')
RE_ADR = re.compile(r'^## ((?:ADR|D)-\d+)\b')


def recorta(t, n):
    t = re.sub(r'\s+', ' ', t).strip()
    return t if len(t) <= n else t[:n - 1].rstrip() + '…'


def partir(texto, re_entrada):
    trozos = re.split(r'(?m)^(?=## )', texto)
    pre, bloques = [], []
    for t in trozos:
        if re_entrada.match(t):
            bloques.append(t)
        elif bloques:
            bloques[-1] += t
        else:
            pre.append(t)
    return ''.join(pre), bloques


def limpiar_preambulo(pre):
    """Quita del preambulo lo que generamos nosotros en pasadas anteriores.

    Sin esto el script es NO idempotente: el indice viejo queda como preambulo y se
    reemite junto al nuevo, y el fichero crece en cada ejecucion.
    """
    pre = re.sub(r'(?ms)^## Índice de .*?(?=^## |\Z)', '', pre)   # indice previo
    pre = re.sub(r'(?m)\A#\s+[^\n]*\n+', '', pre)                # H1 previo
    pre = re.sub(r'(?m)^>.*(?:índice|Regenerar|histórico|mes en curso).*\n?', '', pre)
    pre = re.sub(r'(?m)^\|.*\|\s*$\n?', '', pre)                  # filas de tabla sueltas
    pre = re.sub(r'(?m)^-{3,}\s*$\n?', '', pre)
    return pre.strip()


def fecha_de(bloque):
    zona = '\n'.join(bloque.split('\n')[:8])
    for p in FECHA_PATS:
        m = re.search(p, zona)
        if m:
            return m.group(1)
    return None


def recoger(repo, doc, hist, re_entrada, clave):
    base = os.path.basename(doc).replace('.md', '')
    fuentes = [os.path.join(repo, doc)] + sorted(glob.glob(
        os.path.join(repo, hist, base + '-[0-9][0-9][0-9][0-9]-[0-9][0-9].md')))
    vistos, bloques, pre0 = set(), [], ''
    for i, f in enumerate(fuentes):
        if not os.path.exists(f):
            continue
        pre, bs = partir(io.open(f, encoding='utf-8').read(), re_entrada)
        if i == 0:
            pre0 = pre
        for b in bs:
            k = clave(b)
            if k not in vistos:
                vistos.add(k)
                bloques.append(b)
    return pre0, bloques


RE_INDICE = re.compile(r'(?s)<!-- INDICE:inicio.*?<!-- INDICE:fin -->')


def indice_previo(repo, rel):
    """Rescata el bloque de indice que inyecta scripts/indexar_doc.py, si lo hay.

    procesar() reconstruye cada fichero de historial desde cero a partir de la cabecera
    y los bloques de entradas. El indice tematico vive en el preambulo, o sea que no es
    ninguna de las dos cosas: sin esto, cada pasada de reorg_docs lo borraba, y
    precisamente en los ficheros de >60 KB, que son los que nadie lee enteros.
    """
    full = os.path.join(repo, rel)
    if not os.path.exists(full):
        return ''
    m = RE_INDICE.search(io.open(full, encoding='utf-8').read())
    return m.group(0).strip() + '\n\n' if m else ''


def escribir(repo, rel, s, apply):
    full = os.path.join(repo, rel)
    if apply:
        d = os.path.dirname(full)
        if d:
            os.makedirs(d, exist_ok=True)
        io.open(full, 'w', encoding='utf-8').write(s)
    print('   %-50s %9d B %s' % (rel, len(s.encode('utf-8')), '' if apply else '(dry-run)'))


def procesar(repo, doc, hist, mes, apply, tipo):
    ruta = os.path.join(repo, doc)
    if not os.path.exists(ruta):
        print('   %-50s (no existe)' % doc)
        return 0
    antes = len(io.open(ruta, encoding='utf-8').read().encode('utf-8'))
    base = os.path.basename(doc).replace('.md', '')
    re_e = RE_CH if tipo == 'changelog' else RE_ADR
    clave = ((lambda b: b.split('\n', 1)[0].strip()) if tipo == 'changelog'
             else (lambda b: RE_ADR.match(b).group(1)))
    pre, bloques = recoger(repo, doc, hist, re_e, clave)
    if not bloques:
        print('   %-50s (0 entradas reconocidas)' % doc)
        return 0

    filas, por_mes = [], collections.OrderedDict()
    for b in bloques:
        cab = b.split('\n', 1)[0]
        if tipo == 'changelog':
            ident = RE_CH.match(cab).group(1)
            fecha, titulo = ident, recorta(cab[len('## ' + ident):].lstrip(' —-·()'), 120)
        else:
            ident = RE_ADR.match(cab).group(1)
            fecha = fecha_de(b)
            titulo = recorta(re.sub(r'\d{4}-\d{2}-\d{2}', '', cab[len('## ' + ident):])
                             .lstrip(' —-·').rstrip(' —-·[]'), 110)
        destino = fecha[:7] if fecha else mes
        por_mes.setdefault(destino, []).append(b)
        donde = 'este fichero' if destino == mes else '`%s/%s-%s.md`' % (hist, base, destino)
        filas.append('| %s | %s | %s |' % (fecha, titulo, donde) if tipo == 'changelog'
                     else '| **%s** | %s | %s | %s |' % (ident, titulo, fecha or '—', donde))

    if tipo == 'changelog':
        cab = ['# %s' % base, '',
               '> Bitácora por sesión. **El índice lista TODAS las entradas.** El cuerpo del mes en curso',
               '> vive aquí; los meses cerrados en `%s/`.' % hist,
               '> Regenerar: `python3 scripts/reorg_docs.py --repo . --apply`.', '',
               '## Índice de sesiones (%d entradas)' % len(bloques), '',
               '| Fecha | Qué pasó | Dónde |', '|---|---|---|']
    else:
        cab = ['# %s — registro de decisiones' % base, '',
               '> **El índice lista TODAS las decisiones.** Para leer el cuerpo de una antigua, abre el',
               '> fichero de su mes en `%s/` — no hace falta cargar el histórico entero.' % hist,
               '> Regenerar: `python3 scripts/reorg_docs.py --repo . --apply`.', '',
               '## Índice de decisiones (%d entradas)' % len(bloques), '',
               '| ID | Decisión | Fecha | Dónde |', '|---|---|---|---|']

    pre_sin_h1 = limpiar_preambulo(pre)
    cuerpo = ''.join(por_mes.get(mes, []))
    vivo = '\n'.join(cab) + '\n' + '\n'.join(filas) + '\n\n---\n\n'
    if pre_sin_h1.strip():
        vivo = ('\n'.join(cab) + '\n' + '\n'.join(filas) + '\n\n---\n\n'
                + pre_sin_h1.strip() + '\n\n---\n\n')
    vivo += cuerpo
    escribir(repo, doc, vivo, apply)
    for m, bs in por_mes.items():
        if m == mes:
            continue
        rel = '%s/%s-%s.md' % (hist, base, m)
        h = ('# %s %s — histórico\n\n> Extraído de `%s`. El índice completo vive allí.\n\n'
             % (base, m, doc))
        escribir(repo, rel, h + indice_previo(repo, rel) + '---\n\n' + ''.join(bs), apply)
    print('       antes %d B -> vivo %d B  (%d entradas indexadas)'
          % (antes, len(vivo.encode('utf-8')), len(bloques)))
    return len(bloques)


def real(repo, rel):
    """Devuelve rel con la capitalizacion REAL en disco, o None.

    macOS es case-insensitive: os.path.exists('docs/DECISIONS.md') da True aunque el
    fichero se llame 'decisions.md'. Escribir con el nombre equivocado hace que git
    vea un rename. Resolvemos contra el listado real del directorio.
    """
    d, n = os.path.split(rel)
    full = os.path.join(repo, d) if d else repo
    if not os.path.isdir(full):
        return None
    for f in os.listdir(full):
        if f.lower() == n.lower():
            return os.path.join(d, f) if d else f
    return None


def autodetect(repo):
    ch = next((r for c in ['CHANGELOG.md', 'docs/CHANGELOG.md']
               for r in [real(repo, c)] if r), None)
    de = next((r for c in ['DECISIONS.md', 'docs/DECISIONS.md']
               for r in [real(repo, c)] if r), None)
    # si las decisiones ya estan partidas en decisions/, su DECISIONS.md es un INDICE
    # GENERADO por split_adrs.py: reindexarlo aqui lo destruiria.
    if de and os.path.isdir(os.path.join(repo, os.path.dirname(de), 'decisions')):
        de = None
    hist = next((h for h in ['docs/historial', 'docs/historico']
                 if os.path.isdir(os.path.join(repo, h))), 'docs/historial')
    return ch, de, hist


if __name__ == '__main__':
    ap = argparse.ArgumentParser()
    ap.add_argument('--repo', default='.')
    ap.add_argument('--changelog'); ap.add_argument('--decisions'); ap.add_argument('--hist')
    ap.add_argument('--month', default=datetime.date.today().strftime('%Y-%m'))
    ap.add_argument('--apply', action='store_true'); ap.add_argument('--dry-run', action='store_true')
    a = ap.parse_args()
    if not (a.apply or a.dry_run):
        sys.exit('usa --dry-run o --apply')
    repo = os.path.abspath(a.repo)
    ch, de, hist = autodetect(repo)
    ch, de, hist = a.changelog or ch, a.decisions or de, a.hist or hist
    print('REPO %s | mes %s | hist %s' % (repo, a.month, hist))
    n = 0
    if ch: n += procesar(repo, ch, hist, a.month, a.apply, 'changelog')
    if de: n += procesar(repo, de, hist, a.month, a.apply, 'decisions')
    print('   entradas preservadas: %d' % n)
