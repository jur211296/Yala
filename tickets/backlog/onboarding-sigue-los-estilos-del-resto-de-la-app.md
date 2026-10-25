---
id: onboarding-sigue-los-estilos-del-resto-de-la-app
status: backlog
priority: high
area: "onboarding, welcome, design-system"
created: 2026-10-25
updated: 2026-10-25
source: "Jürgen, sesión «iPhone Duo cerrado interactivo · cortes», 2026-10-25"
---

# El Welcome y el onboarding no siguen los estilos del resto de la app

## Lo que dijo Jürgen

> «Siento que el onboarding no sigue los estilos del resto de la app (fuentes, botones, textos).»

Salió mientras revisábamos el Welcome en el iPhone Duo cerrado, a raíz del «Volver». Ya está resuelto en esa misma sesión:
ahora el botón atrás es el del sistema, con el chevron en su círculo de cristal, como en el resto de la app, y en el Duo
cerrado pasa a la barra vertical. Lo demás queda para esta card.

## Qué revisar

Hay que comparar pantalla por pantalla el Welcome (Hero, selectores, puertas, inicio de sesión) y el onboarding
(`OnboardingView`) con las pantallas de la app, en tres ejes:

- **Fuentes:** el titular serif de los selectores (`DS.Typography.welcomeHeadline`) y el resto de tamaños y pesos frente a
  los del DS.
- **Botones:** las píldoras llenas y de contorno del Welcome frente a los estilos de botón de la app.
- **Textos:** tono y longitud del copy frente a `BRAND-VOICE.md`.

## Lo que ya está decidido y no se toca sin preguntar

- **El fondo del Welcome «se ve igual siempre»**: es el degradado índigo→negro fijo, sin tema (`WelcomeFlowStyle`).
- **La forma de los selectores** sale de la referencia del 15-sep (`WelcomeForm.swift`): titular serif, una tarjeta y
  ningún botón recomendado. Se trajo la jerarquía, no la superficie.

Si una de las dos choca con «seguir los estilos de la app», se le pregunta a Jürgen; no se decide aquí.

## Cómo empezar

Con capturas lado a lado (Welcome contra una pantalla equivalente de la app) y 3-4 propuestas para que él elija. Es una
sesión de diseño con Jürgen delante, no un lote autónomo.
