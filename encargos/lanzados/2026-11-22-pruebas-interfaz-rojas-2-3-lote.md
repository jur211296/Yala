Yala
# Poner en verde las pruebas de interfaz rojas de 2.3: enlace a grupo, texto grande, Pagar ahora, convertir a grupo, cierre de sesión y widget
---
toca: YalaUITests/,tickets/backlog/2026-11-22-deeplink-grupo-arranque-en-frio-rojo-en-2-3.md,tickets/backlog/form-clarity-23-large-text-uitests-red-on-2-3.md,tickets/backlog/formclarity23-large-text-uitests-tap-offscreen.md,tickets/backlog/pay-now-uitest-stops-on-the-possible-duplicate-notice-in-2-3.md,tickets/backlog/personal-to-group-conversion-uitest-taps-the-loan-leg-bus-off-screen.md,tickets/backlog/private-sign-out-wait-uitest-times-out-on-2-3.md,tickets/backlog/widget-entry-background-uitests-red-on-2-3.md,tickets/backlog/account-card-reports-cashflow-carousel-uitest-is-flaky.md,tickets/done/2026-11-22-deeplink-grupo-arranque-en-frio-rojo-en-2-3.md,tickets/done/form-clarity-23-large-text-uitests-red-on-2-3.md,tickets/done/formclarity23-large-text-uitests-tap-offscreen.md,tickets/done/pay-now-uitest-stops-on-the-possible-duplicate-notice-in-2-3.md,tickets/done/personal-to-group-conversion-uitest-taps-the-loan-leg-bus-off-screen.md,tickets/done/private-sign-out-wait-uitest-times-out-on-2-3.md,tickets/done/widget-entry-background-uitests-red-on-2-3.md,tickets/done/account-card-reports-cashflow-carousel-uitest-is-flaky.md,tickets/backlog/2026-11-22-pruebas-interfaz-rojas-2-3-lote.md,tickets/done/2026-11-22-pruebas-interfaz-rojas-2-3-lote.md
esfuerzo: medium
cierre: cierra-sola
---

Jürgen pidió el 22-nov (15:08 Lima) encolar todo lo pendiente del backlog que esté claro o tenga decisión. Este encargo junta tickets afines.

## Tickets
- `tickets/backlog/2026-11-22-deeplink-grupo-arranque-en-frio-rojo-en-2-3.md`
- `tickets/backlog/form-clarity-23-large-text-uitests-red-on-2-3.md`
- `tickets/backlog/formclarity23-large-text-uitests-tap-offscreen.md`
- `tickets/backlog/pay-now-uitest-stops-on-the-possible-duplicate-notice-in-2-3.md`
- `tickets/backlog/personal-to-group-conversion-uitest-taps-the-loan-leg-bus-off-screen.md`
- `tickets/backlog/private-sign-out-wait-uitest-times-out-on-2-3.md`
- `tickets/backlog/widget-entry-background-uitests-red-on-2-3.md`
- `tickets/backlog/account-card-reports-cashflow-carousel-uitest-is-flaky.md`

## Qué hacer
Pon en verde cada prueba. Si la causa es la prueba (toque fuera de pantalla, espera corta o aviso de posible duplicado), arregla la prueba. Si es un bug real de la app, mídelo contra la versión publicada, arréglalo con lo mínimo fuera del toca si es chico y anótalo; si es grande, abre un ticket y no lo tapes en la prueba.

## Reglas
- Antes de tocar nada, verifica contra `origin/2.3` que cada ticket siga pasando (varios son viejos). Si uno ya no pasa o ya está hecho, muévelo a done con la evidencia y sigue con los demás.
- Si un ticket resulta ser una decisión de diseño o de producto que solo Jürgen puede tomar, no la inventes: déjalo en backlog con la pregunta y las opciones con su recomendación, y anótalo en el cierre.
- Textos nuevos en su propia tabla `.strings` (la del toca), no en Localizable.strings ni L10n.swift, en los 16 idiomas y siempre en español neutro latinoamericano (en es-ES también, sin vosotros).
- Si hace falta tocar algo fuera del toca, toca lo mínimo y anótalo en el cierre.
- Producción (iCloud Production, Supabase prod, gateway, web publicada) no se toca: déjalo probado en desarrollo y anotado para Dan, con el OK de Jürgen.
- Nada de pago.

## Dispositivos
Antes de usar un simulador, comprueba si el iPhone 14 conectado por DeviceMCP está libre; no lo des por ocupado sin comprobarlo. En la Max puedes usar un segundo simulador si otra sesión ya usa uno (tope 2); en la Mini, 1.

## Cierre
Commits y PR sin firma de IA y sin saltarse hooks. Espera el merge real del PR en 2.3 antes de `/cerrar-total`. Si a los ~45 min el CI sigue rojo por algo ajeno al PR, cierra y anótalo. El cierre incluye «Saltado o asumido sin preguntar» y «Decidido sin consultar», cada uno con motivo o «Nada».

## Paso 0 — decisiones (resueltas en autónomo (bypass), modo nocturno)

1. **¿Siguen rojas?** Medido antes de tocar: nocturna de 2.3 del 22-nov (run 44991989046, sobre b27dcc084) y corrida local
   sobre origin/2.3 = ea35c1234 (9 casos, iPhone 17 Pro iOS 27.2, `Yala Dev`, cola del simulador): **9/9 verdes en local**.
   En la nocturna, verdes todos menos «convertir a grupo», que arregló el commit 407e1a91f del mismo día (posterior a la
   nocturna) y en local pasa. ⇒ los 8 tickets van a `done` con la evidencia; no hay bug de app que medir contra lo publicado.
2. **`test_m1_largeText_theNoticeIsShown`** ya no existe en `FormClarity23UITests` (quitado en la reforma de la hoja B1, 20/21-nov):
   el ticket se cierra por eso, no por arreglo.
3. **Carrusel inestable** (low): verde hoy, pero el ticket pide algo concreto y barato en la prueba (esperar a la página quieta
   entre arrastres). Se hace: es solo prueba, no cambia la app. Se verifica con 3 corridas seguidas tras la tanda.
4. **Nada fuera del `toca`**; sin textos nuevos (no hacen falta tablas `.strings`).
5. **iPhone 14 por DeviceMCP**: no se usa; XCUITest se mide en el simulador, que es donde corre la nocturna.
6. El encargo trae una decisión de Jürgen pendiente de incorporar (Comercios en común, «Conecta tu IA»): no son de este
   lote; se dejan sin incorporar y se dice en el cierre.
