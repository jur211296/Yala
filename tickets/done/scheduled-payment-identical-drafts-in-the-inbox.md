---
id: scheduled-payment-identical-drafts-in-the-inbox
status: done
priority: high
area: "planning, inbox, sync"
created: 2026-10-26
updated: 2026-10-29
source: "reporte de Jürgen del 2026-10-26 en producción 2.1 · card tablero-algunos-pagos-planificados-generan-vario-tzpw"
---

# Un pago planificado deja varios borradores idénticos en la Bandeja y al descartar uno se van todos

## Qué pasaba (medido con tests en `2.2`)

1. **Varios borradores**: cada dispositivo materializa el vencimiento con lo que ve (`processDuePayments` →
   `hasExistingDraft` solo mira sus borradores). El del otro iPhone, iPad o Mac llega después por el espejo de iCloud o
   por el pull de la nube, y la Bandeja enseña uno por dispositivo, campo por campo iguales. En un solo dispositivo no
   sale: abrir la app N veces deja uno (`ScheduledIdenticalDraftsTests.oneDevice_relaunching_createsOneDraft`). No es
   regresión de #439/#450 (gastos compartidos y el puente): es otro camino, el de los pagos personales.
2. **Descartar uno se llevaba todos**: `DraftService.dismissScheduledOccurrence` (1dafda29c, 2026-10-08) archivaba a
   propósito todos los pendientes de la misma ocurrencia. Un test lo fijaba como contrato
   (`otherDevicesDraftAlreadyHere_isArchivedTogetherWithMine…`).

## Arreglo

- `ScheduledPaymentDraftService.mergeIdenticalPendingDrafts`, al principio de cada `processDuePayments` (arranque, primer
  plano, vuelta de «Solo grupos»): funde los pendientes IDÉNTICOS de la misma ocurrencia (pago, origen, día, importe,
  nota, cuenta, subcategoría, etiquetas, evidencia, grupo). Se queda el de menor `createdAt`, la misma regla en todos los
  dispositivos; los demás se borran (no van a Archivados). Empate a menos de 1 ms, o uno editado: no se toca. Con la
  Bandeja abierta o cualquier hoja presentada espera a la pasada siguiente. Idempotente: también limpia lo que ya hay en los teléfonos.
- Descartar quita solo ese borrador: si otro pendiente retiene la misma ocurrencia, no se salta ni se toca al otro. La
  ocurrencia se salta al descartar el último. El que llega de otro dispositivo DESPUÉS del salto lo sigue archivando
  `archiveDraftsOfDismissedOccurrences`, como antes.

Tests: `ScheduledIdenticalDraftsTests` y
`InboxDismissScheduledDraftTests.otherDevicesDraftAlreadyHere_staysWhenIDismissMine_andTheLastOneSkips`.

## Residual (de la review adversarial del 2026-10-29)

- Entre que llega la copia del otro dispositivo y la siguiente vuelta a la app, la Bandeja puede enseñar dos. Aprobar uno
  en esa ventana deja el otro pendiente (aprobarlo también apuntaría el pago dos veces, como antes del arreglo): la
  fusión solo junta pendientes entre sí.
- «Uno editado no se toca» vale en el dispositivo donde se editó. Si el iPad edita (o aprueba) la copia que sobra y el
  iPhone la funde antes de recibir la edición, el borrado viaja y la edición se pierde; la transacción de una aprobación
  se queda (la relación es `.nullify`).
- La fusión espera con algo presentado en ESTE dispositivo, no en el otro: el iPad puede tener abierta la copia que el
  iPhone borra. Es la misma clase que cualquier borrado remoto con una hoja abierta.
- El aviso con «Deshacer» es uno para toda la app: un descarte en la Bandeja dentro de esos segundos retira el
  «Deshacer» de un pago o de un registro pendiente (ya pasaba antes).

## Device-QA (iPhone + iPad con el mismo iCloud, build de Yala Dev)

1. En el iPhone, crea un pago planificado mensual con fecha de **mañana**. Espera a verlo en el iPad y cierra Yala en los
   dos.
2. Al día siguiente, pon el iPad en modo avión y abre Yala en el iPhone: sale un borrador de ese pago en la Bandeja.
   Cierra Yala.
3. Abre Yala en el iPad (aún sin red): crea su propio borrador. Quita el modo avión y espera un minuto con Yala abierto.
4. En el iPhone, manda Yala a segundo plano, espera a que llegue el del iPad y vuelve: la Bandeja tiene **un** borrador
   de ese pago, no dos.
5. Si llegaras a ver dos (antes de volver a la app), descarta uno con la x: el otro **se queda**.

Cerrado en el barrido de QA 2026-10-30: criterio estricto (filtro doble); motivo y evidencia en docs/qa/tanda-qa-jurgen-2.2-barrido-2026-10-30.md.
