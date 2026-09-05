---
id: groups-pending-member-can-open-group
status: backlog
priority: high
area: groups
created: 2026-08-28
updated: 2026-08-28
---

# Un miembro pendiente de aprobación puede entrar al grupo

## El reporte del owner (Jurgen, 2026-08-28, Lima) — hechos suyos, sin añadir

Mismo setup que la corrida del aviso de aprobación de ese día: dos teléfonos, **TestFlight 2.1 build
12**. **A** = owner. **B** = cuenta de prueba **ya creada** (no instalación limpia).

- B se une por el enlace y queda **pendiente de aprobación**.
- El grupo **«Probando» aparece en la lista de Grupos de B** estando pendiente.
- La app **no llevó a B al tab de Grupos**: B se quedó donde estaba y tuvo que ir a Grupos a mano.
  **Observado, y no es el defecto de este ticket** — ver «Lo observado que no se promueve a defecto».
- B ve **«1 solicitudes pendientes»** y el aviso de esperar al admin.
- **Tocar el grupo «Probando» le deja ENTRAR y VER el grupo estando sin aprobar.** Veredicto del owner:
  **esto está mal**.

No hay más hechos de campo. En particular **no consta reportado** qué vio B exactamente dentro del grupo
(¿roster? ¿gastos? ¿saldos? ¿un aviso dentro?), ni si podía tocar algo, ni cuánto rato se quedó dentro.

## El defecto, en una línea

La puerta del grupo no distingue **«pendiente»** de **«activo»**: se abre igual para los dos.

## Esto NO es

| Ticket | De qué va | Por qué no es este |
|---|---|---|
| `tickets/done/groups-approval-banner-stays.md` | el aviso de «esperando aprobación» no se retiraba **después** de que el admin aprobara | Es la **salida** de la sala de espera, y quedó **PASS en device** en la misma corrida (cerrado en el mismo PR que abre este ticket). Aquí el problema es la **puerta**, y ocurre **antes** de aprobar. Meterlo ahí sería declarar que el PASS de hoy tapó algo que no tapó |
| `tickets/qa/groups-join-intent-reconciler.md` | el `SplitMember` del invitado **jamás nacía**, «¡Todo listo!» sin miembro real, y al owner **no** le llegaba la solicitud | Es el defecto **contrario**: allí el alta no se materializaba. Hoy sí se materializó — B vio su solicitud pendiente y **A pudo aprobarla**. Reusar ese ticket enterraría este hallazgo bajo un guion (ventana export-only de CKShare) cuyo transporte ya está muerto |
| `tickets/in-progress/guest-decline-has-no-screen.md` | la sala de espera del invitado: el «no» no tiene pantalla, y mientras espera **ve el grupo y el roster pero ni un gasto** sin que nadie le diga que eso es normal | **El vecino más cercano: leerlo antes de tocar nada.** Documenta el MISMO hecho observable y le pone **otro veredicto** — lo trata como problema de **copy**, no de puerta. Ver «La tensión de producto» |
| `tickets/qa/groups-consent-door-spec.md` | «La puerta de Grupos»: educativo → login → consent antes de usar Grupos, y el consent viajando con la cuenta | Colisión de nombre, no de tema: esa puerta es la de **entrar a la función Grupos**; ésta es la de **entrar a UN grupo concreto estando pendiente**. B ya había pasado la primera |

## Lo medido en este árbol (`2.1` @ `2175e53e`)

Que a B le lleguen el grupo y el roster estando pendiente **está decidido así hoy, y a propósito**. Es lo
único que se midió del mecanismo en este pase, y se midió porque cambia qué clase de arreglo cabe:

- `supabase-groups-staging.ddl:71-75` — `is_group_member` admite `status in ('active','pendingApproval')`.
- `:77-81` — `is_group_writer` admite **solo** `'active'`.
- `:125` (`split_groups_select`) y `:153` (`group_members_select`) van por **`is_group_member`** ⇒ el
  pendiente **recibe el grupo y el roster**.
- `:811-821` — el bloque de endurecimiento que pasó las policies SELECT de
  `split_expenses`/`split_shares`/`split_settlements` a **`is_group_writer`**, con el comentario de `:814`
  diciéndolo con todas las letras: «split_groups y group_members **SE QUEDAN** con is_group_member: la
  sala de espera necesita ver el grupo y el roster». El encabezado del fichero repite el criterio
  (`:46-47`).
- `gateway/src/groups/routes.ts:388` — el pull descubre membresías con
  `status=in.(active,pendingApproval)`.

⇒ **que el grupo salga en la lista de B no es una fuga de datos**, y el **contenido financiero no baja**
(esas tres SELECT exigen `active`). Lo que el owner señala es que, además de aparecer, la app **le abre
la puerta**. Corolario práctico: quien arregle esto **no** puede tratar el DDL como un descuido — está
escrito a propósito y con comentario; cambiarlo es una decisión, no un fix.

Nota de reuso: estas coordenadas son las que ya citaba `guest-decline-has-no-screen` y se **re-midieron
una a una en este árbol** antes de escribirlas aquí. Coinciden.

## Lo que NO se midió en este pase

Nada de esto se supone. **Sin causa evidenciada no hay fix** (regla del repo), y este ticket no la
inventa:

- **Quién gatea —si alguien— la entrada a `GroupDetailView` con un miembro `pendingApproval`**, qué pinta
  esa pantalla, y si el botón de crear gasto está oculto o deshabilitado. El vecino ya dejó **ese mismo
  hueco escrito** en su sección «Huecos»: «Qué pinta exactamente `GroupDetailView` para un
  `pendingApproval`: empty state de la lista de gastos, y si el FAB de crear gasto está oculto o
  deshabilitado». Sigue sin medir, y ahora hay un reporte de device que lo pide.
- Si el aviso de la sala de espera se pinta también **dentro** del grupo, o solo en la lista.
- Qué ve B dentro (ver arriba: el reporte dice «entrar y ver el grupo» y no detalla).
- Si el comportamiento es igual en el grupo recién unido y en uno con historia.

## La tensión de producto — hay que resolverla ANTES de escribir código

Los dos tickets miran el mismo hecho y no quieren lo mismo:

- **`guest-decline-has-no-screen`** lo da por **esperado y mal explicado**: «Mientras espero: veo el grupo
  y veo quién está dentro, pero ni un solo gasto. Nadie me dice que eso es normal — el copy habla de
  *participar*, no de *ver*». Su pieza 2 **ya aterrizó**: `0342564c` («la sala de espera del invitado deja
  de prometer un aviso que no existe»), y está en `2.1` — re-medido, toca **16** `.lproj`, que es la cifra
  que da el vecino. Es decir: el repo ya invirtió en **explicar** la espera.
- **El owner, hoy**, le pone el veredicto opuesto al mismo hecho: **entrar sin estar aprobado está mal**.

Son dos salidas incompatibles, y elegir una decide el trabajo:

1. **Cerrar la puerta** — la tarjeta no navega (o la pantalla no se abre) mientras el status sea
   `pendingApproval`. Deja la sala de espera **sin superficie** donde vivir el copy que la pieza 2 ya
   escribió, y hay que decidir qué se ve en su lugar.
2. **Explicar la sala de espera** — se deja entrar y **dentro** se dice qué falta y por qué no hay gastos.
   Entonces este ticket se cierra como «no es bug» y lo que queda es copy, que es de quien ya lo tiene.

**Aquí no se decide.** Hace falta el owner, y la decisión va escrita antes de tocar una línea — con lo
del DDL en la mano, porque la opción 1 puede querer además que el servidor deje de entregar el grupo, y
eso es cambiar un endurecimiento explícito.

## Lo observado que no se promueve a defecto

**La app no llevó a B al tab de Grupos** tras unirse: se quedó donde estaba y tuvo que ir a mano. Queda
**registrado como observado** y **no** se convierte en el defecto de este ticket: el owner marcó como
«esto está mal» el **poder entrar**, no el no ser llevado.

**Medido**: ningún ticket de `tickets/` reclama hoy esa navegación forzada, así que no hay dónde
anexarlo. Lo más parecido que existe apunta en la dirección contraria: el «banner de continuidad **en el
tab Grupos**» de `groups-join-intent-reconciler` es una superficie pensada para que el invitado
**encuentre** su estado cuando llegue a Grupos por su pie. ⇒ este pase **no abre ticket** por la
navegación. Si algún día se trabaja, necesita el suyo.

## Criterio de hecho (AC)

El AC de conducta **depende de la decisión de arriba** y por eso se deja condicionado en vez de
inventado:

- **Si se cierra la puerta:** con el miembro en `pendingApproval`, tocar la tarjeta del grupo **no** abre
  el detalle; en su lugar el usuario recibe una superficie que le dice en qué estado está y qué puede
  hacer. Y al ser aprobado, la puerta se abre **sin** relanzar la app (eso último ya tiene PASS en
  `groups-approval-banner-stays`, y no debe romperse).
- **Si se explica la espera:** al entrar estando pendiente, la pantalla del grupo dice **dentro** que la
  solicitud está en revisión y que por eso no hay gastos, sin prometer nada que la app no haga.
- En cualquiera de las dos: **nada de contenido financiero** para un pendiente. Hoy el servidor ya lo
  garantiza (`is_group_writer` en las tres SELECT); el cliente no debe pintar un vacío que parezca un
  grupo sin gastos.

## Cómo se verifica

**Device-QA en TestFlight con dos teléfonos, sobre una subida POSTERIOR a este ticket** (el caso exige un
miembro pendiente real contra el canal backend, que no es ejercitable desde un test). Hoy **no hay
subida**: no hay TestFlight, ni store, ni tag, y **A7/M5 sigue en HOLD** ⇒ este ticket **no** pasa a `qa`
y **no hay PASS** que anotar.

## Relacionado

- `tickets/done/groups-approval-banner-stays.md` — el aviso de aprobación; **PASS del owner en la misma
  corrida**, cerrado en el mismo PR que abre este ticket.
- `tickets/in-progress/guest-decline-has-no-screen.md` — la sala de espera: el «no» sin pantalla y el
  copy de la espera. **Lectura obligada antes de diseñar nada aquí.**
- `tickets/qa/groups-join-intent-reconciler.md` — el alta que no nacía. Otro defecto, no este.
- Sesión de la corrida: `docs/sessions/2026-08-28-device-qa-approval-banner.md`.

---

## MEDIDO · 2026-09-04 — qué ve B dentro: el cascarón, no los gastos. NO es fuga de datos

El ticket dejaba explícitamente abierto «no consta reportado qué vio B exactamente dentro del grupo
(¿roster? ¿gastos? ¿saldos?)». Consta ya, medido **contra la base de datos de producción**
(`yala-modo-nube-production`), sin necesidad de repetir el device-QA:

Las políticas de lectura del grupo se parten en dos, y el corte cae justo en el sitio correcto:

| Tabla | Policy | ¿Pasa un `pendingApproval`? |
|---|---|---|
| `split_groups` (nombre, icono, color) | `is_group_member(group_id)` | **Sí** |
| `split_expenses` (los gastos) | `is_group_writer(group_id)` | **No** |
| `split_shares` (los repartos) | `is_group_writer(group_id)` | **No** |
| `split_settlements` (los saldos) | `is_group_writer(group_id)` | **No** |

Porque las dos funciones NO son sinónimas, y es deliberado:

- `is_group_member` → `status in ('active','pendingApproval')`
- `is_group_writer` → `status = 'active'`

Y los cinco RPCs lectores (`groups_pull_rows_*`) son `LANGUAGE sql STABLE` **sin `SECURITY DEFINER`**,
así que corren con los permisos de quien invoca y la RLS de cada tabla sí les aplica. No hay puerta
trasera por ahí.

⇒ **B entra a un grupo VACÍO**: ve el nombre y el icono porque su ficha sí le baja, y ni un solo
gasto. Coincide con lo que ya observaba `guest-decline-has-no-screen` («veo el grupo y veo quién está
dentro, pero ni un solo gasto»).

**Qué cambia esto para el ticket:** el defecto es de EXPERIENCIA, no de seguridad — a nadie se le
enseñan datos que no debería ver. Lo que pasa es que la app deja entrar a una pantalla que no tiene
nada que contar y no explica por qué está vacía. Sigue siendo un «esto está mal» legítimo, pero no
es una urgencia de privacidad y no hace falta tratarlo como tal.

**Lo que sigue sin medirse:** si B podía TOCAR algo dentro (botones de añadir gasto, invitar,
ajustes). La lectura está cerrada; la escritura no se comprobó aquí — `is_group_writer` gobierna
también los `insert`/`update`, así que el servidor la rechazaría, pero si el cliente le pinta los
botones, el fallo que verá es un error crudo, no una puerta cerrada con explicación.
