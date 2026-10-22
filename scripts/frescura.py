#!/usr/bin/env python3
"""Informe de frescura: que documentacion lleva demasiado sin tocarse.

Por que git y no un sello 'reviewed:' en el frontmatter: un sello a mano miente en cuanto
alguien se olvida de actualizarlo, y ese olvido es justo lo que estamos intentando detectar.
git no puede mentir sobre CUANDO cambio el fichero. Lo que git NO sabe es si alguien lo leyo
y lo dio por bueno sin cambiarlo — por eso esto es una senal, no un veredicto.

Los documentos con caducidad natural (STATE, CHANGELOG) se miden mas corto que los de
referencia, que pueden ser viejos y correctos.

Uso: python3 scripts/frescura.py [--repo .] [--dias 90]
"""
import os
import re, sys, glob, argparse, subprocess, datetime

# umbral en dias por tipo: lo que describe el AHORA caduca antes que una referencia
UMBRALES = [
    (('state.md', 'estado.md'), 14, 'foto de hoy'),
    (('changelog.md',), 30, 'bitácora'),
    (('roadmap.md',), 60, 'plan'),
    (('claude.md', 'agents.md'), 120, 'reglas'),
    (('runbook.md', 'accesos.md', 'handover.md'), 180, 'operación'),
]
POR_DEFECTO = 90


def umbral(rel):
    base = os.path.basename(rel).lower()
    for nombres, d, etq in UMBRALES:
        if base in nombres:
            return d, etq
    if '/decisions/' in rel.replace('\\', '/'):
        return 3650, 'decisión'          # un ADR viejo es correcto: no caduca
    # con barra delante: una ruta relativa como 'research/x.md' no empieza por '/'
    r = '/' + rel.replace('\\', '/').lstrip('/')
    if '/histori' in r or '/archive' in r:
        return 3650, 'archivo'
    # Un documento que REGISTRA un momento no caduca; caduca el que AFIRMA como
    # funciona algo. Un acta de mayo sigue diciendo la verdad de mayo, igual que un
    # ADR viejo suele ser correcto por serlo. Marcarlos de frios entrena el ojo a
    # ignorar el informe entero, que es como se pierde el que si miente.
    if any(x in r for x in ('/sesiones/', '/meetings/', '/actas/', '/research/',
                            '/raw/', '/samples/', '/exploration/')):
        return 3650, 'registro'
    if re.search(r'\d{4}-\d{2}-\d{2}|\d{4}_\d{2}_\d{2}', os.path.basename(r)):
        return 3650, 'registro'          # una fecha en el nombre lo delata
    return POR_DEFECTO, 'documento'


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--repo', default='.')
    ap.add_argument('--dias', type=int, default=None, help='fuerza un umbral unico')
    a = ap.parse_args()
    repo = os.path.abspath(a.repo)
    hoy = datetime.date.today()

    filas = []
    for f in glob.glob(os.path.join(repo, '**', '*.md'), recursive=True):
        rel = os.path.relpath(f, repo)
        if any(x in rel for x in ('node_modules', '_migrado', '/build/', '.git/')):
            continue
        try:
            out = subprocess.run(['git', '-C', repo, 'log', '-1', '--format=%ad', '--date=short', '--', rel],
                                 capture_output=True, text=True, timeout=20).stdout.strip()
        except Exception:
            continue
        if not out:
            continue
        d = (hoy - datetime.date(*map(int, out.split('-')))).days
        lim, etq = umbral(rel)
        if a.dias:
            lim = a.dias
        if d > lim:
            filas.append((d, lim, etq, rel, os.path.getsize(f)))

    filas.sort(key=lambda x: -(x[0] / float(x[1])))
    if not filas:
        print('Nada desfasado. Todo dentro de su umbral.')
        return
    print('%-52s %6s %6s %-11s %s' % ('DOCUMENTO', 'DÍAS', 'LÍMITE', 'TIPO', 'PESO'))
    for d, lim, etq, rel, sz in filas[:40]:
        print('%-52s %6d %6d %-11s %d KB' % (rel[:52], d, lim, etq, sz // 1024))
    print('\n%d documento(s) por encima de su umbral.' % len(filas))
    print('Un documento viejo no está mal por serlo: mira si lo que AFIRMA sigue siendo cierto.')


main()
