---
id: groups-reconnect-prune-or-rewire
status: done
priority: medium
area: groups
created: 2026-08-08
updated: 2026-09-04
source: YalaWiki/Backlog/groups-reconexion-poda-o-recableado.md
---


# La maquinaria de reconexión de Grupos quedó sin emisor — ¿se recablea para el canal backend o se poda?

## El problema, en lenguaje de usuario

Cuando alguien reinstalaba Yala o estrenaba teléfono y volvía a abrir un enlace de un grupo que ya
era suyo, la app tenía una pantalla de «reconectar» que lo llevaba de vuelta sin duplicar nada. Esa
pantalla pertenecía al mundo CloudKit: **hoy ya no hay ningún camino que la muestre.** Hay que
decidir si el canal nuevo la necesita (y se recablea) o si el re-join del backend la sustituye (y se
poda).

## Contexto técnico (medido por el punto de control el 06/08 — re-medir al abrir)

- `InviteMetadata` (con `shareMetadata` dentro) lo comparten **TRES** cases del router —
  `presentGroupInviteOnboarding`, `presentGroupReconnect`, `offerRestoreBeforeInvite` — **los tres
  sin emisor** tras la Fase 3.
- `shareMetadata` tiene 3 lectores vivos: `ContentView:1650` (`handleReconnectJoin`), el `==` de
  `RouterIntent:76` y el `if` de `:384`.
- Retirarlo arrastra: `GroupReconnectView`, `handleReconnectJoin`, el `Equatable` y
  `InviteRouteDecision`.
- **El propio código pide esta decisión:** `AppBootstrapper.swift:1915-1918` declara la pieza
  huérfana y añade que se conserva «porque `ReconnectMode` y su tabla siguen describiendo la UI de
  reconexión que el canal backend usa, y podarla es decisión de producto».

## La pregunta de producto

**¿El usuario que reinstala/cambia de device y vuelve a un grupo del canal backend necesita una UI
de reconexión, o el flujo backend ya lo cubre sin ella?** Hipótesis a verificar antes de decidir:
con sesión viva, el pull re-baja el corpus entero (grupos incluidos) sin pasar por ninguna pantalla;
sin sesión, el sign-in contextual + `member_key`/re-invite token cubren el re-join. Si ambas se
confirman, la reconexión CloudKit-era no tiene equivalente que construir — solo código que retirar.

## Opciones

- **(a) Podar entero** (si la verificación confirma que el re-join backend cubre ambos casos):
  retirar los 3 cases, `GroupReconnectView`, `handleReconnectJoin`, `Equatable` e
  `InviteRouteDecision`. Es la opción coherente con el criterio de la Fase 3 (código sin emisor con
  promesa escrita = la familia de `ensureRegistered()`).
- **(b) Recablear**: darle emisor backend a esta maquinaria (solo si aparece un caso real que el
  re-join no cubra — p. ej. restore de iCloud con enlace en frío).
- **(c) Statu quo**: huérfano declarado. Costo: código muerto cuyo docblock promete una UI que nadie
  puede alcanzar — exactamente la clase de deuda que esta épica lleva un mes pagando.

## Al abrir el ticket

1. Verificar las dos hipótesis del re-join (con sesión / sin sesión) en código y, si se puede, en
   device (par de dogfooding).
2. Decidir (a)/(b)/(c) con el owner.
3. Si (a): commit sustractivo con las cifras re-medidas + XCUITest del re-join si no existe.

migrated from YalaWiki Backlog/groups-reconexion-poda-o-recableado.md @ 1934e8ad

---

## CERRADO · 2026-09-04 — se decidió (a), podar, y ya está ejecutado

Este ticket pedía «verificar las dos hipótesis del re-join y decidir (a)/(b)/(c) con el owner».
Las dos cosas ocurrieron el 2026-09-04, dentro de `guest-journey-dead-screens`:

**Las hipótesis se verificaron, y salieron PARCIALES — no confirmadas.** Con sesión viva el pull
re-baja el corpus entero sin pasar por ninguna pantalla, y el RPC `join_group` cubre ya-miembro,
pendiente, rechazado, expulsado y grupo borrado. Pero aparecieron casos sin salida, y el mayor es
que **al rechazado que tapea un enlace con la app cerrada no le pasa nada, de forma permanente**.

**Aun así la decisión es (a), y el matiz importa:** ninguno de esos casos lo habría rescatado una
pantalla de reconexión. Mueren aguas arriba —en `enterBackendInvite` y en `decideBackend`— antes de
cualquier presentación. La opción (b), recablear, no era la respuesta a lo que se encontró.

⇒ La poda se ejecutó en `4f01484e`: fuera `GroupReconnectView`, los ocho `ReconnectMode`,
`handleReconnectJoin`, el `Equatable` e `InviteRouteDecision` con sus 23 pruebas. **El copy
`groups.reconnect.*` se conservó en los 16 locales** a propósito: `deletedForAll.body` ya tiene un
segundo consumidor vivo en el canal backend, y los cuerpos de reintento son el texto que necesita
el arreglo del hueco.

El hueco encontrado vive en `tickets/backlog/rejected-member-cold-tap-does-nothing.md` (high). No
reabre esta decisión: su arreglo no necesita pantalla.

**Aviso de coordenadas:** las de este ticket estaban caducadas —situaba `inviteRouteDecision` en
`AppBootstrapper.swift:1915-1918` cuando al medirla estaba en `:2145-2179`, y `handleReconnectJoin`
en `ContentView:1650` cuando estaba en `:1973`—. Hoy ya no existen ninguna de las dos.
