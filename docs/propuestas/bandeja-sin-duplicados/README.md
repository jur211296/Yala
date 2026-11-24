# Bandeja sin duplicados entre fuentes — propuesta

> 2026-11-24 · Frank · leído en `2.3` al día (`origin/2.3` en la fecha). Sesión de propuesta: no cambia la app.
> Versión visual para decidir: el artifact enlazado en el PR. Este fichero es la referencia que queda en el repo.

Pedido de Jürgen (24-nov, 08:10 Lima): con Apple Pay, el correo del banco y el aviso del banco conectados, ¿cómo
evitamos tres pendientes del mismo consumo? ¿Cómo evitamos que la IA, por el conector, apunte encima de lo que ya
está? ¿Cómo hacemos que lo que ya es un pago planificado no suba como pendiente nuevo, y que el planificado de
monto estimado tome el monto real del correo?

## 1 · Cómo entra hoy cada fuente (leído en el código)

| Fuente | Camino | Qué trae | Qué deduplica hoy |
|---|---|---|---|
| **Apple Pay** (atajo de Atajos) | `ApplePayPendingStore` (App Group) → `ApplePayDraftService.processPending` al abrir o volver a la app | importe con símbolo, comercio, tarjeta de Wallet (opcional), **hora exacta** | **Nada**, a propósito: «nunca perder un gasto». Un cierre brusco entre guardar y vaciar la cola deja un borrador doble (residual documentado). |
| **Aviso del banco** (acción de Atajos con el texto de la notificación) | `BankNoticePendingStore` → `BankNoticeDraftService.processPending` | importe, moneda, comercio, últimos 4, **hora exacta** | **Nada**. |
| **Correo del banco** (reenvío) | el gateway lo lee → cola `mail_drafts` → `BankEmailDraftService.syncIfNeeded` al volver a primer plano | importe, moneda, comercio, banco, últimos 4, **solo el día** (la app lo pone a mediodía) | El **mismo correo** dos veces (hash del `Message-ID`, `mail_seen`) y el `ack` perdido (`BankEmailCreatedIDsStore`). Nada contra otras fuentes. |
| **Tu IA** (conector, `apuntar_movimiento`) | MCP → cola común con `source: "ai"` → la misma recogida del correo | importe, tipo, moneda, nota, día, cuenta y subcategoría ya resueltas, qué IA | Solo el **mismo borrador visto en otro aparato** (`AIConnectorDraftLogic.alreadyMaterialized`: instante de llegada + importe + nota). La herramienta se declara «no idempotente». Topes: 50 al día, 100 en cola. |
| **Yala web** | la misma cola, `source: "web"` | lo que eligió la persona | Lo mismo que el correo. |
| **Siri / dictado** | `SiriPendingStore` → `SiriDraftService` | dictado | **Nada**, a propósito (colapsaba dos gastos reales iguales). |
| **Foto y voz en la app** | `DraftDeduplicationService` | varios borradores de una captura | Dentro de la misma captura y contra pendientes: importe ±0,01, mismo día y nota parecida. |
| **Pagos planificados** | `ScheduledPaymentDraftService.processDuePayments` el día que vence | nombre, importe (con `isVariableAmount` = estimado), cuenta, subcategoría | No crea un segundo borrador **suyo** (pendiente, o aprobado ese día) ni si ya hay un movimiento enlazado ±1 día. **No mira ninguna otra fuente**, y `isVariableAmount` no cambia nada al llegar un correo. |

Lo que pasa **al aprobar** (`InboxDuplicateCheck`, desde el 10-nov): un movimiento ya guardado con el **mismo día de
calendario, mismo importe con signo exacto y misma cuenta** es «Posible duplicado». El borrador abierto pregunta
«¿Guardarlo de todas formas?»; «Guardar los N listos» lo deja pendiente y lo cuenta; deslizar pregunta. Solo
borradores personales, y solo contra lo **ya guardado** (incluido lo que el propio lote acaba de guardar).

Lo que ve la IA: `buscar_movimientos` lee **movimientos aprobados** (`tx_items`) y `listar_recurrentes` los
planificados. **No ve la Bandeja.** El rol de lectura que comparte con Yala web ya puede leer las columnas
seguras de `inbox_drafts` en staging (`webapp/supabase/web1_01_bandeja_y_sesiones.sql`), y Yala web ya las lee
(`webapp/src/worker/data.ts`, `bandeja`). Lo que la IA apuntó y el teléfono aún no recogió vive en la cola del
gateway, no en `inbox_drafts`.

Otras dos lógicas de duplicados existen y no tocan la Bandeja: `ImportDuplicateLogic` (importar un extracto) y
`DuplicateDetectionLogic` (activar el puente de Grupos: ±2 días, ±5 %, misma moneda).

## 2 · Qué pasa hoy en cada escenario (medido)

Medido el 2026-11-24 con una prueba temporal que siembra cada escenario y pasa por el código real de cada fuente
(`processPending` de Apple Pay y del aviso, `materialize` del correo y de la IA, `processDuePayments`,
`bulkApproveOutcome` y `InboxDuplicateCheck`), en el simulador, scheme `Yala Dev`. La prueba no se commitea.
Cuenta «BCP Visa» en soles, la única de la persona.

| # | Escenario | Pendientes al llegar | Al guardar |
|---|---|---|---|
| E1 | El mismo café (S/ 42.50) por Apple Pay 13:05, aviso 13:06 y correo, todos con la cuenta resuelta | **3** | «Guardar los listos»: 1 guardado, 2 retenidos como posible duplicado |
| E2 | Apple Pay a las 23:50 del 15 y correo fechado el 16 (S/ 89.90) | **2** | El lote guarda **los 2**: cuenta doble |
| E3 | Apple Pay US$ 11.30 y correo S/ 42.94 (el banco ya convirtió) | **2** | Apple Pay queda **sin cuenta** (no hay cuenta en dólares); nada los relaciona |
| E4 | La IA apunta del correo un café que ya está pendiente por Apple Pay | **2** | Igual que E1 si los dos están listos |
| E5 | La IA lee el mismo correo dos veces (dos llamadas) | **2** | El lote retiene el segundo (mismo día, importe y cuenta) |
| E6 | La IA apunta algo ya guardado a mano | 1 | «Posible duplicado»: sí |
| E7 | Luz del Sur, planificado **estimado** S/ 120, vence hoy; llega el correo S/ 134.80 | **2** (el del planificado a S/ 120 y el del correo) | Nada los relaciona: importes distintos |
| E8 | Dos compras reales iguales por Apple Pay (S/ 12 a las 8:10 y 18:40) | 2 (correcto) | El lote guarda **1** y retiene la segunda compra real |
| E9 | Gasto por Apple Pay y reembolso por correo el mismo día | 2 (correcto) | Los 2 (signo distinto) |
| E10 | Registro a mano y, horas después, el aviso del banco | 1 | «Posible duplicado»: sí |

Lo que no se pudo medir en la prueba y queda inferido del código: el cruce de dos aparatos que recogen la cola a la
vez (residual documentado en `BankEmailDraftService.aiConnectorDrafts`) y el correo reenviado que la IA también lee
por su conector de Gmail (hoy no comparten ninguna llave).

La prueba y su salida, por si hay que repetirla: `~/Claude/entregas/2026-11-24-propuesta-bandeja-sin-duplicados/medicion/`.

## 3 · Tres opciones

### A · Red al aprobar, más ancha
Todo sigue entrando como hoy; se ensancha la comprobación al guardar.
- **Regla**: mismo signo; cuenta igual **o** una de las dos sin cuenta; importe ±0,01 en la misma moneda (o
  convertido ±4 % si difieren); **±1 día** de calendario; compara también contra **otros pendientes**, no solo
  contra lo guardado. El aviso **nombra** el gemelo («Ya guardaste Starbucks, S/ 42.50, hoy 13:05 por Apple Pay»).
- **Bandeja**: sigue mostrando las tres filas; al guardar, la segunda y la tercera piden confirmación.
- **IA**: descripción de `apuntar_movimiento` que pide consultar antes (`buscar_movimientos`) y un campo
  `referencia` opcional (id del correo) que la cola rechaza repetido.
- **Planificados**: no lo resuelve.
- **Costo**: 1 lote pequeño. **Riesgo**: bajo. **Lo que no arregla**: la Bandeja sigue llena de repetidos, y
  el lote se queda con la segunda compra real (E8) igual que hoy.

### B · Un pendiente por consumo (recomendada)
Un **emparejador** común corre al llegar cada borrador, contra los pendientes, los movimientos guardados de los
últimos 3 días y los planificados que vencen cerca.
- **La idea que lo hace seguro**: cada fuente cuenta cada pago **una sola vez**. Apple Pay no manda dos veces el
  mismo pago, ni el aviso, ni el correo (ya filtrado por su id). Por eso **dos borradores de la misma fuente nunca
  se funden**: dos cafés iguales por Apple Pay son dos cafés. El duplicado solo existe **entre** fuentes, y cada
  pendiente absorbe como mucho uno de cada otra fuente (emparejamiento uno a uno).
- **Regla de coincidencia**:

  | Campo | Fuerte (se une solo) | Dudosa (se pregunta) |
  |---|---|---|
  | Tipo | mismo signo; un ingreso nunca se une a un gasto | — |
  | Cuenta | la misma, o una sin cuenta y los últimos 4 casan | una sin cuenta y nada que la contradiga |
  | Importe | misma moneda, ±0,01 | misma moneda ±3 % (propinas, preautorizaciones) u otra moneda convertida ±4 % |
  | Tiempo | ≤ 6 h si las dos traen hora; mismo día o el siguiente si una solo trae día (correo) | hasta 72 h (cargos que se asientan tarde) |
  | Comercio | parecido (tokens normalizados; vacío no resta) | distinto |
  | Fuentes | distintas, cada una libre | — |

- **Qué fuente manda, campo a campo**: importe y moneda **del banco** (correo o aviso: es lo que salió de la
  cuenta; el importe original de Apple Pay queda como evidencia); comercio de **Apple Pay** (viene limpio); hora de
  Apple Pay o del aviso; cuenta de quien traiga tarjeta o últimos 4.
- **Bandeja**: una fila por consumo, con «Apple Pay · Correo BCP · Aviso BCP» debajo y **Separar** en el borrador.
  La dudosa sale agrupada: «¿Es el mismo gasto?» con **Es el mismo** / **Son distintos**. Lo que ya está guardado:
  «Ya registrado el 15 oct · Descartar / Guardar igual».
- **IA**: herramienta de lectura nueva (`ver_bandeja`: pendientes y lo que espera en la cola), `referencia`
  opcional como llave de idempotencia por cuenta, y una comprobación en el gateway al encolar que devuelve
  `posible_duplicado` con lo que encontró (la IA pregunta y reintenta con `forzar`). En la app, lo de la IA pasa por
  el mismo emparejador.
- **Planificados**: lo que casa con un planificado (nombre o comercio aprendido, importe dentro de tolerancia o
  planificado estimado, ±5 días del vencimiento) **no crea pendiente**: completa el borrador del planificado (o lo
  adelanta si aún no venció) y, si era estimado, le pone el **monto real** con «Antes S/ 120 estimado». Monto fijo y
  cargo distinto: pregunta. La primera vez que un comercio casa con un planificado se pregunta y se aprende.
- **Costo**: 5 lotes (abajo). **Riesgo**: medio, acotado por el uno a uno y por «Separar»; toca el modelo
  sincronizado (un campo nuevo para recordar qué se unió), así que lleva revisión de checklist.

### C · Una fuente principal por cuenta
La persona elige, por tarjeta, qué fuente crea pendientes (p. ej. «BCP Visa: el correo»). Las demás solo
confirman o enriquecen; si la principal no llega en N horas, la secundaria crea el pendiente.
- **Regla**: la de B, pero solo entre principal y secundarias.
- **Bandeja**: limpia cuando todo llega; un hueco de N horas cuando la principal falla.
- **Costo**: B + configuración por cuenta + temporizador. **Riesgo**: alto de «no me apareció el gasto»; exige
  que la persona entienda sus fuentes, que es justo lo que Yala quiere ahorrarle.

## 4 · Escenarios con cada opción

Ver la tabla del artifact. Resumen: A resuelve el doble conteo al guardar pero no limpia la Bandeja ni toca los
planificados; B resuelve todos salvo la moneda extranjera (que pregunta) y protege las dos compras reales iguales;
C deja la Bandeja más limpia cuando todo llega y es la peor cuando algo falla.

## 5 · Plan de implementación de B, en lotes

| Lote | Qué | Versión | Depende de |
|---|---|---|---|
| **0 · Red al aprobar ±1 día** (opcional, rápido) | `InboxDuplicateCheck` mira también el día anterior y el siguiente y nombra el gemelo. Cierra E2 ya. | 2.3 si Jürgen lo quiere; si no, entra en el 1 | — |
| **1 · Emparejador** | Lógica pura `InboxMatchLogic` (regla de arriba, uno a uno, fuente que manda) + pruebas con los escenarios de este informe. Sin UI. | 2.4 | — |
| **2 · Unir al llegar** | Cablear el emparejador en Apple Pay, aviso, correo, web e IA (un punto común tras `materialize`); campo sincronizado para recordar lo unido y «Separar». Migración SwiftData + columna en la nube. | 2.4 | 1 |
| **3 · Bandeja** | Fila con las fuentes, «¿Es el mismo gasto?» agrupado, «Ya registrado». Capturas antes/después. | 2.4 | 2 |
| **4 · Planificados** | Casar con planificados, monto real del estimado, alias aprendido. | 2.4 | 2 |
| **5 · Conector de IA** | `ver_bandeja`, `referencia` y comprobación al encolar en el gateway; staging y luego producción. Servidor: no espera a la versión de la app. | servidor, cuando se elija | — |

## 6 · Decisiones para Jürgen

1. ¿Opción B? — **Recomendado: B.**
2. ¿Unir solo en coincidencia fuerte, o preguntar siempre? — **Recomendado: unir solo, con «Separar» a un toque.**
3. Si el importe difiere entre fuentes (moneda extranjera), ¿cuál manda? — **Recomendado: el del banco.**
4. Planificado de monto fijo con cargo distinto: ¿se actualiza solo? — **Recomendado: no, pregunta.**
5. ¿La IA puede leer tus pendientes de la Bandeja? — **Recomendado: sí, las columnas que ya ve Yala web, sin el
   texto original.**
6. ¿Lote 0 en 2.3? — **Recomendado: sí, es pequeño y cierra el cruce de medianoche.**
7. Grupos y cuentas compartidas: ¿fuera de esta tanda? — **Recomendado: sí.** El emparejador ignora los borradores
   de grupo; el puente ya tiene su detección al activarse.
