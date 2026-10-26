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

## Propuestas (2026-10-26, sesión S4)

Lienzo con capturas lado a lado y las maquetas: https://claude.ai/artifact/F4QUNid2UUSuN9MRGbCzFA
Capturas originales (iPhone 17 Pro, Yala Dev, base `origin/2.2`): `~/Claude/worktrees/_capturas/onboarding-estilos/`.

Lo medido, eje por eje:

- **Botones.** Dentro del Welcome conviven dos familias: la cápsula índigo de la app (`YalaPrimaryButton`, 15 pt
  medium: «Empezar», «Siguiente», «Abrir Ajustes») y el rectángulo redondeado blanco o de contorno de
  `WelcomeFormButton` (17 pt semibold), que solo usan «Ya tengo una cuenta» y la entrada a la nube (6 llamadas).
- **Titulares.** Tres estilos en la entrada: Hero en sans semibold centrado, selectores en serif bold a la izquierda
  (`DS.Typography.welcomeHeadline`, el único serif de la app) y onboarding en sans semibold centrado con icono. La app usa
  el título pequeño de la barra y cabeceras de sección en sans a la izquierda.
- **Listas.** Selectores y Ajustes agrupan las opciones en una tarjeta con separadores; el onboarding pone una tarjeta
  por opción (cinco en «¿Dónde está tu dinero?»).
- **Textos.** «Empieza desde cero conmigo. Te ayudo…» es la única primera persona del singular de la app (el resto
  habla en plural: 11 frases con «te ayudamos», «te avisamos», «te guiamos»…); «depa» es regional (BRAND-VOICE §2.3);
  «Tu info» frente a «tus datos» del resto.

Las cuatro decisiones que esperan a Jürgen:

| | A (recomendada) | B | C |
|---|---|---|---|
| **D1 Botones** | `WelcomeFormButton` pasa a cápsula y 15 pt medium; sigue blanco lleno / contorno | Se queda el rectángulo | — |
| **D2 Titulares** | El onboarding adopta el titular serif a la izquierda, sin icono encima | Fuera el serif, titular de la app en todo. **Levanta la decisión del 15-sep** | Se dejan los tres |
| **D3 Listas** | Los pasos que eligen entre opciones usan una sola tarjeta con separadores | Se quedan sueltas | — |
| **D4 Textos** | «Empieza desde cero. Te guiamos paso a paso.» · «Viajes, casa compartida, salidas…» · «Tus datos, en tu iCloud.» (16 idiomas) | Se dejan | — |

No se tocan: el fondo índigo→negro fijo (`WelcomeFlowStyle`), el Hero con logo y carrusel, y la forma de los
selectores. Solo D2-B choca con ellos.
