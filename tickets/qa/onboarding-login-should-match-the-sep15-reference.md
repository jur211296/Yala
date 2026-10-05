---
id: onboarding-login-should-match-the-sep15-reference
status: qa
priority: medium
area: "ux, onboarding, welcome"
created: 2026-09-17
updated: 2026-10-02
qa-status: needs-testing
source: "Pack UI 15-sep (Dan) — Jürgen 2026-09-17: cada punto del pack = ticket aparte"
---

# El onboarding / login de Yala debe acercarse a la referencia del 15-sep

## Qué quiere Jürgen

La pantalla de entrada / onboarding debe alinearse con la referencia del 15-sep: captura en `docs/design/referencias/` y memoria `.claude/agent-memory/frank/reference_ui_onboarding_login.md`.

## Rasgos a llevar (de la referencia)

1. Titular cálido + una línea que diga las formas de entrar.
2. Formulario en una sola tarjeta (campos, botón, separador, Google, explorar sin cuenta).
3. Etiqueta encima del campo; secundarios alineados a la derecha.
4. Tres pesos de botón por importancia.
5. Salida sin cuenta visible dentro de la tarjeta.
6. Copy acorde a la región (voseo / tono Yala).

## No inventar

Usar la referencia ya escrita. No mezclar con Siri ni con el chat Yala IA (ticket aparte).

## Hecho (2026-10-02)

Las cinco pantallas de entrada del Welcome tienen la forma de la referencia: titular en serif sin logo,
una línea con las formas de entrar, todo lo que se elige dentro de UNA tarjeta de borde fino y «Volver»
en píldora con la palabra. Se mantiene el degradado oscuro del Welcome: de la referencia se trae la
jerarquía y el contenedor, no el fondo blanco.

- **«Ya tengo una cuenta»** es el «¡Hola de nuevo!»: Apple y Google llenos (mismo peso), «o», y
  Restaurar desde iCloud con contorno, que es la entrada sin cuenta de Yala. Debajo, fuera de la
  tarjeta, «¿Es tu primera vez en Yala? Empieza aquí», que lleva a «Es mi primera vez».
- **Chooser, «Es mi primera vez» y «Vengo por un grupo»**: las opciones son filas de una sola tarjeta,
  con el mismo peso (en «Es mi primera vez» ninguna se recomienda, decisión del 2026-08-10).
- **Entrada a la nube** (intro de re-entrada y alta): titular serif y tarjeta con el botón de marca y su
  nota; «Crear otra cuenta» pasa a botón con contorno dentro de la tarjeta.
- Copy nuevo en los 16 idiomas (título y subtítulo de «Ya tengo una cuenta», el «o» y la pregunta de pie).

Premisa medida: Yala SÍ tiene Google (re-entrada y alta). Las decisiones, en el Paso 0 del PR.

## Guion de QA en iPhone

1. Borra Yala del iPhone e instala el build de TestFlight que trae este cambio.
2. Abre Yala y toca **Empezar**. Comprueba: arriba a la izquierda una píldora «‹ Volver»; el titular
   «¡Hola! ¿Qué quieres hacer en Yala?» en letra con serifa; las tres opciones dentro de una sola
   tarjeta, separadas por líneas finas; sin logo.
3. Toca **Ya tengo una cuenta**. Comprueba: titular «¡Hola de nuevo!»; en la tarjeta, «Entrar con Apple» y
   «Entrar con Google» en blanco, una «o», y «Restaurar desde iCloud» solo con borde; debajo de la
   tarjeta «¿Es tu primera vez en Yala? Empieza aquí».
4. Toca **Empieza aquí**. Debe abrir «Es mi primera vez» (las dos opciones de dónde guardar los datos) o,
   si este Apple ID ya tiene cuenta en la nube, la pantalla para entrar con ella.
5. Toca **Volver** hasta el Chooser, entra en **Ya tengo una cuenta → Entrar con Apple**. Comprueba el
   titular «Entra a tu cuenta» y el botón de Apple dentro de una tarjeta. No inicies sesión.
6. En Ajustes de iOS › Accesibilidad › Pantalla y tamaño del texto › Texto más grande, sube al máximo y
   repite el paso 2: el titular no debe quedar debajo de la píldora y la pantalla debe hacer scroll.
