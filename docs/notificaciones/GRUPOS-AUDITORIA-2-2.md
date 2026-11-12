# Notificaciones de Grupos — auditoría 2.2

Card `sztn`, 2026-10-30. Qué avisos de Grupos existen, quién los dispara, cuándo, a quién y qué dicen. Medido en el
código del árbol del PR, no en documentación anterior.

## Cómo llega un aviso de grupo

Hay **dos capas**, y casi todos los fallos de la card venían de mezclarlas:

1. **El push del servidor.** Lo manda el Worker (Cloudflare) a APNs. Es una alerta que **pinta el sistema** aunque la
   app esté cerrada, y lleva además `content-available` para despertar a la app. No hay triggers ni Edge Functions de
   Supabase que avisen: los dos emisores viven en el Worker (`gateway/src/groups/routes.ts` y `gateway/src/groups/rpc.ts`).
   Los destinatarios salen de tres RPC de Supabase (`get_group_push_tokens`, `get_group_admin_push_tokens`,
   `get_group_member_push_tokens`), que solo puede ejecutar el rol de máquina `yala_push`. CloudKit ya no interviene:
   el transporte CloudKit de Grupos se borró en la Fase 3.
2. **El aviso local de la app.** Si iOS despierta a la app, ésta baja los cambios y compone su propio aviso
   (`GroupNotificationService`), con «te toca X», que el servidor no conoce. Cuando lo manda, **retira** el push del
   servidor del mismo grupo llegado en los últimos 120 s (`GroupServerNoticeReplacementLogic`). Cuando decide no avisar,
   el push del servidor se queda.

## Tabla

| Evento | Disparador | Cuándo | Quién lo recibe (servidor) | Texto del servidor (desde este PR) | Aviso local de la app |
|---|---|---|---|---|---|
| Gasto nuevo | `POST /groups/push` → `fanOutGroupPush` | tras aplicar el delta | miembros activos del grupo con token, **ninguno del autor** (sus otros dispositivos: solo un push silencioso para sincronizar, sin banner) | «🧾 María P. agregó 'Foppy Pet Store' · S/ 40.60», título = grupo | solo a quien tiene parte y no es el autor ni el pagador: «… — te toca X» |
| Gasto editado (también solo su reparto) | igual | igual | igual | «✏️ María P. editó 'Foppy Pet Store' · S/ 40.60». Un alta cuyas cuotas caen en la subida siguiente (lotes de 50 filas) no repite «editó» | igual que el nuevo |
| Gasto borrado | igual | igual | igual | «🗑️ María P. borró un gasto» (sin concepto: el teléfono ya no tiene la fila al subir el borrado) | ninguno |
| Saldo inicial nuevo / editado | igual | igual | igual | «📒 María P. registró / cambió un saldo inicial · S/ 40.00» | ninguno (se excluye a propósito) |
| Pago registrado / editado | igual | igual | igual | «💸 María P. registró un pago: Ana → Jürgen · S/ 20.00» | solo al receptor, si no lo registró él: «💸 ¡Ana te pagó S/ 20!» |
| Pago borrado | igual | igual | igual | «🗑️ María P. borró un pago» | ninguno |
| Ajustes del grupo (nombre, icono, moneda…) | igual | igual | igual | «⚙️ María P. cambió los ajustes del grupo» | ninguno |
| Varias cosas en una subida | igual | igual | igual | «📋 María P. hizo 3 cambios» | «📋 3 novedades para revisar» |
| Marcar saldado / cuota pagada (solo eso) | igual | igual | **nadie** (desde este PR) | — | ninguno |
| Alguien pide entrar | RPC `join_group` → `notifyMembershipChange` | solo si quedó pendiente y cambió algo (`changed`) | admins activos del grupo, menos quien pide | «👋 Alguien quiere unirse a uno de tus grupos» | admins: «👋 X quiere unirse a «grupo»» |
| Te aprueban, rechazan o expulsan | RPC `approve_member` / `remove_member` | tras el RPC | la persona afectada | «Hay una novedad sobre tu membresía» (neutro a propósito: una negativa no se lee en la pantalla bloqueada) | al aprobado: «Ya estás en «grupo»» |
| Alguien se une (aprobado) | pull del resto | al bajar la fila | — (sin push propio) | — | «X se unió al grupo» |
| Salir del grupo, cambiar de rol, renombrarse, invitar, revocar enlace, transferir propiedad | RPC | — | **nadie**, por decisión previa (se ve en el siguiente pull) | — | — |

## Lo que cambió con este PR

- **Quien hace la acción ya no recibe su aviso en ningún dispositivo suyo.** Antes, con la cabecera del dispositivo
  emisor, el servidor excluía solo ese teléfono: el iPad o el segundo iPhone del autor recibían la alerta, y el saldo
  inicial la dejaba a la vista porque la app no tiene aviso propio para él. Ahora el teléfono emisor no recibe nada
  —tampoco si su token sigue registrado a nombre de otra cuenta— y los otros dispositivos del autor reciben solo el eco
  silencioso (`content-available`, sin alerta), para seguir bajando el cambio al momento como antes.
- **Cada tipo tiene su texto.** El teléfono que sube adjunta en claro lo que ya conoce (`notice` en el body:
  quién, grupo, concepto, importe formateado, saldo inicial, quién paga a quién). El Worker lo combina con lo que sabe del
  delta aplicado y lo manda con `loc-key` + `loc-args`, que iOS traduce en el idioma del iPhone de cada destinatario.
  Nada se guarda: el cifrado at-rest no cambia.
- «Novedades en tus grupos» queda solo para un teléfono que recibe de **varios grupos** en la misma tanda, o para una
  subida de una versión anterior de la app (sin `notice`).

## Lo que queda fuera, a sabiendas

- **Filtro por participación en el servidor.** Un miembro que no está en un gasto recibe igual el aviso del servidor,
  como antes; el servidor no sabe qué cuotas tiene cada uno sin descifrar. La app solo lo sustituye cuando le toca algo.
- **Idioma.** iOS resuelve el texto del servidor con el idioma del **sistema**, no con el que se elige dentro de Yala.
- **Importe en el formato del autor.** Lo formatea el teléfono que sube (símbolo o código de moneda, decimales).
- **Borrados sin concepto.** Para incluirlo habría que guardar el concepto al borrar.
- **Borrados y ajustes no los retira el aviso local.** El aviso rico de la app no cuenta borrados ni ajustes del grupo,
  así que esos avisos del servidor se quedan aunque llegue después un aviso rico de otro cambio del mismo grupo.
- **El aviso local en otro dispositivo del autor.** Quién creó o editó un gasto (`lastEditedByMemberID`) no viaja por el
  canal: en el iPad del autor, la app atribuye el cambio al pagador. Si el autor apuntó un gasto que pagó otro y en el que
  él tiene parte, su iPad puede enseñar «🧾 Ana agregó …». Arreglarlo pide una columna nueva en el canal de Grupos.
- **Subida de versión del canal.** Cuando un teléfono re-sube filas por un cambio de versión del manifest
  (`applyCapabilityUpgradeIfPending`), los demás pueden recibir «X hizo N cambios» por filas que nadie tocó. Pasa una vez
  por versión; antes salía el genérico.
- **Partir un reparto entre dos subidas.** Si las cuotas borradas y las nuevas de una edición caen en lotes distintos,
  ese cambio no avisa.
