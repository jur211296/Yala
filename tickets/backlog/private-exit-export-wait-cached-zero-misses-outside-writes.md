---
id: private-exit-export-wait-cached-zero-misses-outside-writes
status: backlog
priority: low
area: "settings, modo-nube"
created: 2026-09-26
updated: 2026-10-08
source: "review adversarial de `private-exit-loses-unmaterialized-inbound-captures` (lentes de pérdida de datos y de efectos colaterales)"
---

# La espera del cierre privado cachea un cero sin ancla que una escritura ajena deja viejo

## Qué pasa, en lenguaje de usuario

Cierro sesión en mi sesión privada en un teléfono que nunca vio terminar un export a iCloud (recién restaurado).
Mientras espera, salgo y vuelvo a Yala y la app crea algo por su cuenta (p. ej. el borrador de un pago
programado). La espera da el cierre por bueno, suelta la sesión y, justo antes de borrar, se para con el aviso de
«no pudimos confirmar». No se pierde nada, pero el aviso sale con la sesión ya soltada en vez de antes.

## Lo medido (2026-09-26)

- `CloudSessionSignOut.confirmExportOrBlock` cachea el recuento SIN ancla (`withoutAnchor`) porque recorrer el
  historial entero cada segundo es caro. Lo invalida un ancla nueva, un borrador que crea la propia vuelta y, desde
  `private-exit-loses-unmaterialized-inbound-captures`, una cola del App Group que encoge (drenado de primer plano o
  de remote-change).
- Cualquier otra escritura durante la espera (`handleBecameActive` → `processDueScheduledPayments`, reconciliadores)
  no la tira. Con el cero cacheado, la espera confirma.
- No hay pérdida: `armAfterCredentials(.confirm)` vuelve a esperar con caché nueva y el recuento pegado al arm no usa
  caché, así que bloquea con `credentialsReleased: true`.

## Lo que se espera

Invalidar la caché por un testigo barato de «el historial cambió» (el token o el timestamp de la última
transacción), no por una lista de escritores.

## Medido en 2.1 (triage 2026-10-08)

- `CloudSessionSignOut.confirmExportOrBlock`: `withoutAnchor` se reinicia solo con `storeChanged`, con la cola del App Group que encoge o con un ancla nueva; el docblock dice «Otras escrituras ajenas no la tiran» y cita este ticket.
- Sin pérdida: el recuento pegado al arm sigue sin caché.

Triage 2026-10-08: abierto · low → low · sigue igual, sin pérdida de datos: solo cambia el momento del aviso.
