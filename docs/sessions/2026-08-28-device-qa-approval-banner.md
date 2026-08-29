# Device QA 2026-08-28 — la aprobación del admin retira el aviso

- `groups-approval-banner-stays` cerrado con **PASS del owner** (Jurgen, Lima). Dos teléfonos, grupo
  nuevo, **TF 2.1 build 12**. A = owner (cuenta personal), B = cuenta de prueba **ya creada** (no install
  limpia). B se une, ve «1 solicitudes pendientes» y el aviso «Esperando la aprobación del
  administrador»; A aprueba; **B se queda en la hoja de Grupos, sin forzar cierre ni reabrir** y al rato
  el aviso y el mensaje naranja **se van solos**. Grupo normal, 2 miembros activos.
- El punto que lo convierte en prueba: **sin relanzar la app**. El bug original se quitaba de encima
  cerrando y reabriendo, así que un PASS con relanzado no valía.
- **Medido, no supuesto:** el fix `479e8e81` es ancestro de `f4cf3d2b` («Build 12 para TestFlight de
  2.1») ⇒ el binario que probó el owner lleva el código que el ticket valida.
- **Fuera del PASS:** el **rechazo** (paso 6) y la **contra-prueba del tercer miembro** (paso 7) no se
  corrieron hoy — los dos tienen unit, ninguno tiene device. Tampoco la transición «¡Todo listo!» del
  cover abierto. Y no cierra al hermano `groups-join-intent-reconciler`: el reporte dice que A aprobó, no
  por qué superficie supo de la solicitud.
- **Hallazgo nuevo de la misma corrida, ticket aparte:** con B **todavía pendiente**, el grupo «Probando»
  salía en su lista y **al tocarlo pudo entrar y ver el grupo**. Owner: está mal. Va a
  `tickets/backlog/groups-pending-member-can-open-group.md` (high). **No** se dobla dentro del ticket del
  aviso: aquí el defecto es la **puerta**, no la salida de la sala de espera.
- Del hallazgo nuevo, medido en `2.1` @ `2175e53e`: que el pendiente reciba **grupo + roster** es
  intencional en el DDL (`supabase-groups-staging.ddl:125`, `:153` por `is_group_member`; el comentario
  del endurecimiento en `:814` lo dice literalmente) y el **contenido financiero no baja**
  (`is_group_writer` en `:817`, `:819`, `:821`). ⇒ no es fuga; la pregunta es si la app debe abrir la
  puerta. **Decisión de producto pendiente del owner** — choca con `guest-decline-has-no-screen`, que
  trata el mismo hecho como problema de copy y ya invirtió en explicarlo (`0342564c`).
- Observado y **no** promovido a defecto: la app no llevó a B al tab de Grupos; fue a mano.
- Sin subida a TestFlight hoy. HOLD sigue: A7/M5, App Store, tag. Cero Swift en el PR de esta sesión.
