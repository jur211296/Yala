# El onboarding / login de Yala debe acercarse a la referencia del 15-sep

## Contexto
Jürgen pidió lanzar este ticket de Cola B ahora. Referencia visual del 15 de septiembre. Arrancas en contexto limpio.

Ticket: tickets/backlog/onboarding-login-should-match-the-sep15-reference.md
Captura: docs/design/referencias/2026-09-15-onboarding-login-referencia.jpg
Memoria, si el worktree la tiene: .claude/agent-memory/frank/reference_ui_onboarding_login.md
El worktree no hereda ficheros sin trackear. Los rasgos van aquí para no depender de eso.

## Que se pide
Alinear la pantalla de entrada / onboarding con la referencia del 15-sep. Apple-native, eficiente. Decide los detalles de UI; no pares a preguntarle a Jürgen salvo un riesgo real de producto.

La referencia es de jerarquía y contenedor, no de proveedores. Yala no tiene correo ni Google. «Explorar sin cuenta» equivale al modo local sin iCloud. No mezcles con Siri ni con el chat Yala IA (ticket aparte). No inventes: usa la captura y estos rasgos.

Vistas: Yala/App/Views/Onboarding/ — WelcomeChooserView, WelcomeNewChooserView, WelcomeExistingChooserView y sobre todo WelcomeCloudSignInView (hoy elige Restaurar iCloud o Sign in with Apple).

Rasgos:
1. Titular cálido en serif grande y una línea que diga las formas de entrar. Sin logo ni ilustración.
2. Formulario en una sola tarjeta con borde fino, sin sombra: campos, botón, separador, camino recomendado y salida sin cuenta. Fuera de la tarjeta solo la pregunta de pie.
3. Etiqueta encima del campo, no placeholder como etiqueta. Secundarios alineados a la derecha, en la misma línea que la etiqueta.
4. Tres pesos de botón por importancia: pasivo hasta que hay datos, lleno para el camino recomendado, contorno para explorar sin cuenta.
5. Salida sin cuenta visible dentro de la tarjeta, no escondida en un enlace.
6. Copy acorde a la región. El voseo de la captura es de la otra app; en Yala manda el registro de tono que ya esté decidido.
7. Botón «Volver» como píldora arriba a la izquierda, con icono y palabra, no solo chevron.

Abre docs/design/referencias/2026-09-15-onboarding-login-referencia.jpg antes de maquetar y contrasta contra esos rasgos.

Pipeline Mini serial (norma 2026-10-02): limpiar sims muertos; xcodebuild -jobs 2 SIN sim booteado; boot 1 sim; tests; apagar y limpiar ese sim. Prohibido solapar swift-frontend + SpringBoard + app + UITests. Máximo 1 simulador.

## Que NO hay que tocar
No marketing/. No otra sesión. No contestar correos. No mezclar con Siri ni con el chat Yala IA.

## Como se sabe que esta bien
PR a 2.1 con el onboarding/login alineado a la referencia, o un hallazgo medido si la premisa es falsa. Cierre autónomo con /cerrar-total. Al cerrar: apagar sim, borrar data de ese device, y si el PR quedó mergeado quitar worktree. Si creas un secreto en el Llavero, anótalo para 1Password (vault Yala; nunca keys de firma en Shared with Grok Bot).

## Paso 0 — decisiones

> Resueltas en autónomo (bypass, 22:20 Lima): las recomendaciones se dan por buenas. Se discuten en el PR.

**Hechos medidos antes de decidir.** (1) La premisa «Yala no tiene Google» es falsa: «Ya tengo una cuenta» ofrece Restaurar desde iCloud, Entrar con Apple y Entrar con Google, y el alta en la nube tiene los dos botones de marca. (2) Quien elige entre Restaurar y Apple es `WelcomeExistingChooserView`, no `WelcomeCloudSignInView`: ésta solo pinta el botón del proveedor ya elegido (o los dos, en el alta). (3) Todo el Welcome va sobre el degradado índigo→negro FIJO, por decisión de Jürgen (`WelcomeFlowStyle`). (4) Ninguna pantalla tiene campos de texto: no hay correo ni contraseña.

**D1 · ¿Fondo blanco como la captura?** → No: se queda el degradado oscuro del Welcome y la tarjeta es la `welcomeFlowCard` que ya existe (borde fino, sin sombra). Por qué: de una referencia ajena se trae la disciplina, no su superficie ni su paleta (memoria «tarjetas blancas: identidad»), y el Welcome «se ve igual siempre» es decisión suya. Descartado: un Welcome claro, que es otra identidad.

**D2 · ¿Qué pantallas?** → Las cuatro del encargo (Chooser, «Ya tengo una cuenta», «Es mi primera vez», intro de la entrada a la nube) **más «Vengo por un grupo»**, que es su calco y se abre desde el mismo Chooser. Por qué: dejarla con logo y cards sueltas rompe el recorrido a mitad (alcance mínimo salvo incoherencia). Las fases de progreso, error y relanzamiento de `WelcomeCloudSignInView` y las puertas de iCloud/Grupos no cambian, salvo el botón Volver, que es compartido.

**D3 · Titular** → Serif del sistema (New York) en `largeTitle` bold, alineado a la izquierda, sin logo. Token nuevo `DS.Typography.welcomeHeadline`. Escala con Dynamic Type.

**D4 · ¿Qué pantalla es el «¡Hola de nuevo!»?** → «Ya tengo una cuenta». Título nuevo «¡Hola de nuevo!» y una línea que dice las formas de entrar. Es el único copy nuevo de cabecera; las demás pantallas conservan su título, que ya es cálido o es la frase que la persona acaba de tocar.

**D5 · Pesos de botón en «Ya tengo una cuenta»** → Apple y Google llenos (blanco, misma forma y tamaño: prominencia equivalente, guideline 4.8), separador «o», y «Restaurar desde iCloud» con contorno. Cada bloque lleva su etiqueta encima (las líneas que ya existían). Por qué: el contorno es el camino SIN cuenta de Yala, que es lo que la referencia hace con «Explorar sin cuenta». **A revisar por Jürgen:** el orden cambia (antes Restaurar iba primero) y lo lleno puede leerse como recomendación de la nube.

**D6 · «Es mi primera vez»** → Las dos opciones dentro de una sola tarjeta, con el MISMO peso. Por qué: Jürgen decidió que ninguna se recomienda (chip RC, 2026-08-10) y la nube va primero (W2); eso manda sobre el rasgo 4 de la referencia. La opción privada es la salida sin cuenta y queda dentro de la tarjeta (rasgo 5). Se conservan títulos, cuerpos y la igualación de alto.

**D7 · Chooser y Grupos** → Opciones como filas de una sola tarjeta con separador fino; iconos tintados de siempre. Sin pesos: son caminos, no un formulario.

**D8 · Pie fuera de la tarjeta** → «¿Es tu primera vez en Yala? Empieza aquí» bajo «Ya tengo una cuenta», que lleva a la misma rama que la card «Es mi primera vez» del Chooser (con su faro). No se añade a las demás: no hay pregunta de pie que no repita el Volver.

**D9 · Volver** → Píldora arriba a la izquierda con chevron y «Volver» (clave que ya existe en los 16 idiomas), borde fino. Se cambia en el modificador compartido, así que la llevan las siete pantallas que lo usan. El identificador `welcome_back_button` no cambia.

**D10 · Copy y registro** → Tuteo neutro como el resto de `es`; voseo en `es-AR`, que ya lo usa. Claves nuevas: título y subtítulo de «Ya tengo una cuenta», el «o» y el pie. En los 16 idiomas.

**D11 · Entrada a la nube (intro)** → Titular serif + subtítulo, y una tarjeta con el botón de proveedor (o los dos, en el alta) y la nota debajo. «Crear otra cuenta» (solo encaminado por el faro) pasa a botón con contorno dentro de la tarjeta. El logo se queda en las fases que no son el intro.

**D12 · Pruebas** → Los identificadores de XCUITest no cambian. Se añade un XCUITest de la forma nueva (píldora con texto visible y pie de «Ya tengo una cuenta») y se corren las suites del Welcome.
