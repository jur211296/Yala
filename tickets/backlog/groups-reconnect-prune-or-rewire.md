---
id: groups-reconnect-prune-or-rewire
status: backlog
priority: medium
area: groups
created: 2026-08-08
updated: 2026-08-26
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
