#!/usr/bin/env python3
"""suites-de-fichero.py — de un fichero de test a los TIPOS que `-only-testing` sabe filtrar.

    python3 -I qa/scripts/suites-de-fichero.py YalaTests/A.swift [YalaTests/B.swift …]
    python3 -I qa/scripts/suites-de-fichero.py --only-testing YalaTests YalaTests/A.swift …

**Por qué existe.** `-only-testing:YalaTests/<X>` casa por el nombre del TIPO, no por el del
fichero, y si no casa `xcodebuild` sale con `TEST SUCCEEDED` sin avisar. En este repo hay más de
cincuenta ficheros cuyas suites no se llaman como ellos: `LocalizationParityTests.swift` declara
tres (`LocalizationParityTests`, `BundleLocaleDriftTests`, `StringsdictParityTests`) y ninguna
lleva `@Suite`, así que tampoco las encuentra un `grep "@Suite"`. `/l10n-check` corrió solo la
primera durante semanas y se dejaba cuatro casos sin correr.

**Qué cuenta como suite.** Un tipo declarado en la columna 0 (`struct`, `class`, `enum`, `actor`
o `extension`) que lleva `@Suite` delante o algún `@Test` dentro, antes de la siguiente
declaración de columna 0. Los tipos anidados no salen: pedir el de fuera ya los corre. Una
`extension` cuenta por el tipo que extiende, aunque ese tipo viva en otro fichero.

Mira solo código: los comentarios y las cadenas se vacían antes de buscar, para que un `@Test`
citado en un comentario o en el mensaje de un `#expect` no fabrique una suite.

Salida: un nombre por línea, en orden de aparición y sin repetir (con `--only-testing T`, cada uno
como `-only-testing:T/<Tipo>`). Exit: 0 = todos los ficheros tienen al menos una suite · 1 = alguno
no tiene ninguna (se dice cuál por stderr: es un gap, no un verde) · 2 = uso o fichero ilegible.

Banco: `qa/scripts/suites-de-fichero-test.sh`.
"""
import re
import sys

USO = 'uso: suites-de-fichero.py [--only-testing TARGET] FICHERO…'

# Atributos delante (`@MainActor`, `@Suite("…")`), modificadores y la palabra clave del tipo.
DECL = re.compile(
    r'^((?:@[\w.]+(?:\([^)\n]*\))?\s+)*)'
    r'(?:(?:public|private|fileprivate|internal|final|nonisolated)\s+)*'
    r'(?:struct|class|enum|actor|extension)\s+([A-Za-z_]\w*)'
)
TEST_ATTR = re.compile(r'(?<![\w.])@Test\b')
SUITE_ATTR = re.compile(r'(?<![\w.])@Suite\b')


def sin_comentarios(src):
    """Quita // y /* */ (anidables, como en Swift) y vacía las cadenas, crudas y multilínea.

    Conserva los saltos de línea, para que la columna 0 siga siendo la columna 0.
    """
    out, i, n = [], 0, len(src)
    while i < n:
        c = src[i]
        crudo = re.match(r'(#+)("""|")', src[i:i + 64]) if c == '#' else None
        if crudo:                                         # cadena cruda: #"…"#, #"""…"""#
            fin = crudo.group(2) + crudo.group(1)
            j = src.find(fin, i + crudo.end())
            j = n if j < 0 else j + len(fin)
            out.append('""' + '\n' * src.count('\n', i, j)); i = j
        elif src.startswith('"""', i):                    # cadena multilínea
            j = src.find('"""', i + 3)
            j = n if j < 0 else j + 3
            out.append('""' + '\n' * src.count('\n', i, j)); i = j
        elif c == '"':                                    # cadena de una línea
            j = i + 1
            while j < n and src[j] not in '"\n':
                j += 2 if src[j] == '\\' else 1
            j = min(j + 1, n)
            out.append('""'); i = j
        elif src.startswith('//', i):                     # comentario de línea (también ///)
            j = src.find('\n', i)
            i = n if j < 0 else j
        elif src.startswith('/*', i):                     # comentario de bloque, anidable
            prof, j = 1, i + 2
            while j < n and prof:
                if src.startswith('/*', j): prof += 1; j += 2
                elif src.startswith('*/', j): prof -= 1; j += 2
                else: j += 1
            out.append('\n' * src.count('\n', i, j)); i = j
        else:
            out.append(c); i += 1
    return ''.join(out)


def suites(codigo):
    """Tipos de columna 0 con `@Suite` delante o algún `@Test` en su tramo, en orden."""
    encontradas = []
    actual, es_suite, suite_pendiente = None, False, False
    for linea in codigo.split('\n'):
        en_columna_0 = linea[:1] not in ('', ' ', '\t', '}', ')', ']')
        if en_columna_0:
            m = DECL.match(linea)
            if m:
                if actual and es_suite:
                    encontradas.append(actual)
                actual = m.group(2)
                es_suite = (suite_pendiente or bool(SUITE_ATTR.search(m.group(1)))
                            or bool(TEST_ATTR.search(linea[m.end():])))
                suite_pendiente = False
                continue
            if linea.startswith('@'):
                # Un atributo en su propia línea se apunta para la declaración que viene.
                suite_pendiente = suite_pendiente or bool(SUITE_ATTR.search(linea))
            else:
                suite_pendiente = False
        if actual and TEST_ATTR.search(linea):
            es_suite = True
    if actual and es_suite:
        encontradas.append(actual)
    return encontradas


def main(argv):
    target = None
    if argv[:1] == ['--only-testing']:
        if len(argv) < 2:
            print(USO, file=sys.stderr)
            return 2
        target, argv = argv[1], argv[2:]
    if not argv:
        print(USO, file=sys.stderr)
        return 2
    vistas, sin_suite = [], []
    for ruta in argv:
        try:
            with open(ruta, encoding='utf-8', errors='replace') as f:
                codigo = sin_comentarios(f.read())
        except OSError as e:
            print(f'suites-de-fichero: no puedo leer {ruta}: {e}', file=sys.stderr)
            return 2
        propias = suites(codigo)
        if not propias:
            sin_suite.append(ruta)
        for s in propias:
            if s not in vistas:
                vistas.append(s)
    for s in vistas:
        print(f'-only-testing:{target}/{s}' if target else s)
    for ruta in sin_suite:
        print(f'suites-de-fichero: {ruta} no declara ninguna suite (gap)', file=sys.stderr)
    return 1 if sin_suite else 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
