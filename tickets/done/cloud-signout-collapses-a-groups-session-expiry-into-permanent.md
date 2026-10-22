---
id: cloud-signout-collapses-a-groups-session-expiry-into-permanent
status: done
priority: medium
area: "modo-nube, groups, sesión"
created: 2026-09-14
updated: 2026-09-23
source: "alcance de `cloud-signout-collapses-every-groups-transient-into-permanent` (PR del 2026-09-14)"
qa-status: not-replicable
qa-date: 2026-09-23
qa-notes: barrido 2026-09-23 sin device-QA - solo cambia el texto de un aviso y montarlo pide SQL en staging y una hora sin red; CloudSignOutGroupsReasonTests
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

## Cerrado el 2026-09-15 — opción 1

**Decisión de Jürgen (2026-09-14):** propagar la sesión caducada como ya hacían las otras tres celdas del
cierre. Ni copy largo (opción 2) ni dejarlo como estaba (opción 3).

**Qué cambia para quien usa Yala.** Con una cuenta en la nube, cambios de grupos sin subir y la sesión
caducada, «Cerrar sesión» ya no dice «Revisa tu conexión». Dice «No pudimos cerrar tu sesión» y «Tu sesión
caducó. Vuelve a iniciar sesión e inténtalo de nuevo.». El bloqueo es el mismo: nada se sube, nada se borra y la
sesión no se cierra.

**Qué se hizo.**

- `CloudSignOutFlowLogic.cloudSignOutGroupsBlockReason` deja pasar `.sessionExpired`. `.permanent` y los demás
  motivos siguen igual.
- El resto de la cadena ya existía y tenía tests: el paso 2 escribe el motivo traducido en la fase, Ajustes lo
  manda al aviso del bloqueo y `SignOutBlockedCopy` le pone el texto de sesión caducada, en los 16 locales.
- Dos docblocks habrían quedado falsos (el de `.permanent` y el de la traducción). Al de `.sessionExpired` se le
  añade lo que su aviso todavía no distingue.

**Lo medido que corrige el ticket.** «`pushAllPendingForSignOut` corta en `.drained` sin ciclar» no es exacto:
corre un ciclo y da `.drained` porque el outbox personal está vacío, salga lo que salga del ciclo
(`CloudMigrationController.swift:406-409`). La conclusión se sostiene: el caso es alcanzable.

**Cómo se verificó.**

- `CloudSignOutGroupsReasonTests`: la tabla por `allCases` con la fila nueva, y un caso que compone la cadena
  entera (`classify` → traducción → texto del aviso), con la cuenta no disponible como vecino que sigue en el
  genérico.
- **3 mutantes compilados y corridos, 3 muertos**, cada uno por los dos tests y con fallo de aserción, no de
  compilación: volver a `.permanent`, devolver `.uploadRetryLater` y arrastrar `.permanent` a `.sessionExpired`.
  Antes, un control sin mutante: 5 de 5 en verde.
- Una lente adversarial de solo lectura: con este motivo no cambia ninguna acción, solo el texto y el slug del
  log; los tests matan los tres mutantes, y los dos hallazgos de abajo son reales.

**Lo que no cierra, con ticket propio.**

- `groups-push-reads-an-offline-token-refresh-as-a-session-expiry` (`medium`, decisión): «Tu sesión caducó»
  también sale **sin conexión** con el token caducado. Ya pasaba en el «equipo», en solo grupos, en el desasociar
  y en el Welcome; con este cambio llega a la nube. **Cerrado el 2026-09-15 en el canal de sincronización:** sin
  red ya no sale en ninguna de esas pantallas. El guion de abajo sigue valiendo, porque borra la sesión en el
  servidor y cierra con la red puesta.
- `cloud-session-expiry-with-only-group-changes-has-no-sign-in-door` (`medium`, decisión): en la nube, «vuelve a
  iniciar sesión» no dice dónde. La única puerta es «Nuevo grupo», solo si el SDK borró la sesión, y no está
  medido que exija la misma cuenta.
- `cloud-signout-collapses-the-personal-push-all-reason-into-permanent` (sigue en backlog): con cambios
  personales pendientes bloquea el paso 1 y el aviso vuelve a ser el genérico.
- Anotado en `groups-outbox-rows-without-a-live-session-have-no-exit`: la nube entra en su población.

## Device-QA — NO simulable

**Por qué no se simula.** El aviso solo sale al cerrar sesión en una cuenta **en la nube**, y bajo `-uitest`
nada pone el modo `.cloud`. Solo lo escriben la migración y el alta en la nube (`MigrationWorkExecutor`,
`BornCloudSignUpService`), y ninguno de los 27 hooks `-uitest-*` lo toca. Crear ese seam quedaba fuera del
encargo.

**Montaje.** El mismo teléfono sirve para el guion de `cloud-signout-collapses-every-groups-transient-into-permanent`.

1. iPhone con **Yala Dev**, que habla con staging. Una cuenta **en la nube** con al menos un grupo.
2. No toques movimientos personales durante la prueba. Si queda uno sin subir, el cierre se bloquea un paso
   antes y sale el aviso de siempre: eso es `cloud-signout-collapses-the-personal-push-all-reason-into-permanent`.

**Recorrido.**

1. Ajustes → «¿Dónde viven tus datos?» → «Modo Nube · Auth». Apunta la hora `exp` que sale junto a tu
   usuario: es cuando caduca el token de acceso.
2. Pon el **modo avión** y crea un gasto en el grupo. Queda sin subir.
3. En el Mac, abre el SQL editor de Supabase **staging** (nunca producción). Busca tu `id` por tu correo en
   Authentication → Users y ejecuta `delete from auth.sessions where user_id = '<tu id>';`. Así el token ya
   no se puede renovar.
4. Deja la app en segundo plano hasta que pase la hora `exp` del paso 1.
5. Quita el modo avión, abre Yala y ve a Ajustes → «Cerrar sesión» → confirma en la hoja.
6. **Esperado:** «No pudimos cerrar tu sesión», con el texto **«Tu sesión caducó. Vuelve a iniciar sesión e
   inténtalo de nuevo.»** No debe decir «Revisa tu conexión». La sesión no se cierra y el gasto sigue en el
   grupo.

**Si sale «Revisa tu conexión»:** comprueba que no quedaba ningún movimiento personal sin subir. Con uno
pendiente, bloquea el paso 1, y eso no es este ticket.

## Barrido de `qa` · 2026-09-23 · cerrado sin device-QA

Sale de la cola de device-QA por el barrido que pidió Jürgen el 2026-09-23 (encargo `2026-09-23-barrido-qa-in-qa-pre-device`). Solo cambia el texto de un aviso, y montarlo pide borrar la sesión con SQL en staging y esperar hasta una hora sin red. Lo cubre `CloudSignOutGroupsReasonTests`.
