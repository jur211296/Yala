---
id: adopt-window-uploads-what-reaches-the-mirror-after-the-icloud-check
status: qa
priority: medium
area: "modo-nube, migración"
created: 2026-09-25
updated: 2026-10-05
qa-status: needs-testing
source: "residual y review adversarial (lente de bypass) de `adopt-on-an-empty-store-uploads-what-the-mirror-imports-before-the-relaunch`, 2026-09-25"
---

# Lo que llega al espejo después de que el adopt le preguntó a iCloud sube a la cuenta sin prueba de linaje

## El problema, en lenguaje de usuario

Activo la nube en este iPhone con una cuenta que ya existe. Mi iCloud no tiene finanzas de Yala (o no tengo iCloud), así que
entra sin pedir nada. Antes de cerrar y volver a abrir la app pasa una de dos cosas:

1. Mi iPad —mismo Apple ID, todavía en iCloud— apunta un gasto.
2. Inicio sesión en iCloud en este iPhone, con mi Apple ID o con otro que ya tenía años de finanzas en Yala.

El iPhone recibe eso por iCloud y, al reabrir, lo sube a la cuenta en la nube.

## Lo medido (2026-09-25, en el código)

- El ticket padre hace que el adopt con el espejo adjunto y sin nada local que pida linaje le pregunte a CloudKit. Si ese
  iCloud tiene filas, espera a que el primer import termine y decide la guarda de linaje; con `none` o `noAccount`, entra.
- Entre esa respuesta y el relanzamiento el espejo sigue adjunto (la tarjeta de Almacenamiento no fuerza nada, y puede
  durar días) y el drain traduce todo lo que no escribió el motor, imports incluidos (`CloudSyncEngine.swift`, filtro por
  autor del drain). Lo que el espejo baje en la ventana sube en el primer drain, sin prueba de linaje.
- `noAccount` sale del `CKError.notAuthenticated` de ese instante. Con `.localNoMirror` el espejo está adjunto aunque no haya
  cuenta (`attachesCloudKitMirror`), y nada re-pregunta si la cuenta aparece después.
- Inferido, sin medir: que `NSPersistentCloudKitContainer` empiece a importar en el mismo proceso cuando aparece la cuenta.
- No se puede contar en la flota: el canario `cloudAdoptICloudCorpusChecked` cuenta respuestas, no lo que llega después.

## Por qué medium

El caso 1 es poco probable y el dato es del mismo dueño del Apple ID. El caso 2 puede traer el corpus entero de otro Apple
ID, y la ventana dura lo que la persona tarde en reabrir.

## Opciones, sin decidir

- Tras relanzar, antes del primer drain (`CloudSyncRuntime.start`, donde ya corre `restoreAdoptedRelayIdentitiesIfPinned`),
  mirar en el historial los inserts del espejo posteriores al adopt en las tablas que piden linaje. Primero como canario; si
  pasa, decidir qué se hace con ellos. **Es decisión de producto**: la nube ya está armada, el espejo ya no está, y no hay
  salida del adopt con `.cloud` persistido.
- Volver a preguntar a CloudKit justo antes de armar la nube acorta la ventana, pero no la cierra.
- Tratar `noAccount` como «esperar» solo cuando el mount adjunta el espejo deja esperando para siempre al teléfono sin iCloud.

## Relación

- Padre: `adopt-on-an-empty-store-uploads-what-the-mirror-imports-before-the-relaunch`.
- Hermano: `adopt-window-late-imports-overwrite-newer-cloud-edits` (la misma ventana, con filas que el backend sí conoce).

## Canario (2026-10-05, sesión nocturna en MODO AUTÓNOMO)

Decisión de Jürgen del 2026-10-04 (opción A): **primero un canario; la política, después**. Este cambio NO cambia lo que
sube: mide.

**Qué cambia para el usuario.** Nada visible. A partir de este build, cuando alguien active la nube en un teléfono con una
cuenta que ya existe y su iCloud le traiga algo después de la comprobación, la telemetría dice cuántas altas subieron sin
prueba de linaje y por qué camino entró ese teléfono.

**Qué mide.** En el primer drain tras el remonte (el que cierra la ventana del adopt), las altas que SUBEN:
- en tablas que piden linaje (todas menos los tipos de cambio);
- con una identidad que el backend no conocía en el adopt (las que conocía ya no suben desde #250);
- posteriores al ancla del paso 3 (un re-anclaje del token relee un margen anterior y eso no cuenta).

**Cómo leerlo.** Canario `cloudAdoptLateImportUnproven`, `detail = <autor>|<camino>|<clase>`, `value` = cuántas altas.

| Pieza | Valores | Qué dice |
|---|---|---|
| autor | `mirror` · `local` | `mirror` = bajó de iCloud (firma del espejo). `local` = creado en este teléfono en la ventana, o derivado en el arranque (borradores de pagos programados). Si el espejo no firmara sus imports, lo importado caería aquí: por eso hay dos series |
| camino | `none` · `noAccount` · `found` · `lineageRows` · `noMirror` · `unknown` | cómo entró el adopt. **`none` y `noAccount` son la población del ticket**: iCloud dijo que no había nada que probar. `found`/`lineageRows` ya pasaron una prueba de linaje (caso 1, mismo dueño). `unknown` = build anterior o fichero que no se escribió |
| clase | `TransactionItem` · `other` | movimientos, o el resto (categorías, cuentas, presupuestos…). El tipo exacto está en el rastro del dispositivo |

Lectura para decidir la política:
- `mirror|none|*` o `mirror|noAccount|*` con valores **pequeños** (1–3) → caso 1 (el iPad del mismo dueño apunta algo).
- Con valores **grandes** (decenas o cientos de `TransactionItem`) → caso 2: un corpus entero de iCloud subió a la cuenta.
- Todo en cero durante semanas con adopts reales (`cloudAdoptICloudCorpusChecked` en `none`/`noAccount` distinto de cero)
  → la ventana no trae nada en la práctica.

Consulta en Analytics Engine (token de solo lectura en `~/Secrets/yala-cloudflare/analytics-read.token`, cuenta de
`admin@yala-app.pe`; el valor del canario vive en `double1`):

```sql
SELECT blob3 AS detail, count(DISTINCT blob5) AS telefonos,
       sum(_sample_interval * double1) AS altas
FROM yala_metrics
WHERE blob1 = 'canary' AND blob2 = 'cloudAdoptLateImportUnproven'
  AND timestamp > NOW() - INTERVAL '30' DAY
GROUP BY detail ORDER BY altas DESC
```

Y el denominador, cuántos adopts preguntaron a iCloud y qué les contestó: la misma consulta con
`blob2 = 'cloudAdoptICloudCorpusChecked'` y `sum(_sample_interval)`.

**Qué se tocó.**
- `RelayIdentityLedger`: `AdoptRoute` y el fichero `….adopt-route`, con el ciclo de vida de `….backend-known`.
- `MigrationWorkExecutor`: el paso 0-bis apunta su camino (`adoptEntryRoute`) y `pinAdoptedIdentities` lo guarda.
- `CloudSyncEngine`: `countAdoptUnprovenInsert` en la rama de altas del drain, su ventana, su suelo y la agrupación
  `adoptUnprovenCanaryDetails`; rastro `CloudSyncMigration adoptLateImportUnproven` (con el tipo).
- `MetricsService`: canario `cloudAdoptLateImportUnproven`.
- Regla nueva en `.claude/rules/swiftdata-cloudkit.md` («Y lo que el espejo trae tras el chequeo y el backend NO conoce…»).

**Review adversarial (tres lentes: exactitud, no-regresión, privacidad y tests).** Sin regresiones en lo que sube ni en el
ciclo de vida del registro, y sin PII. Cazó y se arregló: un re-anclaje del token contaba como «sin linaje» las huérfanas
que el adopt ya había subido (suelo por el ancla); el detalle por tipo podía echar del spool de métricas canarios ajenos
(agrupado); conteos solo de 1 que dejaban vivas tres mutaciones del valor; controles positivos y `defer`.
**Una premisa mía era falsa**: escribí que el re-drain tras un kill deduplica las filas; un mutante vivo lo puso en duda y
una sonda lo midió: no deduplica (el HLC cambia), así que se cuenta la fila añadida.

**Verificado.** 239 tests de `MigrationWorkExecutorTests` en verde. Mutantes: tanda 1, 10/11 muertos (el vivo era la
premisa falsa de arriba); tanda 2 sobre el código de la review, ver el PR.

**Residuales con ticket**: `adopt-empty-backend-exit-leaves-the-window-unmeasured` (la salida por backend vacío arma la
nube sin ventana) y `adopt-imports-between-the-reconcile-and-the-baseline-are-never-drained`. **Sin ticket, documentados**
en la regla: la serie `local` incluye altas derivadas del arranque, y una retirada que no puede borrar deja la ventana
abierta (cada drain seguiría contando altas `local`, con rastro `retire`).

**Lo que sigue abierto aquí**: la política. Cuando haya números, decidir qué hacer con esas altas (no subir, pedir prueba,
avisar). Este ticket vuelve a `backlog` con esa pregunta tras el device-QA.

## Device-QA (un iPhone real de pruebas: CloudKit no existe en el simulador)

Mide dos cosas que nadie ha medido: si el espejo empieza a importar en el mismo proceso cuando aparece la cuenta de iCloud
(caso 2 del ticket), y si firma esos imports. **Esto sube datos de un iCloud a una cuenta en la nube: usa una cuenta de
nube de PRUEBAS y un iPhone de pruebas, nunca tus datos reales.**

**Montaje.**
1. Un iPhone de pruebas con el build nuevo (TestFlight), **sin sesión de iCloud** (Ajustes → tu nombre → Cerrar sesión).
2. Una cuenta de nube de Yala de pruebas que ya exista (creada antes desde otro dispositivo o desde este mismo, y vacía
   o casi).
3. Un Apple ID de pruebas que tenga finanzas de Yala en iCloud (por ejemplo, el de otro dispositivo de pruebas en modo
   iCloud con 10–20 movimientos).

**Caso · el del ticket.**
1. En el iPhone sin iCloud, abre Yala → Ajustes → «Dónde viven tus datos» → «Activar la nube en este dispositivo» e
   inicia sesión con la cuenta de pruebas. Espera a que pida cerrar y volver a abrir. **No la cierres todavía.**
2. Sal de Yala (sin cerrarla del todo) e inicia sesión en iCloud con el Apple ID del punto 3 del montaje. Espera 2–3
   minutos.
3. Ahora sí: cierra Yala del todo (desliza hacia arriba en el selector de apps) y vuelve a abrirla. Espera un minuto con
   la app abierta y con red.
4. Mira la consulta de arriba (puede tardar unos minutos en llegar):
   - `mirror|noAccount|TransactionItem` con un valor parecido a los movimientos de ese iCloud → el caso 2 existe y el
     espejo firma. Es el dato que pide la política.
   - Lo mismo pero en `local|noAccount|…` → el caso existe y el espejo NO firma sus imports: avísame, cambia cómo se lee.
   - Nada, y `cloudAdoptICloudCorpusChecked` con `noAccount` sí llegó → el espejo no importó en ese proceso: el caso 2 es
     más estrecho de lo que el ticket temía.
5. Limpieza: borra la cuenta de nube de pruebas (Ajustes → «Tu cuenta de Yala» → «Eliminar mi cuenta») y cierra sesión
   de iCloud en ese iPhone.
