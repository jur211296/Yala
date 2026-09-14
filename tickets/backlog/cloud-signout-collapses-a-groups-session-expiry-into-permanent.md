---
id: cloud-signout-collapses-a-groups-session-expiry-into-permanent
status: backlog
priority: medium
area: "modo-nube, groups, sesión"
created: 2026-09-14
source: "alcance de `cloud-signout-collapses-every-groups-transient-into-permanent` (PR del 2026-09-14)"
---

# Al cerrar sesión en la nube, una sesión de grupos caducada sigue diciendo «revisa tu conexión»

## El problema, en lenguaje de usuario

Tengo una cuenta en la nube con grupos y cambios de grupos sin subir. Mi sesión con el servidor de grupos
ya caducó. Pulso «Cerrar sesión» y la app me dice **«Hay cambios sin subir a la nube. Revisa tu conexión
e inténtalo de nuevo.»** Mi conexión funciona. Lo que hace falta es volver a entrar con la cuenta, que es
lo único que sube esos cambios — y eso es justo lo que el aviso no dice.

## Lo medido (2026-09-14)

El 2026-09-14 el paso 2 de `performCloudSecureSignOut` dejó de aplanar el motivo con un ternario y pasó a
traducirlo con `CloudSignOutFlowLogic.cloudSignOutGroupsBlockReason`, una función pura y exhaustiva. Ahí
lo pasajero ya viaja con su aviso propio (`.uploadRetryLater`), pero dos motivos se dejaron colapsados **a
propósito y con esta nota**:

```swift
case .permanent, .sessionExpired: return .permanent
```

`.sessionExpired` tiene copy propio desde el paso 9 (`groups.errors.sessionExpired`: «Tu sesión caducó.
Vuelve a iniciar sesión e inténtalo de nuevo.») y las otras tres celdas del cierre ya lo enseñan. Solo la
celda de la nube lo esconde.

**Es alcanzable**: basta con el outbox personal vacío —que es lo normal: `pushAllPendingForSignOut` corta
en `.drained` sin ciclar— y filas vivas en el outbox de grupos cuando el canal responde 401.

## Lo que hay que decidir

Decírselo o no, y es una decisión de producto: el consejo «vuelve a iniciar sesión» se le da a alguien que
acaba de pedir lo contrario. Las opciones:

1. **Propagar `.sessionExpired`** como ya hacen las otras tres celdas. Coherente, y el consejo es cierto:
   sin volver a entrar, esos cambios no suben.
2. **Copy propio para esta celda** que explique la secuencia («vuelve a entrar, deja que suban tus
   cambios y cierra sesión después»).
3. **Dejarlo como está**, documentando que en la nube el aviso es deliberadamente conservador.

## Relación con otros tickets

- `cloud-signout-collapses-every-groups-transient-into-permanent` — el que abrió esta celda y dejó éste.
- `cloud-signout-collapses-the-personal-push-all-reason-into-permanent` — el mismo colapso, un paso antes.
