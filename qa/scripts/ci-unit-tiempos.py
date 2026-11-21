#!/usr/bin/env python3
"""ci-unit-tiempos.py — la tabla de segundos por suite con que `ci-unit-tandas.sh` reparte los unit.

    python3 qa/scripts/ci-unit-tiempos.py extraer <tanda.xcresult> <salida.json>
    python3 qa/scripts/ci-unit-tiempos.py generar <run-id> [<run-id> …] [--dir D] [--salida F]

`extraer` lo corre cada tanda del job `unit` sobre el `.xcresult` de su primera vuelta y sube el
JSON como artefacto `unit-tiempos-<tanda>`. `generar` baja esos artefactos de uno o varios runs
(`gh run download`) y escribe `qa/ci-unit-tiempos.json`: cada suite pesa la MEDIANA de lo que midió
en los runs donde corrió. Con `--dir D` no baja nada: lee `D/<run-id>/**/*.json`.

QUÉ PESA UNA SUITE. La suma de lo que tardan sus casos (`durationInSeconds` del `.xcresult`), más
`por_caso_s` por caso. Swift Testing corre los casos a la vez dentro del proceso, así que la suma no
es el reloj del paso (en el run 44890016796 sumaban 2 216 s en ~20 min de paso), pero sirve para
repartir: lo que importa es que las tandas pesen parecido entre sí.

CUÁNDO REGENERARLA. Cuando las tandas del job `unit` se descompensen (una tarda varios minutos más
que las otras), o tras mover muchas suites. Mejor tres runs que uno: la mediana amortigua un runner
lento. Una suite que no está en la tabla pesa por sus `@Test`; nunca se queda sin correr.

Formato del `.xcresult` medido con Xcode 27 (`xcresulttool get test-results tests`): nodos
`Test Plan` → bundle (`Unit test bundle`) → `Test Suite` (tipo de columna 0) → … → `Test Case` con
`durationInSeconds`. El `name` de una suite es su nombre visible (`@Suite("…")`); el tipo sale del
último tramo de `nodeIdentifierURL` (`test://com.apple.xcode/Yala/YalaTests/<Tipo>`). Una función `@Test` suelta cuelga directamente del bundle y no entra en la
tabla (la corre la última tanda). Banco: `qa/scripts/ci-unit-tiempos-test.sh`.
"""
import glob
import json
import os
import statistics
import subprocess
import sys
import tempfile

RAIZ = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
POR_CASO_S = 0.05
CONTEXTO_S = 240


def casos(nodo):
    """(segundos, número) de todos los Test Case bajo `nodo`."""
    if nodo.get('nodeType') == 'Test Case':
        return float(nodo.get('durationInSeconds') or 0), 1
    s, n = 0.0, 0
    for h in nodo.get('children', []):
        ds, dn = casos(h)
        s += ds
        n += dn
    return s, n


def por_suite(arbol):
    """{suite: {"s": segundos, "casos": n}} de las suites de primer nivel de cada bundle."""
    fuera = {}
    for plan in arbol.get('testNodes', []):
        bundles = plan.get('children', []) if plan.get('nodeType') == 'Test Plan' else [plan]
        for b in bundles:
            for s in b.get('children', []):
                if s.get('nodeType') != 'Test Suite':
                    continue
                # `name` es el nombre visible de `@Suite("…")`; el TIPO, que es lo que entiende
                # `-only-testing`, es el último tramo de `nodeIdentifierURL`.
                tipo = (s.get('nodeIdentifierURL') or '').rstrip('/').rsplit('/', 1)[-1] or s.get('name', '?')
                seg, n = casos(s)
                previo = fuera.get(tipo, {'s': 0.0, 'casos': 0})
                fuera[tipo] = {'s': round(previo['s'] + seg, 3), 'casos': previo['casos'] + n}
    return fuera


def extraer(xcresult, salida):
    try:
        crudo = subprocess.run(['xcrun', 'xcresulttool', 'get', 'test-results', 'tests', '--path', xcresult],
                               capture_output=True, text=True, check=True).stdout
        suites = por_suite(json.loads(crudo))
    except (OSError, subprocess.CalledProcessError, ValueError) as e:
        print(f'ci-unit-tiempos: no pude leer {xcresult}: {e}', file=sys.stderr)
        return 1
    if not suites:
        print(f'ci-unit-tiempos: {xcresult} no trae ninguna suite', file=sys.stderr)
        return 1
    with open(salida, 'w', encoding='utf-8') as f:
        json.dump({'suites': suites}, f, ensure_ascii=False, indent=1, sort_keys=True)
    print(f'ci-unit-tiempos: {len(suites)} suites, {sum(v["casos"] for v in suites.values())} casos → {salida}')
    return 0


def generar(argv):
    runs, d, salida = [], None, os.path.join(RAIZ, 'qa', 'ci-unit-tiempos.json')
    i = 0
    while i < len(argv):
        if argv[i] == '--dir':
            d = argv[i + 1]; i += 2
        elif argv[i] == '--salida':
            salida = argv[i + 1]; i += 2
        else:
            runs.append(argv[i]); i += 1
    if not runs:
        print('uso: ci-unit-tiempos.py generar <run-id> [<run-id> …] [--dir D] [--salida F]', file=sys.stderr)
        return 2
    if d is None:
        d = tempfile.mkdtemp(prefix='unit-tiempos-')
        for r in runs:
            destino = os.path.join(d, r)
            os.makedirs(destino, exist_ok=True)
            res = subprocess.run(['gh', 'run', 'download', r, '--pattern', 'unit-tiempos-*', '--dir', destino])
            if res.returncode != 0:
                print(f'ci-unit-tiempos: no pude bajar los tiempos del run {r}', file=sys.stderr)
                return 1
    medidas = {}
    for r in runs:
        ficheros = glob.glob(os.path.join(d, r, '**', '*.json'), recursive=True)
        if not ficheros:
            print(f'ci-unit-tiempos: el run {r} no trae tiempos (¿corrió el job unit?)', file=sys.stderr)
            return 1
        del_run = {}
        for f in ficheros:
            for s, v in json.load(open(f, encoding='utf-8'))['suites'].items():
                del_run[s] = del_run.get(s, 0.0) + v['s'] + v['casos'] * POR_CASO_S
        for s, seg in del_run.items():
            medidas.setdefault(s, []).append(seg)
    previa = {}
    if os.path.isfile(salida):
        try:
            previa = json.load(open(salida, encoding='utf-8')).get('_meta', {})
        except ValueError:
            previa = {}
    tabla = {
        '_meta': {
            'runs': [int(r) if r.isdigit() else r for r in runs],
            'como': 'python3 qa/scripts/ci-unit-tiempos.py generar <run-id> [<run-id> …]; '
                    'segundos por suite = suma de sus casos + por_caso_s por caso, mediana entre runs',
            'por_caso_s': POR_CASO_S,
            'contexto_s': previa.get('contexto_s', CONTEXTO_S),
        },
        'suites': {s: round(statistics.median(v), 1) for s, v in sorted(medidas.items())},
    }
    with open(salida, 'w', encoding='utf-8') as f:
        json.dump(tabla, f, ensure_ascii=False, indent=2)
        f.write('\n')
    print(f'ci-unit-tiempos: {len(medidas)} suites de {len(runs)} run(s) → {salida}')
    return 0


def main(argv):
    if argv[:1] == ['extraer'] and len(argv) == 3:
        return extraer(argv[1], argv[2])
    if argv[:1] == ['generar']:
        return generar(argv[1:])
    print(__doc__.strip().split('\n\n')[1], file=sys.stderr)
    return 2


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
