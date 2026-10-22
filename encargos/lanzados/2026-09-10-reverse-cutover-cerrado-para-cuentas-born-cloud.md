# Abrir «Volver a iCloud» a cuentas born-cloud

## Contexto
Jürgen 2026-09-10 decidió **abrir** la reversa a quien nació en la nube (no aplazar, no v-futura). Ticket: `reverse-cutover-cerrado-para-cuentas-born-cloud` (high).

Hoy `reverse_claim` rechaza si `migrated_at is null` (golden 11 lo pinnea). Tras el fresh start del paso 2, toda cuenta nueva es born-cloud → nadie puede degradar `complete → groups_only` ni recorrer la fila E de la matriz.

La degradación `kind` ya existe en `reverse_complete` (paso 2). Falta la **puerta** y el camino de **export a CloudKit por primera vez** (no es restaurar un mirror previo).

Cola del rediseño: pasos 0–3 en `2.1`. Tras este ticket se retoma el paso 4 (`welcome-private-fresh-start-skips-icloud-check`).

MODO AUTÓNOMO HASTA TERMINAR: gate/commit/board/`docs/TICKETS.md`/merge/`/cerrar-total` sin preguntar. Bugs/decisiones nuevas → ticket `--solo-crear`. Ambigüedad NUEVA: elige lo más seguro alineado con «abrir born-cloud» y regístralo. Para solo por credencial/acceso real.

Avisos a Frank: (1) bloqueo acceso; (2) PR; (3) `/cerrar-total` resumen producto; (4) idle — una vez.

## Que se pide
1. Leer ticket entero + ADR §11 + fila E de la matriz + código de `reverse_claim` / `ReverseEligibility` / golden 11.
2. Quitar o condicionar el guard `not_migrated`; implementar export a CloudKit para born-cloud que nunca tuvo mirror; cliente y tests al día.
3. Verificar en staging: born-cloud completa el ciclo y termina `kind='groups_only'` con lo personal en iCloud (device-QA de CloudKit → dejar en `qa/` si el sim no basta).
4. Actualizar ADR/matriz si hace falta para decir que born-cloud SÍ puede volver.
5. Un PR a `2.1` + `/cerrar-total`.

## Que NO hay que tocar
marketing/. Wipe adicional de prod. Pasos 4–13 del rediseño salvo lo mínimo que toque esta puerta.

## Como se sabe que esta bien
Criterios del ticket (rama «si se abre»); golden 11 revisado; PR mergeado; board/`TICKETS.md` al día; `/cerrar-total`.

## Paso 0 — decisiones (resueltas en autónomo, bypass)

Jürgen ya contestó el nodo raíz del ticket («¿se abre la reversa a born-cloud?» → **sí**). Estas son las
siete que esa respuesta deja abiertas. El desarrollo completo, con las mediciones que las sostienen, está
en `tickets/in-progress/reverse-cutover-cerrado-para-cuentas-born-cloud.md` §Paso 0 — aquí va el veredicto.

| # | Nodo | Resuelto |
|---|---|---|
| D1 | ¿Qué sustituye al guard `migrated_at`? | **El tipo de cuenta**: `kind <> 'complete' → not_complete`. Es la columna que el ADR §11 puso para esa pregunta, y de paso cierra una puerta abierta: una cuenta YA revertida conserva `migrated_at` y podía re-reclamar la reversa (medido) |
| D2 | ¿Rompe el takeover de una migración abandonada (golden 12)? | **No.** `claim_account` escribe `kind='complete'` en el mismo UPDATE que arma la migración, no al terminar. Verificado en sandbox |
| D3 | ¿Hay que construir el export a CloudKit? | **No — la premisa del ticket es falsa.** La reversa no sube nada a mano: monta el mirror y `NSPersistentCloudKitContainer` exporta solo; `reverseUpload` solo **sondea**, y ya cuenta como pendientes las filas sin metadata, que es justo el estado de un corpus que nunca estuvo en CloudKit |
| D4 | ¿Basta con borrar `hasCKMap` del gate del cliente? | **No.** Ese guardarraíl es para el **migrado sin mapa** (riesgo: resurrección de borrados al remontar el mirror sobre una zona que aún tiene records). Born-cloud no tiene esa zona. Se **distingue** con el `CloudMigrationMarker` —lo escribe el cutover y solo el cutover—; el migrado-sin-mapa sigue excluido |
| D5 | ¿Funciona el resto del motor en born-cloud? | **Sí, medido**: `reverseSeqCut` cae a 0 (el código lo declara correcto), `sweepZombies` y `healDuplicates` aplican igual, `verifyRebinds` da 0. Ninguno lee `ckRecordName` |
| D6 | ¿Se arregla el copy («tus datos **regresan** a tu iCloud» a quien nunca estuvo)? | **No aquí.** `.claude/rules/l10n.md` dice «no reescribas copy que ya funciona» y son 16 locales: es voz de producto, de Jürgen → ticket propio |
| D7 | ¿Orden de despliegue? | **La base antes que el cliente.** La migración es compatible hacia atrás en las tres poblaciones; al revés no (el botón aparecería y el servidor lo rechazaría) |

**Lo que queda para Jürgen y no decido yo:** el device-QA de CloudKit real (que el mirror exporte por
primera vez un corpus born-cloud no está medido en este repo, y lo dice `WelcomeMirrorRelaunchLogic`), el
copy de D6, y el merge del PR.
