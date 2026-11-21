#!/usr/bin/env bash
# El veredicto del check `tests`: junta el build y las tandas del job `unit` de `qa.yml` y sale en
# verde SOLO si todo corrió y salió en verde. Deja las mismas salidas que tenía el job `tests` cuando
# lo hacía todo en un runner (`unit_pure`, `unit_pure_rojos`, `unit_context`, `unit_context_rojos`),
# para que el job `aviso` las lea igual.
#
#   bash qa/scripts/ci-unit-resultado.sh        # lee el entorno; lo llama el job `tests`
#
# POR QUÉ (2026-11-21). Los unit pasaron a un build y tres tandas en paralelo (auditoría de tiempos
# del CI), pero el ruleset de 2.3 exige un check que se llama exactamente `tests`. Ese check es ahora
# este paso, en un Ubuntu. Un verde aquí tiene que significar lo mismo que antes: se corrió TODO y
# nada quedó en rojo. Por eso falla cerrado: un resultado vacío (tanda cancelada, salida perdida,
# build caído) es rojo, nunca «no aplica».
#
# Entorno:
#   BUILD, UNIT            `needs.<job>.result` de `build` y de la matriz `unit`
#   TANDAS                 las tandas de la matriz, separadas por espacios («1 2 3»)
#   PURE_<k>, ROJOS_<k>    `outcome` del paso pure-logic de la tanda k y los tests que siguen en rojo
#   CONTEXTO, CONTEXTO_ROJOS   lo mismo, del paso context-based (corre en la tanda 1)
#
# Salidas: `unit_pure` y `unit_context` valen `success`, `failure` o vacío (alguna tanda no dejó
# resultado: el aviso lo lee como «no llegó a correr»). Banco: `ci-unit-resultado-test.sh`.
set -uo pipefail

SALIDA="${GITHUB_OUTPUT:-/dev/stdout}"
RESUMEN="${GITHUB_STEP_SUMMARY:-/dev/null}"
TANDAS="${TANDAS:-}"

[ -n "$TANDAS" ] || { echo "::error title=tests::Falta TANDAS: no sé cuántas tandas mirar."; exit 1; }

pure=success
rojos=""
filas=""
for k in $TANDAS; do
  v="PURE_$k"; r="${!v:-}"
  v="ROJOS_$k"; rj="${!v:-}"
  case "$r" in
    success) ;;
    failure) [ "$pure" = "" ] || pure=failure ;;
    *) pure="" ;;
  esac
  [ -z "$rj" ] || rojos="$rojos${rojos:+ }$rj"
  filas="$filas| pure-logic, tanda $k | ${r:-sin resultado} | ${rj:-} |\n"
done

contexto="${CONTEXTO:-}"
case "$contexto" in success|failure) ;; *) contexto="" ;; esac
filas="$filas| context-based (tanda 1) | ${contexto:-sin resultado} | ${CONTEXTO_ROJOS:-} |\n"

{
  echo "unit_pure=$pure"
  echo "unit_pure_rojos=$rojos"
  echo "unit_context=$contexto"
  echo "unit_context_rojos=${CONTEXTO_ROJOS:-}"
} >> "$SALIDA"

{
  echo "### Unit tests"
  echo "Build: \`${BUILD:-sin resultado}\` · tandas: \`${UNIT:-sin resultado}\`"
  echo
  echo "| Paso | Resultado | Siguen en rojo |"
  echo "|---|---|---|"
  printf '%b' "$filas"
} >> "$RESUMEN"

motivo=""
if [ "${BUILD:-}" != success ]; then
  motivo="el build acabó en '${BUILD:-vacío}': no hay nada probado"
elif [ "${UNIT:-}" != success ]; then
  motivo="las tandas acabaron en '${UNIT:-vacío}'"
elif [ "$pure" != success ]; then
  motivo="pure-logic: '${pure:-sin resultado en alguna tanda}'"
elif [ "$contexto" != success ]; then
  motivo="context-based: '${contexto:-sin resultado}'"
fi

if [ -n "$motivo" ]; then
  echo "::error title=tests::En rojo — $motivo.${rojos:+ Siguen en rojo: $rojos.}${CONTEXTO_ROJOS:+ Context-based: $CONTEXTO_ROJOS.}"
  exit 1
fi
echo "tests: build y $(wc -w <<< "$TANDAS" | tr -d ' ') tandas en verde, context-based incluido."
