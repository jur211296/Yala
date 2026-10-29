---
id: account-deletion-private-close-has-no-durable-intent
status: backlog
priority: medium
area: "cuenta, borrado"
created: 2026-10-29
updated: 2026-10-29
source: "review adversarial del encargo 2026-10-29-vaciar-datos-mantiene-cuenta (S27i)"
---

# «Eliminar cuenta» con iCloud privado no guarda que el servidor ya se borró

Desde S27i, «Eliminar cuenta» en la celda D borra la zona de iCloud, luego la cuenta en el servidor y después lo local.
Si el cierre local falla (la quiescencia del import no llega en 60 s), el reintento salta el servidor gracias a un flag
en MEMORIA (`AccountDeletionService.serverSideDeleted`). Si la app se cierra entre el borrado del servidor y el arm, no
queda nada durable: al relanzar, la sesión muere en el primer refresh (el servidor borró `auth.users`), la fila de
«Eliminar mi cuenta» desaparece y el teléfono se queda como una celda C con lo local intacto y la zona de iCloud
posiblemente repoblada por el espejo. Es el mismo hueco que ya tenía el cierre anterior, con una ventana algo mayor.

Arreglo propuesto: una marca durable «cuenta borrada, falta el cierre local» escrita tras el `200` del servidor y
consumida por el arranque (o por la fila), que retome `closeLocalAfterAccountDeletionPrivate` sin sesión.
