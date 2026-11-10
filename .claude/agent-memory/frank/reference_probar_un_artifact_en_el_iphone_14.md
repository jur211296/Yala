---
name: probar-un-artifact-en-el-iphone-14
description: Cómo abrir y probar un artifact privado de claude.ai en el iPhone 14 de pruebas con Device MCP, y qué falla de un prototipo web dentro del marco del artifact en móvil.
metadata:
  type: reference
---

Medido el 2026-11-07 (propuestas de bienvenida 2.3, artifact privado):

- **Safari del iPhone 14 ya tiene sesión en claude.ai**: un artifact privado abre sin login con
  `xcrun devicectl device process launch --device <udid> --payload-url "<url>#hash" com.apple.mobilesafari`.
  El `#nombre` (letras, dígitos, guiones) llega a la página: sirve para abrir una dirección o un modo concreto.
- **`take_screenshot` con `max_width` menor que 390 cambia la escala**: las coordenadas de `tap` son puntos
  (390 de ancho). Con `max_width: 390` se lee y se toca en el mismo marco; con 300, dos toques fallaron.
- Dos toques seguidos en menos de ~300 ms Safari los trata como doble toque: el segundo no llega.
- **Un teléfono simulado dentro de la página atrapa el desplazamiento** en el iPhone (no en escritorio) y
  `scrollIntoView` mueve toda la página. Arreglo: modo pantalla completa (la pantalla ajustada al alto, mandos
  flotantes) y desplazar solo la tira con `scrollLeft`. Verlo en el teléfono antes de dar por bueno el móvil.
- No usar `-uitest` en el iPhone físico para ver el Welcome: sus defaults efímeros PURGAN del almacén persistente
  las marcas de onboarding hecho (ver `UITestEphemeralDefaults.swift`).
- Las notificaciones personales del 14 pueden aparecer encima: no se tocan.

Relacionado: [[conducir-el-iphone-real-con-device-mcp]], [[el-iphone-de-pruebas-es-el-14-por-cable]].
