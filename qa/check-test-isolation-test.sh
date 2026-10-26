#!/usr/bin/env bash
# Banco de qa/check-test-isolation.sh (2026-10-26). Corre el check sobre ficheros .swift de mentira
# en un directorio temporal, uno por caso, y comprueba si pasa o cae.
#
#   bash qa/check-test-isolation-test.sh
#
# Por qué existe: el check buscaba `makeTestContext(` con `grep` en el fichero entero, comentarios
# incluidos, y una cabecera que solo NOMBRABA la función dejó el PR #634 en cola toda una noche.
# Los casos que «caen» son los que impiden arreglar eso a base de dejar de mirar: una llamada real
# sin `.serialized` tiene que seguir cayendo, también detrás de una cadena cruda con comillas
# dentro (`#"…"…"#`, que desalineó la primera versión del arreglo) o de una URL en una cadena.
set -uo pipefail

AQUI="$(cd "$(dirname "$0")" && pwd)"
CHECK="$AQUI/check-test-isolation.sh"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT

fallos=0
# caso <nombre> <pasa|cae> <contenido del .swift>
caso() {
  local nombre="$1" esperado="$2" contenido="$3" d="$T/$1" obtenido
  mkdir -p "$d"
  printf '%s\n' "$contenido" > "$d/Prueba.swift"
  if bash "$CHECK" "$d" > "$d/log" 2>&1; then obtenido=pasa; else obtenido=cae; fi
  if [ "$obtenido" = "$esperado" ]; then
    echo "ok   $nombre ($obtenido)"
  else
    echo "FALLO $nombre: $obtenido (esperado: $esperado)"
    sed 's/^/      | /' "$d/log"
    fallos=$((fallos + 1))
  fi
}

# Lo que NO es una llamada: tiene que pasar sin `.serialized`.
caso comentario_de_linea pasa '// Esta suite no usa makeTestContext() a propósito.
struct A { func t() {} }'
caso comentario_doc pasa '/// Ver `makeTestContext()` en TestHelpers.
struct A { func t() {} }'
caso comentario_de_bloque pasa '/* makeTestContext() reusa el container.
   /* anidado: makeTestContext() */ sigue siendo comentario */
struct A { func t() {} }'
caso comentario_al_final pasa 'struct A { func t() {} } // antes llamaba a makeTestContext()'
caso en_una_cadena pasa 'struct A { func t() { #expect(true, "makeTestContext() reusa el container") } }'
caso en_una_cadena_multilinea pasa 'struct A { func t() { let s = """
  makeTestContext() reusa
  """ } }'
caso definicion pasa 'func makeTestContext(fileID: String = #fileID) throws -> ModelContext { fatalError() }'

# Lo que SÍ es una llamada: sin `.serialized` en el código, cae.
caso llamada_sin_serialized cae 'struct A { func t() throws { let c = try makeTestContext() } }'
caso llamada_con_serialized pasa '@Suite("A", .serialized)
struct A { func t() throws { let c = try makeTestContext() } }'
caso serialized_solo_en_comentario cae '// Debería ser @Suite(.serialized)
struct A { func t() throws { let c = try makeTestContext() } }'
caso llamada_tras_cadena_cruda cae 'struct A { func t() throws {
  let h = #""date","amount""#
  let c = try makeTestContext()
} }'
caso llamada_tras_url cae 'struct A { func t() throws { let u = "https://x.y"; let c = try makeTestContext() } }'
caso llamada_tras_comillas_escapadas cae 'struct A { func t() throws { let s = "dijo \"hola\" // no es comentario"; let c = try makeTestContext() } }'

# El árbol real tiene que pasar: si no, el arreglo tumbaría el CI que vino a desatascar.
if bash "$CHECK" > "$T/real.log" 2>&1; then
  echo "ok   árbol real ($(tail -n 1 "$T/real.log"))"
else
  echo "FALLO árbol real"; sed 's/^/      | /' "$T/real.log"; fallos=$((fallos + 1))
fi

if [ "$fallos" -eq 0 ]; then
  echo "── check-test-isolation: todos los casos en verde."
else
  echo "── check-test-isolation: $fallos caso(s) en ROJO."
  exit 1
fi
