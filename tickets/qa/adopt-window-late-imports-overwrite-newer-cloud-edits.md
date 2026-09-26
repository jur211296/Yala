---
id: adopt-window-late-imports-overwrite-newer-cloud-edits
status: qa
priority: medium
area: "modo-nube, migración"
created: 2026-09-25
updated: 2026-09-26
source: "review adversarial (lente de tests) de `adopt-on-an-empty-store-uploads-what-the-mirror-imports-before-the-relaunch`, 2026-09-25"
---

# Lo que el espejo importa tarde tras un adopt sube con un reloj nuevo y puede pisar ediciones más nuevas de la nube

## El problema, en lenguaje de usuario

Mi primer iPhone pasó mis finanzas a la nube hace una semana y desde entonces he corregido algunos movimientos. Activo la
nube en el segundo iPhone del mismo Apple ID. Su iCloud todavía no ha terminado de bajar la copia vieja. Si el adopt termina
antes de que llegue todo, lo que llega después sube con la versión vieja y puede deshacer mis correcciones.

## Lo medido (2026-09-25, en el código) e inferido

- Medido: tras el adopt, el paso 3 (`fastForwardHistoryBaseline`) ancla la línea base; lo que el espejo importe DESPUÉS lo
  traduce el primer drain tras relanzar, porque el drain no filtra por el autor del espejo.
- Medido en la documentación del propio motor (`HistoryTokenFallbackLogic`): re-emitir filas con un HLC fresco pisa por LWW
  escrituras ajenas más nuevas.
- Medido: el drain corre, y el push sube, ANTES del primer pull del runtime (`CloudSyncRuntime.start` → `performCycle`).
- Inferido, sin reproducir: que en la práctica lleguen filas conocidas por el backend después del reconcile. La quiescencia
  del import lo acota; el ticket padre lo acota más en el caso del store vacío (espera al primer import entero tras un
  `found`); queda el adopt que arranca con filas locales y un import a medias (el «import-lag» de siempre).

## Opciones (decidida la primera, 2026-09-25)

- En el primer drain tras un adopt, no traducir los inserts del espejo de filas cuya identidad conoce el backend (el pull
  las traerá con su versión). **← elegida.**
- O acuñar para esas filas el HLC que tenían y no uno fresco. Descartada: ese HLC no viaja por CloudKit (el espejo exporta
  las columnas, no el reloj del backend), así que no hay de dónde leerlo; y aunque lo hubiera, una fila del backend editada
  después seguiría ganando solo si su HLC es mayor, que es justo lo que el pull ya garantiza sin acuñar nada.

## Relación

- Surge de `adopt-on-an-empty-store-uploads-what-the-mirror-imports-before-the-relaunch`.
- Hermano: `adopt-window-uploads-what-reaches-the-mirror-after-the-icloud-check`.
- Familia: `adopt-orphan-with-a-fresh-hlc-beats-the-absent-leaders-edit`.

## Resolución (2026-09-25, sesión nocturna en MODO AUTÓNOMO)

**Qué cambia para el usuario.** Tras activar la nube en un segundo iPhone, lo que su iCloud todavía estaba bajando de
movimientos que la nube ya tiene no vuelve a subir: sus correcciones hechas en la nube se quedan.

**Paso 0 · decisiones (auto-contestadas de noche).**
- D1 · qué hacer con esas filas: no traducirlas; el pull trae la versión del backend (la opción que el encargo prefería).
- D2 · alcance: altas, cambios **y borrados** que el espejo trae de filas que el backend conoce. Un cambio o un borrado con
  HLC fresco pisa igual que un alta; dejarlos fuera era dejar el ticket a medias.
- D3 · cómo sabe el drain qué conoce el backend: la enumeración que el reconcile del adopt ya hace (vivas y borradas), guardada
  junto al registro del adopt, que ya sobrevive al relanzamiento y ya se retira tras el primer drain completo.
- D4 · autor: las altas se filtran sin mirar la firma del espejo (ningún camino local crea una fila con una identidad del
  backend), los cambios y borrados solo con ella (los del usuario tienen que salir).
- D5 · lista ilegible: todo como antes, con rastro (la regla del registro).

**Qué se tocó.**
- `RelayIdentityLedger`: fichero `….backend-known` al lado del registro; lo quitan la siembra y la vuelta atrás.
- `MigrationWorkExecutor.pinAdoptedIdentities(backendKnown:)`: lo escribe detrás de la marca del adopt.
- `CloudSyncEngine`: `skipsAdoptBackendKnownRow` en las tres ramas de `translateChange`; la retirada del registro decide por
  la marca y no por el fichero (un adopt sin filas acuñadas con testigo no escribe registro y la lista se quedaba).
- Canario `cloudAdoptLateImportSkipped` y rastro `adoptLateImportSkipped`.
- Regla nueva en `.claude/rules/swiftdata-cloudkit.md` («Y lo que el espejo importa TARDE…»).

**Contrato que cambió.** Dos tests de `adopt-window-late-leader-identity-export-can-duplicate-after-the-remount` afirmaban
que la edición vieja que el espejo trae con la re-identificación sube tras restaurar la identidad. Era este bug escrito como
contrato: ahora no sube, manda el backend y sigue sin duplicarse.

**Review adversarial (tres lentes: filtro, tests, consumidores + regla).** Cazó un defecto real en MI arreglo, con dos
lentes por separado: el borrado que el espejo importa de una fila que antes re-identificó salía igual, porque el filtro
miraba solo la identidad preservada (la del líder) y `relayTombstoneIdentity` la traducía a la del backend. Arreglado: el
borrado se mira con sus dos identidades. También: la salida por backend vacío dejaba la lista de una pasada anterior
(ahora la quita), cinco huecos de test (borrado del propio usuario, otro autor, un tombstone en la enumeración, un test del
runtime que no probaba que el drain corrió, un control que quitaba más que la lista) y tres frases inexactas de la regla.

**Verificado.** Tests `adoptLateImport_*` en `MigrationWorkExecutorTests`: el caso del ticket con control que quita SOLO
la lista, el borrado re-identificado del espejo con su control, el pull que trae la versión de la nube sin duplicar, el
canario, el ciclo de vida, la salida por backend vacío y la lista ilegible; y el del runtime reajustado. 395 tests en las 9
suites del motor y del adopt. Mutantes: 11/11 muertos en la primera tanda y una segunda para el código de la review (ver
el PR).

**Residuales.** Lo que el backend NO conoce sigue subiendo (`adopt-window-uploads-what-reaches-the-mirror-after-the-icloud-check`);
lo que el backend aprendió después de la enumeración, también. Una edición de este teléfono en la ventana sobre una fila
que el espejo pisa después sube con el valor del espejo (ticket nuevo
`adopt-window-user-edit-uploads-the-value-the-mirror-wrote-over-it`, low). Y por decisión: una edición genuinamente más
nueva de otro teléfono del mismo Apple ID que sigue en iCloud, si llega en la ventana, ya no sube (manda el backend). Que el espejo firme sus cambios con el prefijo sigue sin
medir en device (si no los firma, los cambios y borrados salen como antes; las altas no dependen de eso).

## Device-QA (dos iPhone reales: CloudKit no existe en el simulador)

El caso depende de una carrera (que el import de iCloud llegue DESPUÉS del paso 3 del adopt), así que puede no reproducirse
a la primera. El canario dice si se reprodujo.

**Montaje.**
1. iPhone A y B con el mismo Apple ID, el build nuevo en los dos, los dos en iCloud y con los mismos datos.
2. Pon B en modo avión.
3. En A: crea «Prueba tarde» por 5,00 y cambia el importe de un movimiento que ya existía («Café») a 4,00. Espera un par de
   minutos con A abierto para que suba a iCloud.
4. En A: Ajustes → «Dónde viven tus datos» → «Migrar a la nube», hasta que diga que la nube está activa.
5. En A, ya en la nube: cambia «Café» a 9,00 y «Prueba tarde» a 8,00.

**Caso · el del ticket.**
1. En B: quita el modo avión y, en cuanto tenga red, Ajustes → «Dónde viven tus datos» → «Activar la nube en este
   dispositivo». No esperes a que bajen los cambios de iCloud.
2. Cuando pida cerrar y volver a abrir, hazlo.
3. Esperado, en B y en A (tira hacia abajo en Movimientos): «Café» 9,00 y «Prueba tarde» 8,00. Antes del arreglo, la nube
   podía volver a 4,00 y 5,00.

**Qué mirar en Analytics Engine.** Canario `cloudAdoptLateImportSkipped`: `TransactionItem` con un valor distinto de cero
dice que el import llegó tarde y el arreglo actuó. En cero, el import terminó antes del adopt y el caso no se reprodujo:
repítelo con más datos en el paso 3.
