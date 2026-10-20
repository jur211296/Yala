---
id: groups-tab-stays-empty-after-signing-in-to-a-groups-only-account
status: qa
priority: high
area: "grupos, sync"
created: 2026-10-19
updated: 2026-10-19
qa-status: needs-testing
source: tarjeta del tablero `tablero-al-volver-a-tu-cuenta-de-grupos-por-ya-t-ewkw` (QA guiado del 2026-10-19, C · D5 paso 1)
---

# Al volver a tu cuenta de Grupos por «Ya tengo una cuenta», tus grupos no aparecían hasta cerrar y abrir Yala

## Qué le pasaba al usuario

Instalación limpia › «Ya tengo una cuenta» › Google con una cuenta solo-grupos de producción que es admin de un grupo.
La pestaña Grupos se quedaba en «Sin grupos» más de un minuto. Al cerrar y abrir Yala, el grupo aparecía en el acto.

## Causa (medida en código)

- El canal de Grupos solo lo arrancaban el arranque en frío, la vuelta a primer plano y el cierre de
  `GroupsSignInView`. En este camino la sesión nace con la app abierta (`onEnterGroupsOnly`) y no pasa ninguno: el
  arranque en frío fue sin sesión y `GroupsSignInView` no se presenta.
- El pull que pide la pestaña al aparecer (`refreshFromCloud` → `syncNowFromPush`) exige el `context` que solo fija
  `startIfEligible`, así que volvía `false` sin tocar la red.
- La hipótesis de la card se confirma. La alternativa del App Attest no encaja: exige un loop vivo en backoff, y aquí no
  lo había. Que en staging sí bajara se explica, inferido, por una vuelta a primer plano después de guardar la sesión
  (la hoja de Google al cerrarse), que en producción llegó antes por el re-registro del attest.

## Arreglo

La pestaña Grupos arranca el canal al aparecer (`startIfEligible(trigger: "groups-tab")`, con la misma guarda de
`-uitest` que los otros dos arranques), antes de pedir su pull. Con el loop vivo solo lo despierta; sin sesión o con el
flag apagado no hace nada. El comentario de `onEnterGroupsOnly` que ya lo daba por hecho pasa a ser verdad.

Tests: `YalaTests/CloudSync/GroupsSyncClientTests` (`tabPull_withANeverStartedChannel_reachesNoNetwork` fija el bug,
`tabStart_withALiveSession_pullsWithoutARelaunch` el arreglo, y el control `tabStart_withoutASession_staysOff`) y
`GroupsTabStartsChannelWiringTests` (la llamada, su guarda y su orden en el `onAppear`).

## Device-QA (Jürgen, iPhone de QA, TestFlight contra producción)

1. Borra Yala e instálala de nuevo.
2. «Ya tengo una cuenta» › Google con admin@yala-app.pe (solo-grupos, admin de «QA D3»). Acepta el consentimiento.
3. Entra en la pestaña Grupos **sin cerrar Yala**.
4. **Esperado:** «QA D3» aparece en unos segundos, sin relanzar.
