---
id: personalization-shows-two-back-buttons
status: done
priority: low
area: "ajustes, navegación"
created: 2026-10-24
updated: 2026-10-28
source: "encargo 2026-10-24-idioma-ajustes-boton-muerto-2-2 (card 6d71), visto de camino"
---

# Personalización enseña dos botones «‹» arriba a la izquierda

## El problema, en lenguaje de usuario

Al entrar en Ajustes › Personalización, arriba a la izquierda salen dos flechas de volver, una al lado de la otra.
Las dos llevan a la lista de Ajustes.

## Qué se midió (2026-10-24, iPhone 17 Pro, iOS 27.0, Yala Dev de `origin/2.2` @ 9eeb954e6)

- Captura: `~/Claude/worktrees/_capturas/2026-10-24-idioma-ajustes-boton-muerto/personalizacion-doble-atras.png`
  (abierta con el toque normal en «Personalización», antes de tocar nada del idioma).
- `PersonalizationSettingsView` pinta su propio «‹» (`YalaToolbarButton`, `.topBarLeading`) y lleva `.swipeBack()`, que
  aplica `navigationBarBackButtonHidden(true)`. Aun así el «Atrás» del sistema aparece: el XCUITest
  `AppLanguageSettingsReturnUITests` lo encuentra como `BackButton`.

## Sin medir

- Si pasa en otras pantallas de Ajustes con el mismo molde (`YalaToolbarButton` + `.swipeBack()`), o solo aquí.
- Si es de iOS 27.0 o también de 26.x.
- Por qué `navigationBarBackButtonHidden` no se aplica aquí.

## Cierre (2026-10-28, card cuij, S16)

Ya estaba arreglado en la base cuando se lanzó la card. Medido:

- **Causa:** Ajustes ponía `.navigationBarBackButtonHidden(false)` por fuera en todas sus pantallas, y eso manda sobre el
  `swipeBack()` de dentro. Lo cerró 90b6e0870 (2026-10-25, carril del iPhone Duo) con `ProfileView.paintsOwnBackButton`,
  que incluye `.personalization` y las otras doce pantallas con «‹» propio.
- **Hermanas:** las ocho que usan el «‹» del sistema (Divisa, Favoritos, Vaciar datos, Face ID, iCloud, Privacidad IA,
  Almacenamiento, Cuenta de Yala) no pintan uno propio: ninguna lleva `swipeBack()` ni `chevron.left`.
- **Red:** `AppLanguageSettingsReturnUITests` afirma que en Personalización no existe `BackButton`; verde el 2026-10-28.
- **Simulador:** iPhone 17 Pro, iOS 27.0, un solo «‹» (captura en el PR de S16).
