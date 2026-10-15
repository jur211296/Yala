---
name: entradas-de-fuera-en-el-simulador
description: Cómo disparar en el simulador lo que entra desde fuera de Yala (widgets, Siri, Atajos, notificaciones) y qué no se puede
metadata:
  type: reference
---

Medido el 2026-10-15 (lote 15, iPhone 17 Pro, iOS 27.0, Yala Dev):

- **El toque de un widget** = su URL. `-uitest-deeplink-url yaladev://…` la mete por `handleIncomingURL` sin el
  diálogo «¿Abrir en "Yala Dev"?» que saca `simctl openurl`. El esquema de Yala Dev es `yaladev`; `yala://` abre la
  app de producción si está instalada.
- **Siri**: la app Atajos del simulador (Biblioteca › Yala Dev) lista las acciones de Yala y **las ejecuta** al
  tocarlas; ahí se ve la pregunta de «Anotar con Siri». Su cuadro de texto no está en el árbol de accesibilidad: se
  ve, no se escribe.
- **Notificaciones**: `simctl push` falla con «Source is not authorized» si la app no tiene permiso, y
  `simctl privacy grant` no acepta `notifications`. El destino del toque se mide con `-uitest-deeplink <destino>`.
- **Widgets en la galería**: si la app y el widget discrepan en la divisa, falta `defaultCurrencyCode` en
  `UserDefaults` (la semilla no pasa por el onboarding): `-defaultCurrencyCode PEN` como argumento lo arregla.
- **Girar o abrir ventanas** sin Simulator.app: XCUITest temporal ([[girar-simulador-sin-simulator-app]]). Las
  capturas en horizontal salen giradas: `sips -r 270`.
- **`ShortcutsLink` y `SiriTipView` los dibuja iOS**: en Yala Dev el botón sale cortado («Atajos de», ni con
  `.fixedSize()`) y la sugerencia dice «Yala Dev». En una maqueta de propuesta, avisa de ello en el texto.

Relacionado: [[capturar-widgets-por-galeria]], [[yala-ia-en-el-simulador]].
