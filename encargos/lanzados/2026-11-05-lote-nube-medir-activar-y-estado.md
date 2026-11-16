# Lote · Nube: medir activación lenta y «Todo al día» falso
toca: activación de nube / «Dónde viven tus datos» / canarios de sync

Rama base: origin/2.3. Un solo PR contra 2.3, un solo cierre. Máquina: la libre. Puede usar simulador (pipeline serial). Cierre autónomo. Termina con `/cerrar-total`.

## Contexto
Tres cards medium 2.3 relacionadas:
1. «Activar la nube sube 3333 elementos…» (tablero-activar-la-nube-sube-3333-elementos-para-i9wh)
2. «Activar la nube con pocos datos tarda minutos: medir en qué paso» (tablero-activar-la-nube-con-pocos-datos-tarda-mi-vfg1)
3. «Dónde viven tus datos dice Todo al día con sync parada» (tablero-donde-viven-tus-datos-dice-todo-al-dia-c-39ww)

## Qué se pide
1. Medir/reducir la explosión de elementos al activar (no subir miles por 2 registros).
2. Canarios o logs claros de en qué paso se va el tiempo con pocos datos.
3. «Todo al día» solo si la sync realmente está al día.
4. `tablero`: las tres a in qa al cerrar, con guion corto.
5. `preguntar-bot` si una decisión de producto cambia el resultado.

## Qué NO hay que tocar
marketing/, apagar TelemetryDeck, despliegues prod.

## Hecha cuando
Las tres cards cumplen hechaCuando; gate verde; `/cerrar-total`.

## Paso 0 — decisiones

> Resueltas en autónomo (bypass, 22:50 Lima: franja nocturna, sin preguntas al bot). Se discuten en el PR.

Hechos medidos antes de decidir:
- Store del iPhone de pruebas (copiado con `devicectl`): 3234 `ExchangeRate` para 383 días distintos (hasta 9 copias del
  mismo día), 69 subcategorías, 13 categorías, 7 avisos, 3 movimientos, 2 cuentas → ~3328 filas = los «3333».
- Serie de Analytics Engine de esa activación (instalación `b20327d9`, staging): `upload>verify` 459 s de ~505 s;
  `identity>upload` 1 s (la espera al import de iCloud NO es la causa); verificación 33 s.
- Card 39ww («Todo al día» con la sync parada): ya arreglada en 2.3 por el lote N3 (`SyncStatusSectionLogic.stopped`,
  ticket en `tickets/done`). Solo falta su paso por QA.

**D1 · ¿Cómo se reduce la explosión?** → Fundir las tasas duplicadas (mismo día y base) justo antes de enumerar la
primera página de la subida. Por qué: es la causa medida y la fusión no pierde datos (las tasas se juntan).
Alternativa descartada: no subir los tipos de cambio en la activación — es decisión de producto, el Merkle de la
verificación cuenta esa tabla y con la fusión ya bajan de ~3300 a ~480 filas.

**D2 · ¿Dónde se funde?** → En `MigrationSnapshotUploader.uploadPage` con cursor `nil`, ANTES de
`fastForwardHistoryBaseline`. Por qué: el baseline deja los borrados fuera del drain, así que el backend nunca recibe
tombstones de filas que nunca conoció; y con el cursor `nil` aún no subió nada. Alternativa descartada: fusión global en
cada arranque — toca el store de todos los usuarios de iCloud y no es lo que pide el encargo (va a ticket aparte).

**D3 · ¿Qué fila sobrevive?** → El menor `syncID`; tasas fundidas de la más vieja a la más nueva; timestamp el más
reciente. Por qué: dos dispositivos del mismo iCloud eligen la misma (regla «Fundir duplicados…»). Filas sin `syncID`
no entran.

**D4 · ¿Y si la lectura o el guardado fallan?** → `.blocked(.localFailure)`, el mismo desenlace que el resto de fallos
locales de la subida; sin `rollback` (contexto compartido, precedente del backfill). Por qué: un disco que no guarda
tampoco dejaría encolar la página.

**D5 · Medición** → Canario nuevo `cloudSnapshotDuplicateRatesFused` (x = filas borradas) para ver en la flota cuánto
ahorra. Por qué: cumple «canarios claros» de la card vfg1 sin otra activación.

**D6 · Cards** → i9wh y vfg1 a «en QA» con guion corto (activar la nube con el build nuevo y ver la cifra); 39ww a «en
QA» con su guion. Por qué: lo pide el encargo; el device-QA no frena el merge.
