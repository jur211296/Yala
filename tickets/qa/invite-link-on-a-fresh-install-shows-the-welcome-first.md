---
id: invite-link-on-a-fresh-install-shows-the-welcome-first
status: qa
priority: medium
area: "groups, onboarding"
created: 2026-10-20
updated: 2026-10-20
source: "tablero-al-abrir-un-enlace-de-invitacion-en-una-z81w (QA guiado del TF19, 2026-10-20)"
---

# Al abrir un enlace en una instalación nueva, la bienvenida sale 10-15 s antes que la invitación

## En lenguaje de usuario

Instalo Yala y abro el enlace del grupo. Durante 10-15 s veo la bienvenida normal y puedo tocar «Empezar» e irme por otro camino; después aparece «Conecta tu cuenta».

## Lo medido (2026-10-20)

- Los 10-15 s son la espera del import de iCloud que el reconciler del arranque hace antes de encaminar la invitación (`AppBootstrapper.awaitPersonalStoreReady` → `forceFetchAndWait(timeout: 15)`). En una instalación nueva el montaje es neutro: no hay import que esperar.
- Mientras tanto la bienvenida está montada e interactiva.

## Lo que cambia (decisión de Jürgen)

- **«Abriendo tu invitación…»** sin botones tapa la bienvenida (y VoiceOver no la lee) desde que llega un enlace con el onboarding sin hacer, hasta que la cadena del invitado la releva (firmar, consentir, la hoja o su puerta), el enlace no se puede abrir, el join sale directo, el reconciler no tiene nada que enseñar (ya es miembro, canal apagado) o vence un techo de 20 s, tras el que vuelve la bienvenida normal (canario `inviteOpeningCeilingReached`). **El techo cuenta desde que la pantalla aparece**, no desde que llega el enlace: en frío el enlace llega antes del splash (review adversarial). Estado del proceso: `InviteOpeningState`; decisión: `InviteOpeningLogic`. 16 idiomas.
- El reconciler del arranque **no espera al import** con un enlace en este arranque, sin espejo montado y en `.icloud` (`InviteOpeningLogic.routesWithoutImportWait`). Cualquier otro arranque espera como antes.

## Fuera, a propósito

- Un relanzamiento desde la pantalla de inicio (sin volver a abrir el enlace) no enseña la pantalla de apertura y el arranque espera al import como antes: el «tap» del enlace vive en memoria.
- Inferido, sin medir: si el arranque llegara al reconciler antes de que el sistema entregue el enlace, esperaría al import como antes. Hoy el arranque tiene varios pasos con red antes de ese punto.
- Ver el grupo antes de pedir cuenta (L12-17, 2.2).
- La selección de idioma (solo con un idioma del sistema no soportado) no se tapa.

## Tests

`InviteOpeningLogicTests` y `InviteOpeningStateTests` (con el techo), `InviteOpeningWiringTests`, XCUITest `WelcomeInviteOpeningUITests` con el seam `-uitest-invite-opening` (la pantalla sin botones y la bienvenida de vuelta al vencer el techo; control sin enlace).

## Device-QA (Jürgen, iPad, Yala Dev contra staging)

1. Borra Yala, reinstala sin abrir y abre el enlace de «QA unión 19» con el cronómetro en marcha.
2. Esperado: desde el primer instante «Abriendo tu invitación…» sin botones, y «Conecta tu cuenta» en 1-2 s (más si la red es lenta).
3. Esperado: en ningún momento se puede tocar «Empezar».
