---
id: account-deletion-cloud-close-has-no-durable-intent
status: backlog
priority: low
area: "cuenta, borrado"
created: 2026-10-31
updated: 2026-10-31
source: "encargo S32 (account-deletion-private-close-has-no-durable-intent), alcance que se dejó fuera"
---

# «Eliminar cuenta» en la nube o en solo grupos tampoco guarda que el servidor ya se borró

Desde el 2026-10-31 la celda D (iCloud privado) deja una marca durable tras el `200` de `POST /account/delete` y el
arranque retoma el cierre local si la app se cerró a medias. La nube (E) y solo grupos sin sesión privada (F) no la
escriben: entre el `200` y `closeLocalAfterAccountDeletionCloud` corren la higiene del faro y las dos revocaciones (SIWA y
Google), que son red. Si la app se cierra ahí, al relanzar la sesión muere en el primer refresh y lo local de la cuenta
borrada se queda en el teléfono.

Se dejó fuera por alcance: el encargo pedía la D, y el cierre de la nube retomado al arrancar (motor de sync, cambio de
almacén en caliente) pide su propia prueba. El molde está hecho: `AccountDeletionService.privateCell` y
`resumePendingPrivateClose` generalizados a «la celda que se decidió con la cuenta viva».
