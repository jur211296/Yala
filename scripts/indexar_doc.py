#!/usr/bin/env python3
"""Pone un indice TEMATICO arriba de un documento largo de entradas fechadas.

Por que: un fichero de referencia de mas de 100 lineas que no lleva indice se previsualiza
con `head` y el agente se queda con informacion incompleta SIN AVISAR. El indice hace que,
aunque solo lea el principio, vea el alcance completo y pueda ir a la entrada exacta.

Tematico y no cronologico a proposito: una trampa tecnica se busca por tema ("TMDL",
"Azure SQL", "Deneb"), no por la fecha en que se descubrio.

Uso: python3 scripts/indexar_doc.py docs/aprendizajes-tecnicos.md [--apply]
"""
import io, re, sys, collections

TEMAS = [
    ('Modelo / TMDL / DAX',
     r'tmdl|dax|medida|lineagetag|semanticmodel|modelo|relaci[oó]n|columna|userelationship|'
     r'concatenatex|calculate|auto-date|dim_|clave|unicidad|cohorte|lado uno|jerarqu'),
    ('Informe / PBIR / visuales',
     r'pbir|visual|p[aá]gina|slicer|marcador|bookmark|cabecera|report|tabla|matriz|queryref|'
     r'aggmap|canvas|chasis|theme|clonar|clonado|remap|filtro|eje |ejes|kpi|etiqueta|lienzo'),
    ('Deneb / HTML Content', r'deneb|html|jsonspec|smart ?filter|sfb|vega'),
    ('Datos: Azure SQL / silver / bronze',
     r'azure|sqlcmd|silver|bronce|bronze|\bsp\b|stored|entra|pitr|firewall|\bsql\b|ingesta|'
     r'pipeline|dedup|try_cast|fct_|sys\.|partition|window function|navision|apunte|inventario'),
    ('Entorno / osascript / git',
     r'osascript|git\b|repo|desktop|shell|exit code|python|json\.dump|api\b|fichero que ya estaba'),
    ('Método de verificación',
     r'verificar|verificaci|comprobar|punto ciego|idempotent|distinguir|miente|ment[ií]a|'
     r'ref-check|contar|tapando|casi iguales|no basta'),
    ('Proceso y documentación',
     r'tactiq|bit[aá]cora|compartible|este archivo|convenci[oó]n document|stakeholder|atribucion'),
]

TEMAS_SWIFT = [
    ('Datos / SwiftData / CloudKit', r'swiftdata|cloudkit|modelcontainer|sync|sincroniz|migraci|schema|persist|icloud'),
    ('UI / SwiftUI / diseño', r'swiftui|vista|view|navegaci|dark mode|color|animaci|toolbar|widget|liquid glass|dise'),
    ('Concurrencia / rendimiento', r'concurren|async|await|actor|task|main ?thread|rendimiento|performance|memoria'),
    ('Tests / QA / build', r'test|xctest|xcuitest|qa\b|build|xcodebuild|simulador|derived ?data|ci\b'),
    ('Grupos / backend / gateway', r'grupo|gateway|attest|supabase|backend|servidor|endpoint|api\b'),
]

def elegir_temas(texto):
    """Escoge el juego de temas que mas casa con el documento."""
    import re as _re
    tl = texto.lower()
    pbi = sum(len(_re.findall(p, tl)) for _, p in TEMAS)
    swi = sum(len(_re.findall(p, tl)) for _, p in TEMAS_SWIFT)
    return TEMAS_SWIFT if swi > pbi else TEMAS


_ACTIVOS = None

def tema(t):
    tl = t.lower()
    for nom, pat in (_ACTIVOS or TEMAS):
        if re.search(pat, tl):
            return nom
    return 'Otros'

def indice_vinetas(f, s, vin, apply):
    """Indice de un documento cuya estructura son vinetas '- **Titulo:**', no encabezados."""
    lineas = s[:0]
    idx = []
    for i, (pos, tit) in enumerate(vin):
        fin = vin[i + 1][0] if i + 1 < len(vin) else len(s)
        nlinea = s.count('\n', 0, pos) + 1
        peso = len(s[pos:fin].encode('utf-8'))
        idx.append((nlinea, re.sub(r'\s+', ' ', tit).strip(' :'), peso))
    kb = len(s.encode()) // 1024
    b = ['<!-- INDICE:inicio — generado por scripts/indexar_doc.py, no editar a mano -->', '',
         '## Índice de reglas (%d)' % len(idx), '',
         '> Este fichero son **%d KB en %d reglas largas**. No lo leas entero: localiza la regla' % (kb, len(idx)),
         '> aquí y lee **solo su tramo** con `sed -n \'<linea>,<linea+N>p\'`.',
         '> Los números de línea se desplazan al editar — regenera con',
         '> `python3 scripts/indexar_doc.py <fichero> --apply`.', '',
         '| Línea | Regla | Peso |', '|---|---|---|']
    def filas(off):
        return ['| `L%d` | %s | %s |' % (nl + off, tit[:120],
                ('%.1f KB' % (peso / 1024.0)) if peso >= 1024 else '%d B' % peso)
                for nl, tit, peso in idx]
    # El propio indice desplaza el contenido hacia abajo: se cuenta cuanto ocupa y se
    # corrigen los numeros. Como corregirlos no cambia el numero de lineas del bloque,
    # una sola pasada basta.
    desplaz = len(b) + len(filas(0)) + 3   # +2 del cierre, +1 de la linea en blanco
    b += filas(desplaz)
    b += ['', '<!-- INDICE:fin -->']
    bloque = '\n'.join(b)
    m = re.match(r'(?s)(\A---\n.*?\n---\n+)?(#[^\n]*\n+)((?:>[^\n]*\n|\n)*)', s)
    cab = m.group(0) if m else ''
    out = cab + bloque + '\n\n' + s[len(cab):]
    print('  %s: %d reglas en vinetas, la mayor de %.1f KB' % (f, len(idx), max(p for _, _, p in idx) / 1024.0))
    if apply:
        io.open(f, 'w', encoding='utf-8').write(out)
        print('  escrito: %d -> %d B' % (len(s.encode()), len(out.encode())))
    else:
        print('  (dry-run)')


def main():
    f = sys.argv[1]
    apply = '--apply' in sys.argv
    s = io.open(f, encoding='utf-8').read()
    s = re.sub(r'(?s)<!-- INDICE:inicio.*?<!-- INDICE:fin -->\n*', '', s)  # idempotente

    global _ACTIVOS
    _ACTIVOS = elegir_temas(s)
    n2 = len(re.findall(r'(?m)^## ', s)); n3 = len(re.findall(r'(?m)^### ', s))
    NIVEL = '##' if '--h2' in sys.argv else ('###' if '--h3' in sys.argv else ('###' if n3 > n2 else '##'))
    n4 = len(re.findall(r'(?m)^#### ', s))
    if max(n2, n3, n4) < 8:
        # Sin encabezados suficientes: puede seguir habiendo estructura en vinetas
        # "- **Titulo:**". Se indexan por NUMERO DE LINEA y peso, no por ancla, porque
        # una vineta no genera ancla y porque a un agente le sirve mas saber que puede
        # leer solo ese tramo con sed que tener un enlace que no existe.
        vin = [(m.start(), m.group(1)) for m in re.finditer(r'(?m)^- \*\*(.+?)\*\*', s)]
        if len(vin) >= 8:
            return indice_vinetas(f, s, vin, apply)
        print('  %s: solo %d encabezados y %d vinetas; no hay nada que indexar'
              % (f, max(n2, n3, n4), len(vin)))
        return
    if n4 > max(n2, n3) and '--h2' not in sys.argv and '--h3' not in sys.argv:
        NIVEL = '####'
    print('  nivel de entrada: %s  (##=%d, ###=%d)' % (NIVEL, n2, n3))

    ents = []
    for m in re.finditer(r'(?m)^%s (.+)$' % re.escape(NIVEL), s):
        cab = m.group(1).strip()
        # las lineas plantilla de la seccion "Formato" no son entradas
        if re.search(r'\[(FECHA|T[IÍ]TULO|YYYY|AAAA)', cab, re.I):
            continue
        mf = re.search(r'(\d{4}-\d{2}-\d{2})', cab)
        fecha = mf.group(1) if mf else None
        tit = re.sub(r'^\[?\s*\d{4}-\d{2}-\d{2}\s*\]?', '', cab)   # fuera la fecha inicial
        tit = re.sub(r'^\s*\([^)]{0,20}\)', '', tit)                  # fuera "(4)", "(cierre)"
        tit = tit.lstrip(' —-·:').strip() or cab                       # nunca vacio
        ancla = re.sub(r'[^a-z0-9\s-]', '', cab.lower()).strip().replace(' ', '-')
        ents.append((tema(tit), fecha or '—', tit, ancla))

    por = collections.OrderedDict()
    for t, fe, ti, an in ents:
        por.setdefault(t, []).append((fe, ti, an))

    orden = [n for n, _ in (_ACTIVOS or TEMAS)] + ['Otros']
    # Si la clasificacion no distingue (demasiado en "Otros"), un indice PLANO es mejor:
    # el valor que pide la guia es que una lectura parcial vea el alcance completo, y eso
    # lo da la lista entera. Agrupar mal solo anade ruido.
    ratio = len(por.get('Otros', [])) / float(len(ents))
    plano = '--plano' in sys.argv or ratio > 0.35
    kb = len(s.encode()) // 1024
    b = ['<!-- INDICE:inicio — generado por scripts/indexar_doc.py, no editar a mano -->', '']
    if plano:
        print('  clasificacion pobre (%d%% sin tema) -> indice PLANO' % (ratio * 100))
        b += ['## Índice (%d entradas)' % len(ents), '',
              '> **No hace falta leer este fichero entero** — son %d KB. Localiza la entrada' % kb,
              '> aquí y salta a ella.', '']
        for _t, fe, ti, an in [(t, f_, ti_, an_) for t in orden if t in por for f_, ti_, an_ in por[t]]:
            pass
        for fe, ti, an in sorted([e for t in por for e in por[t]], key=lambda x: x[0], reverse=True):
            b.append('- `%s` [%s](#%s)' % (fe, ti[:100], an))
        b.append('')
    else:
        b += ['## Índice por tema (%d entradas)' % len(ents), '',
              '> Busca aquí por **tema**, no por fecha, y abre solo la entrada que necesites.',
              '> **No hace falta leer este fichero entero** — son %d KB.' % kb, '']
        for t in orden:
            if t not in por: continue
            b += ['### %s (%d)' % (t, len(por[t])), '']
            for fe, ti, an in por[t]:
                b.append('- `%s` [%s](#%s)' % (fe, ti[:96], an))
            b.append('')
    b.append('<!-- INDICE:fin -->')
    bloque = '\n'.join(b)

    s = re.sub(r'(?s)<!-- INDICE:inicio.*?<!-- INDICE:fin -->\n*', '', s)
    m = re.match(r'(?s)(\A#[^\n]*\n+(?:>[^\n]*\n)*\n*)', s)
    out = (m.group(1) + bloque + '\n\n' + s[m.end():]) if m else bloque + '\n\n' + s
    print('  %s: %d entradas en %d temas' % (f, len(ents), len(por)))
    for t in orden:
        if t in por: print('     %-30s %3d' % (t, len(por[t])))
    if apply:
        io.open(f, 'w', encoding='utf-8').write(out)
        print('  escrito: %d -> %d B' % (len(s.encode()), len(out.encode())))
    else:
        print('  (dry-run)')

main()
