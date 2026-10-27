# Encargo · CI rojo: cola de reparación de tipos de cambio (PR tests 2.2)

Card: CI rojo: cola de reparación de tipos de cambio (PR tests 2.2) · proyecto Yala · v2.2 · cierre cierra-sola · prioridad alta.

## Contexto
- PR: https://github.com/jur211296/Yala/pull/645 — «fix(tests): cinco tests rojos de 2.2» contra `2.2` (salió de S9). No mergea.
- Check `tests` rojo. Run: https://github.com/jur211296/Yala/actions/runs/40415867578 · commit 15e0456.
- Fallan 3 tests de `FXRepairQueueTests`:
  - `partialRow_secondRecalculateWritesNothing`
  - `completedRow_recalculateWritesAndSealsAsFinal`
  - `ensureRates_withFullCoverage_doesNotHitProvider`
- Además cayó el proceso de tests (crash del runner/host app) en ese run.

## Pedido
1. Leer el log completo del run (`gh run view 40415867578 --log-failed`) y reproducir local los 3 tests.
2. Determinar si es fallo real (regresión del código de la cola FX) o test frágil/aislamiento (estado compartido, reloj, proveedor no stubbeado, orden de tests), y si la caída del proceso es la causa o algo aparte.
3. Arreglar la causa raíz: los 3 tests verdes y sin caída del proceso. Preferir arreglar tests/fixtures; tocar código de app solo si hay bug real, mínimo.
4. Empujar al PR #645 (o PR hermano contra 2.2 si no conviene) y dejar CI `tests` verde para auto-merge.

## Qué NO tocar
- Nada de UI ni features fuera de la cola de reparación FX.
- No desactivar/skip los tests ni subir reintentos para tapar el rojo.
- No tocar el script de gate/reintentos del CI (S10, PR #646) salvo que sea la causa demostrada.
- No mergear a mano saltando checks.

## Cómo se sabe que está bien
- Los 3 tests pasan local varias veces seguidas (y la suite FX entera).
- Run de CI con `tests` verde en el PR, sin caída del proceso.
- PR listo para merge a 2.2; card a in qa con resumen de causa.

## Dependencias
- Arranca sobre `origin/2.2` (o la rama del PR #645 actualizada); `git fetch` y rebase sobre origin/2.2 antes de empujar/abrir PR.
- Va tras S11 (Una sola Yala); si toca archivos que S11 también tocó, rebase y resolver.

## Cierre
La sesión termina con `/cerrar-total`.

## Paso 0 — decisiones (resueltas en autónomo, bypass)

1. **¿Fallo real o test frágil?** Test frágil. Medido en el log del run 40415867578: los tres
   tests mueren con `Fatal error: Dictionary literal contains duplicate keys`. El literal
   `["USD": 1.0, preferred: 3.75]` repite clave cuando la preferida del entorno es "USD" — la de
   la región del runner (`en_US`) con el `UserDefaults` limpio. Antes otra suite filtraba una
   preferida no-USD al `UserDefaults` real; #645 cortó esa fuga y destapó la fragilidad.
2. **¿La caída del proceso es aparte?** No: es la misma causa. Un literal con clave repetida es un
   trap y tumba el proceso entero; el runner reinicia y el test vuelve a morir.
3. **¿Código de app?** No se toca. La cola FX no tiene bug; el arreglo vive solo en
   `YalaTests/FXRepairQueueTests.swift`.
4. **Forma del arreglo.** Helper `partialRates(preferred:)` que parte de la base y añade la
   preferida solo si no es "USD" (si lo es, su tasa ya es 1.0). Se aplica a los **cuatro**
   literales con la preferida dentro, incluido `ensureRates_withPartialRow_refetchesThatDate`, que
   el CI no listó pero comparte el patrón. No se fija la preferida escribiendo en `.standard`:
   sería volver a la fuga que #645 acaba de cerrar.
5. **Dónde se entrega.** Commit encima de la rama de #645 (ya en cola de auto-merge): el rojo solo
   existe con su cambio, así que el arreglo viaja con él. Sin force-push; el ruleset de 2.2 no
   exige ir al día.
6. **Reproducción local.** Forzar `defaultCurrencyCode = USD` en el simulador antes de correr la
   suite para ver el rojo, y repetir en verde con el arreglo varias veces.
