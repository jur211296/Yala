---
id: inbox-dismiss-x-does-not-delete-the-draft-for-good
status: qa
priority: high
area: "inbox, pagos-programados"
created: 2026-10-08
updated: 2026-10-08
source: "reporte de Jürgen, 2026-10-08 11:52 (Lima); card del tablero tablero-borrar-un-gasto-de-la-bandeja-de-entrada-yneu"
---

# Un gasto que descarto en la Bandeja con la x vuelve a aparecer

## Lo que dijo Jürgen

> «cuando borro un gasto de la bandeja de entrada (la x arriba a la derecha antes de aprobar), no se está borrando
> definitivamente, me vuelve a aparecer»

A las 13:19 (Lima) confirmó que **el gasto que reaparecía era un pago programado personal**.

## Qué pasa, en lenguaje de usuario

Cuando vence un pago programado, como el alquiler o una suscripción, la app deja un borrador en la Bandeja para
que lo apruebes. Si lo descartas (con la x, deslizando, en lote o con la papelera), el borrador desaparece. Pero
la próxima vez que abres la app, o que vuelves a ella, está otra vez ahí, idéntico. La app no recuerda que ese
vencimiento ya lo descartaste.

## Medido (árbol `2ddb5d28e`, 2026-10-08)

- La x de la hoja (`InboxDraftEditSheet`, `xmark.circle`) es **Rechazar**: `DraftService.rejectDraft` pone
  `status = .rejected` y el borrador va a Archivados. El swipe «Rechazar», el lote y la papelera (borrar de verdad)
  pasan por `rejectDraft` / `bulkReject` / `deleteDraft` / `bulkDelete`. Todos los caminos de descarte del Inbox
  pasan por `DraftService` (grep: ningún otro sitio cambia el estado de un borrador, salvo «Saltar» de Planificación).
- **Causa (hipótesis 1, confirmada con un test rojo en 2.1):** los cuatro métodos solo saltaban la ocurrencia con
  `skipGroupScheduledOccurrence`, que era un no-op salvo para `.groupScheduledExpense`. Para `.scheduledPayment` y
  `.subscription` no se saltaba nada ni avanzaba `nextDueDate`. `hasExistingDraft` solo cuenta pendientes y
  aprobados, así que el rechazado no bloqueaba y el borrado ya no existía: `processDuePayments`, que corre en cada
  arranque y en cada vuelta a primer plano, creaba un borrador idéntico. Rojo:
  `InboxDismissScheduledDraftTests.dismissedScheduledDraft_doesNotComeBack` en sus 8 combinaciones (personal y
  suscripción × x/swipe, lote, papelera, borrado en lote). El de grupo ya pasaba.
- **Hipótesis 2 (otro dispositivo / canal de sync): confirmada como causa secundaria, solo con dos dispositivos.**
  Cada teléfono corre `processDuePayments` por su cuenta y crea su propio borrador de la misma ocurrencia, con otro
  `syncID` y otro `createdAt`, así que el ancla de contenido no los empareja. Con el arreglo de la causa 1 solo, el
  borrador del otro teléfono seguía llegando pendiente después de descartar el propio (rojos en
  `otherDevices*` en iCloud y en `InboxDismissScheduledDraftCloudTests` en la nube). La variante «un upsert viejo con
  `pending` pisa el rechazo» se descarta: `status_raw` es su propia unidad de coherencia con su HLC, el pull salta la
  unidad mientras el rechazo esté pendiente en el outbox y el servidor arbitra por campo (`SyncApplyEngine`
  `shouldSkipUnit`, `EntityEmissionMap` `inbox_drafts`). Un borrado sí emite tombstone; un upsert POSTERIOR de otro
  dispositivo sobre esa fila la resucita por la regla de fila del servidor (gana el HLC más alto) — es el contrato
  de LWW, no un bug de este ticket.
- **Hipótesis 3 (fuentes de captura): descartada como causa.** Apple Pay y Siri consumen su cola del App Group al
  guardar: un descartado no vuelve en el pase siguiente (`InboxDismissCapturedDraftTests`). El único camino es un
  kill entre el `save()` y el `remove` (lo documenta `ApplePayDraftService` L160-165): reprocesa la entrada como
  borrador NUEVO, normalmente en el mismo arranque. Se deja así: «nunca perder un gasto capturado» manda.
  Voz, foto/captura y chat no se re-ejecutan sobre el mismo dato (la imagen compartida se borra antes de procesarla;
  el chat no crea `InboxDraft`, guarda una transacción). Correo y automatización no tienen creador (`.emailAlert` y
  `.automation` solo son etiquetas; `DraftService.createDraft(s)` no tiene llamadores). La premisa de UX (la x
  archiva y Jürgen lo veía en Archivados) se descarta: Jürgen confirmó que volvía a la Bandeja.
- **Puente de grupos:** un borrador de liquidación RECHAZADO se respeta (`isReplacedOnReBridge`); uno BORRADO vuelve a
  preguntar al siguiente re-puente, a propósito (lo fija `GroupsBridgeRestoreConvergenceTests`
  `settlementDraft_canBeRejectedOrDeleted_andARejectionSticks`). La x rechaza, así que no aplica. No se toca (fuera de
  alcance del encargo).

## Decisión de producto (tomada en autónomo; se discute en el PR)

**D1 · Descartar el borrador de un pago programado = saltar esa ocurrencia**, la misma marca que «Saltar» de
Planificación, en los tres orígenes (pago programado, suscripción y de grupo). La x sigue archivando; no cambia copy
ni UI. Alternativas descartadas: posponer (es el bug), x = borrar de verdad (no arregla la recreación y quita la vuelta
atrás desde Archivados), avanzar la próxima fecha sin marca (no se ve ni se puede deshacer en Planificación).

**Qué ocurrencia se salta:** la que el borrador retiene (`ScheduledDraftOccurrenceLogic.heldOccurrence`): la próxima
fecha del pago, salvo que el borrador sea de una ocurrencia que la próxima fecha ya dejó atrás (devuelto desde
Archivados, o creado por otro teléfono). La fecha del borrador solo cuenta si cae exactamente en el calendario del
pago, porque la persona puede editarla y el adelanto va fechado hoy. No se salta nada si el borrador ya está archivado
(borrarlo desde Archivados no toca otra ocurrencia) ni si es el duplicado de una ocurrencia ya pagada.

**La próxima fecha avanza al descartar**, si la ocurrencia saltada es la próxima y ya venció (lo mismo que haría el
arranque siguiente). Sin eso, «Adelantar» en Planificación en la misma sesión pagaba dos veces la siguiente. Y un
rechazado vuelve a la fecha de su vencimiento: la x guarda antes la fecha editada, y una fecha fuera del calendario
no diría, al devolverlo, qué ocurrencia era.

**Volver a pendientes** quita la marca. Si la app ya pasó de largo esa ocurrencia, aprobarla marca la fecha pagada
sin avanzar la próxima fecha otra vez (sin esto, aprobar tras devolver se comía la ocurrencia siguiente). Sí avanza
si esa ocurrencia ya estaba cubierta (saltada, pagada ese día o con otra transacción enlazada): es un adelanto. La
fecha de pago nunca retrocede.

**Dos dispositivos:** el borrador pendiente de una ocurrencia saltada —el que creó el otro teléfono antes de
enterarse— se archiva (rechazado, recuperable desde Archivados) al descartar y en cada `processDuePayments`.

## Qué cambió

- `ScheduledDraftOccurrenceLogic` (nuevo, lógica pura): ocurrencia retenida, la que se salta al descartar, la que se
  restaura al devolver, si un pendiente es de una ocurrencia descartada y si aprobar avanza la próxima fecha.
- `DraftService`: `rejectDraft`, `bulkReject`, `deleteDraft` y `bulkDelete` saltan la ocurrencia en los tres
  orígenes (sustituye a `skipGroupScheduledOccurrence`) y archivan los pendientes hermanos de esa ocurrencia;
  `returnToPending` y `bulkReturnToPending` deshacen el salto. Re-planean los avisos de pagos al cambiar el salto.
- `ScheduledPaymentDraftService.processDuePayments` archiva antes de crear nada los pendientes de una ocurrencia
  saltada; `handleDraftApproved` y `handleGroupScheduledExpenseApproved` no avanzan dos veces.
- `SiriDraftService.processPending` acepta la cola y la quiescencia inyectadas (como Apple Pay) para fijar su prueba.

## Pruebas

- Rojo en 2.1 y verde con el arreglo: `YalaTests/InboxDismissScheduledDraftTests` (8 combinaciones fuente × gesto,
  grupo, controles y dos dispositivos con iCloud).
- Modo nube con dos dispositivos por el wire real: `YalaTests/CloudSync/InboxDismissScheduledDraftCloudTests`.
- Apple Pay y Siri: `YalaTests/InboxDismissCapturedDraftTests`.
- Lógica pura: `YalaTests/ScheduledDraftOccurrenceLogicTests`.
- Controles: dos pagos idénticos y dos capturas idénticas siguen siendo dos; la ocurrencia siguiente sigue llegando;
  devolver desde Archivados (antes y después de que la app pase de largo) y aprobar no se come la siguiente; borrar un
  archivado no salta otra ocurrencia; el duplicado de una ocurrencia pagada no se barre.

## Review adversarial (dos lentes, 2026-10-08)

Lente de lógica de ocurrencias, arreglados con su test y su mutante:
1. Tras descartar, la próxima fecha no avanzaba hasta el arranque siguiente: «Adelantar» en la misma sesión pagaba la
   siguiente dos veces (y el adelanto pendiente se archivaba solo). → avanza al descartar
   (`dismissingThenPayingTheNextOneEarly_inTheSameSession_paysItOnce`).
2. Un rechazado con la fecha editada, devuelto después de que la app pasara de largo, saltaba otra ocurrencia o
   avanzaba dos veces al aprobar, y la fecha de pago retrocedía. → vuelve a la fecha de su vencimiento y la fecha de
   pago no retrocede (`dismissingAfterEditingTheDate_returnsWithTheOccurrenceDate_andApprovingPaysItOnce`).
3. Un adelanto hecho el día de una ocurrencia cubierta por una transacción asociada de otro día no avanzaba. → cuenta
   como cubierta (`payingEarlyOnTheDayOfAnOccurrenceCoveredByAnotherTransaction_advances`).

Lente de sync: tres casos de dos teléfonos tocando el mismo pago dentro de la ventana de sync, en residuales.

## Residuales (no cubiertos, con su porqué)

- Dos dispositivos, fecha de pago editada (lente de lógica, hallazgo 4): si el otro teléfono aprobó la ocurrencia con
  la fecha cambiada a un día anterior, descartar aquí su duplicado salta una ocurrencia ya pagada y Planificación la
  pinta saltada en vez de pagada. No mueve dinero.

- Apple Pay / Siri: un kill entre el `save()` y el `remove` de su cola reprocesa la entrada como un borrador nuevo.
  Recordarlo exigiría una marca por entrada en el borrador (campo nuevo = schema de CloudKit y columna en el backend).
- Un adelanto («Pagar ahora») descartado ANTES de su vencimiento, que llega y la app pasa de largo, y luego devuelto a
  pendientes y aprobado: avanza otra vez (su fecha es la del día del adelanto, fuera del calendario, y no dice qué
  ocurrencia retenía).
- Saltar hoy en Planificación una ocurrencia y adelantar la siguiente el mismo día: el barrido archiva el adelanto
  (su fecha es la ocurrencia saltada).
- El borrador del otro teléfono de un adelanto (fecha de hoy) no se reconoce como de la ocurrencia descartada.
- Dos teléfonos tocando el MISMO pago dentro de la ventana de sync (review adversarial, lente de sync; sin test):
  (a) aprobar su borrador en uno y descartar el duplicado en el otro, que aún no vio la aprobación: el segundo
  archiva el aprobado como gemelo y su `status_raw` gana por LWW (queda «Rechazado» con su transacción);
  (b) la lista de fechas saltadas (`skipped_dates_raw`) viaja como un texto con UNA versión, así que dos saltos o
  vueltas concurrentes del mismo pago se pisan y uno se pierde (contrato previo; ahora la escriben también el
  descarte y «Volver a pendientes»); (c) si al otro teléfono le llega la vuelta a pendientes antes que el pago sin
  el salto, el barrido la re-archiva (recuperable desde Archivados). Cerrarlos exige unir la lista por fecha en el
  servidor (cambio de esquema).
- «Saltar» de Planificación rechaza los pendientes sin guardar los valores de Archivados: no salen en Archivados
  (preexistente, `ScheduledPaymentsViewModel.rejectPendingDraft`; no se toca aquí).

## Guion de device-QA (para Jürgen)

Lo que el simulador no puede probar: el espejo real de iCloud y la nube entre dos teléfonos.

**Montaje**
1. Instala el build de este cambio (TestFlight o `Yala Dev` desde Xcode) en el iPhone y en un segundo dispositivo
   (iPad u otro iPhone) con el **mismo Apple ID**.
2. En los dos, Ajustes → «Dónde viven tus datos» en **iCloud** para la primera ronda.

**A. Un solo teléfono (lo que reportaste)**
1. Planificación → nuevo pago programado «QA alquiler», mensual, con fecha de **ayer** y una cuenta.
2. Cierra Yala del todo (desliza hacia arriba) y ábrela: «QA alquiler» aparece en la Bandeja.
3. Ábrelo y toca la **x** de arriba a la derecha.
4. Cierra Yala del todo y ábrela. Luego vete a otra app más de un minuto y vuelve.
   **Esperado:** «QA alquiler» no vuelve a la Bandeja. Está en Archivados.
5. Planificación → «QA alquiler»: la fecha de ayer sale **saltada** y la próxima es el mes que viene.
6. Archivados → «QA alquiler» → **Volver a pendientes**: vuelve a la Bandeja y en Planificación la fecha de ayer ya
   no sale saltada. Apruébalo.
   **Esperado:** la próxima fecha sigue siendo el mes que viene, **no** dentro de dos meses.

**B. Dos dispositivos con iCloud**
1. Crea otro pago «QA luz» con fecha de ayer en el iPhone y espera a que aparezca en Planificación del iPad.
2. Abre Yala en los dos: cada uno muestra «QA luz» en su Bandeja.
3. En el iPhone, descártalo con la x.
4. Espera un par de minutos con los dos abiertos; cierra y abre Yala en el iPad.
   **Esperado:** en el iPad «QA luz» pasa a Archivados; en el iPhone no reaparece ninguno de los dos.

**C. Dos dispositivos en la nube**: repite B con los dos en «Nube» (Ajustes → «Dónde viven tus datos»).

Si algo falla, una captura de la Bandeja y de Planificación del pago basta.
