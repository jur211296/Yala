---
name: el-arbol-base-contesta-si-es-mio
description: «¿este rojo es mío?» se contesta corriendo la MISMA suite en un worktree desde HEAD, no razonando sobre el diff — y esa corrida cuesta GB de disco que hay que devolver
metadata:
  type: feedback
---

**Cuando la suite falla, la pregunta «¿es mío?» se contesta con una corrida, no con un argumento.**
Y la corrida barata existe: si mis cambios están **sin commitear**, `HEAD` ya es el árbol limpio.

    git worktree add --detach <scratchpad>/base-<sha> HEAD
    cp Secrets.xcconfig <scratchpad>/base-<sha>/          # sin él no compila (regla del repo)
    xcodebuild test -project <base>/Yala.xcodeproj ...    # la MISMA suite, mismo simulador

**Why:** el 2026-09-06, `YalaTests` completa me dio rojos que no tocaban nada mío. Tres greps
demostraban que esos tests no mencionaban mis ficheros — evidencia fuerte y **no concluyente**, porque
la mitad eran *source-scans* que leen el árbol entero. La corrida del base zanjó en 90 s lo que
ninguna lectura iba a zanjar: **el árbol limpio fallaba con 3 y el mío con 1, y los conjuntos eran
disjuntos**. Tres corridas, tres conjuntos distintos ⇒ rojos no deterministas, ninguno mío. Escribir
«preexistente» sin eso habría sido inferencia disfrazada de medición, y la regla del repo prohíbe
justamente eso.

**How to apply:**

- **Compara suites ARRANCADAS, no solo el veredicto.** Es lo que descarta que mi cambio haya dejado
  suites sin correr —la familia del «cero casos»—:

      grep -oE '◇ Suite "?[^"]*"? started' <log> | sort -u | wc -l

  El mío dio 629 y el base 628, con una sola diferencia: mi suite nueva. Eso, y no el número de
  fallos, es lo que prueba que no perdí cobertura.
- **Cuenta los casos, pero NO con un grep anclado en `^` — eso es lo que me falló.** Los `print` de la
  app y el reporter comparten stdout sin lock: un log a media línea la parte en dos y ninguna mitad
  casa con `^✔ Test .* passed`. Medido el 2026-09-07 sobre tres corridas del mismo árbol, el grep
  anclado dio **6360 · 6353** (perdiendo 43-50 distintas cada vez) y `Test run with` dio **6414** las
  tres. ⇒ **el resumen NO miente; mentía mi grep.** Para el detalle por caso, `-resultBundlePath` +
  `xcrun xcresulttool get test-results summary --path <bundle>`. Si rascas el log, sin ancla
  (`grep -o '✘ Test '`). Lo de «reportó 5784 in 594 mientras el conteo daba 6139 en 629» era esto
  mismo leído al revés.
- **Confirma aislando.** Un rojo que pasa con `-only-testing` y falla en la suite completa es
  interacción (estado global / orden), nunca tu diff.
- **Y si el rojo sobrevive a todo esto, va a ticket.** «Preexistente» no cierra nada: la regla del
  repo pide arreglarlo o registrarlo con dueño y fecha.

## Lo que cuesta, y hay que devolverlo

**La corrida de contraste se come el disco, y el disco es el que hace fallar los XCUITest.** Ese día
empecé con 20 GB (ya bajo el umbral de 25) y **acabé en 5,9 GB**: el worktree base generó 2,4 GB de
DerivedData propio y XcodeBuildMCP otros 4,2 GB. El siguiente paso del gate —XCUITest— es justo el que
el `CLAUDE.md` avisa que se rompe con el disco lleno, así que la medición que me daba la respuesta me
dejaba sin poder terminar el gate.

- **Retira el worktree en cuanto tengas el dato** (`git worktree remove --force`) y **borra su
  DerivedData**, que no se va con él. Se identifica por su `info.plist`:

      plutil -extract WorkspacePath raw ~/Library/Developer/Xcode/DerivedData/Yala-*/info.plist

- **`qa/scripts/session-cleanup.sh --derived` borra el DerivedData de TODAS las sesiones**, incluida
  la de otro worktree vivo de otra sesión. Su dry-run lo enseña; léelo antes de `--apply`. Lo mío lo
  borro yo; lo de otra sesión se queda ([[push-solo-lo-de-la-sesion]]).
- `rm -rf` está bloqueado por permisos en este entorno; `find <ruta> -depth -delete` sí pasa.

## La trampa que invalidó mi primera medición entera

**No canalices `xcodebuild` a `tail`.** El SIGPIPE corta la corrida a media suite, y el resumen que
queda (`1959 tests in 210 suites`) tiene toda la pinta de un dato. Perdí una corrida completa y estuve
a punto de investigar por qué «mi cambio hacía desaparecer 4000 tests». Redirige a un fichero y filtra
después. Es familia de [[mis-mediciones-fallan-por-el-filtro]], pero el filtro aquí no descarta
líneas: **mata el proceso que las produce**.
