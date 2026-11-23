Yala
# Arreglar que Yala vuelva a la bienvenida después de «Ya está tu cuenta»
---
toca: Yala/App/Views/Onboarding/,Yala/App/ContentView.swift,Yala/App/Models/AppRouter.swift,Yala/App/YalaApp.swift,YalaTests/WelcomeTrasCuentaLista/,YalaUITests/WelcomeTrasCuentaLista/,Yala/Resources/de.lproj/WelcomeTrasCuentaLista.strings,Yala/Resources/en-GB.lproj/WelcomeTrasCuentaLista.strings,Yala/Resources/en.lproj/WelcomeTrasCuentaLista.strings,Yala/Resources/es-419.lproj/WelcomeTrasCuentaLista.strings,Yala/Resources/es-AR.lproj/WelcomeTrasCuentaLista.strings,Yala/Resources/es-ES.lproj/WelcomeTrasCuentaLista.strings,Yala/Resources/es.lproj/WelcomeTrasCuentaLista.strings,Yala/Resources/fr.lproj/WelcomeTrasCuentaLista.strings,Yala/Resources/it.lproj/WelcomeTrasCuentaLista.strings,Yala/Resources/ja.lproj/WelcomeTrasCuentaLista.strings,Yala/Resources/nl.lproj/WelcomeTrasCuentaLista.strings,Yala/Resources/pl.lproj/WelcomeTrasCuentaLista.strings,Yala/Resources/pt-BR.lproj/WelcomeTrasCuentaLista.strings,Yala/Resources/pt-PT.lproj/WelcomeTrasCuentaLista.strings,Yala/Resources/pt.lproj/WelcomeTrasCuentaLista.strings,Yala/Resources/zh-Hans.lproj/WelcomeTrasCuentaLista.strings,tickets/backlog/welcome-returns-after-the-account-is-ready.md,tickets/done/welcome-returns-after-the-account-is-ready.md,tickets/backlog/2026-11-22-welcome-vuelve-tras-cuenta-lista.md,tickets/done/2026-11-22-welcome-vuelve-tras-cuenta-lista.md
esfuerzo: high
cierre: cierra-sola
---

Jürgen pidió el 22-nov (15:08 Lima) encolar todo lo pendiente del backlog que esté claro o tenga decisión. Este encargo junta tickets afines.

## Tickets
- `tickets/backlog/welcome-returns-after-the-account-is-ready.md`

## Qué hacer
Reproduce el ticket crítico: al terminar «Ya está tu cuenta», Yala vuelve a la bienvenida y hay que reabrir la app. Encuentra la causa raíz, arréglala y deja una prueba de interfaz que lo cubra para cuenta nueva con iCloud privado, con Modo Nube y con solo grupos.

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

## Paso 0 — decisiones (resueltas en semi, sin consultar)

1. **¿Sigue pasando el ticket en `origin/2.3`?** No por el camino del ticket: la causa raíz (el respaldo del `onDismiss`
   del cover leía `hasCompletedOnboarding` de un `@Binding` capturado al presentar, `false`, con `true` en disco) se
   arregló el 14-nov en el commit «Empezar entra en la app» (card c8i9, lectura de disco en `welcomeCoverDidDismiss`).
   El ticket es del 13-nov y nunca se movió. ⇒ se verifica con una prueba de interfaz que reproduzca el mecanismo real
   y un mutante que devuelva la lectura vieja; si da rojo con el mutante y verde sin él, el ticket va a `done`.
2. **Cómo llegar a «¡Tu cuenta está lista!» en el simulador, que no inicia sesión.** Se amplía el seam existente
   `-uitest-unified-access-phase` con `reentry-ready` (llama al `onAdoptStarted` real con el cover abierto y aterriza
   en `.reentryReady`), `born-ready` (aterriza en `.bornCloudReady`) y `groups-only` (llama al `onEnterGroupsOnly`
   real). Sin red, solo DEBUG. Alternativa descartada: un seam que fuerce el respaldo (dejaría ciego al test).
3. **Las tres entradas del encargo** = cuenta nueva con iCloud privado (vitrina → iCloud → conversación → app), Modo
   Nube (re-entrada, el caso literal del ticket, y alta nueva: «Creamos tu cuenta» → conversación → app) y solo
   grupos (entrada que el servidor clasifica como solo grupos → educativo → formulario del grupo → pestaña Grupos).
   En cada una se afirma que se llega a la app y que la bienvenida no vuelve en los segundos siguientes.
4. **Textos nuevos:** ninguno. La tabla `WelcomeTrasCuentaLista.strings` no se crea (no hay copy que poner).
5. **Fuera del toca:** solo el docblock del seam en `Yala/App/UITestHooks.swift` y el índice de QA. Se anota.
