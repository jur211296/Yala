---
id: welcome-2-3-visual-adjustments
status: done
priority: medium
area: onboarding
created: 2026-11-13
updated: 2026-11-13
source: comentarios de Jürgen del 13-nov tras ver Yala Dev 2.3 en su iPhone 14
---
# Bienvenida 2.3: ajustes visuales, tres botones de entrada iguales y logo nítido

Card del tablero: `tablero-bienvenida-2-3-ajustes-visuales-tres-bot-4v27`.

## Qué pidió Jürgen

1. Quitar el círculo de arriba a la derecha (el sitio de la mascota, que en 2.3 no va).
2. Logo un poco más grande.
3. El lema con la fuente del prototipo, en dos líneas exactas: «Tus finanzas personales,» y «sin esfuerzo.», que
   quepa así en el iPhone más chico.
4. Sin la etiqueta «EJEMPLO» en la vitrina.
5. Cada minidescripción de la vitrina en una línea como máximo, reescrita más corta.
6. «Dividir gastos con amigos» fuera de la vitrina, debajo de los tres botones.
7. El tercer botón dice «iCloud privado».
8. Los tres botones de entrada con el mismo diseño (referencia: botones de inicio de Vercel).
9. Logo nítido en la bienvenida y en las pantallas de espera.

## Qué se hizo

- `WelcomeShowcaseView`: cabecera solo con el logo (40 pt, antes 30), lema en Bricolage Grotesque ExtraBold 28 pt en un
  solo `Text` de dos líneas que encoge entero si no cabe, sin «EJEMPLO», minidescripción con `lineLimit(1)`, accesos
  con el componente nuevo `WelcomeAccessButton` (cristal medio, borde fino, ícono + texto centrados en cada botón;
  iCloud privado algo más alto, con su línea debajo) y «Dividir gastos con amigos» debajo de ellos.
- `WelcomeShowcaseLogic.offersGroupsDoor(on:providersAvailable:)`: el atajo sale siempre en «Mis finanzas» con
  entrada a la cuenta, ya no según la función que rota.
- `YalaLogo` pasa a SVG vectorial con «Preserve Vector Data», trazado desde las capas de 1024 px del ícono de la app.
  Lo usan la bienvenida, el arranque y las pantallas de espera.
- Fuente empaquetada en `Yala/Resources/Fonts/` con su licencia OFL y registrada en `UIAppFonts`.
- Textos: las siete minidescripciones y el tercer acceso, más cortos, en los 16 idiomas.

- `WelcomeBackButton`: el «‹» del Welcome sale blanco (antes, índigo).

## Decisiones

En el Paso 0 del encargo (cuerpo del PR).
