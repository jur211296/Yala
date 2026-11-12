# Armar con Jürgen el roadmap definitivo de Yala, preguntándole

## Contexto
2.1 se envió a revisión de Apple el 21-oct y está en Waiting for Review. 2.2 está en curso en lotes decididos: Grupos, Siri gratis, reportes, flujo de caja y más. Jürgen quiere planificar el roadmap EN CONJUNTO, en una sesión interactiva con preguntas. No quiere recibir una propuesta cerrada. Es de día y Jürgen está disponible.

## Qué se pide
1. Orientarse con lo que hay: STATE.md, DECISIONS.md (solo el índice y los ADR que hagan falta), docs/ con roadmap o tickets, el board (tablero listar --proyecto Yala, incluidas las cards en espera de decisión y el backlog) y lo que queda de 2.2.
2. Preparar un borrador corto de los temas: qué cierra 2.2, qué va en 2.3 y siguientes, monetización y Pro, Grupos, IA, marketing y lanzamiento, y la deuda técnica.
3. Ir preguntándole a Jürgen con AskUserQuestion, por bloques y con opciones concretas y una recomendación. Que sean pocas preguntas por vez. Por ejemplo: prioridades, qué entra en cada versión, fechas objetivo y qué se descarta.
4. Con sus respuestas, escribir el roadmap definitivo en docs/ROADMAP.md (versiones, contenido, criterios de terminado, fechas si las da) y anotar las decisiones en DECISIONS.md.
5. Proponer qué cards del board se mueven, se crean o se mandan a done según el roadmap, y aplicarlo con tablero después de su sí.

## Qué NO hay que tocar
- Ni código de la app ni el simulador, porque hay otra sesión de código viva.
- No decidir por Jürgen: si no contesta, esperar.
- No tocar los archivos sin commitear de Jürgen en ~/Yala.

## Cómo se sabe que está bien
Jürgen aprueba el ROADMAP.md, el board queda alineado y se abre un PR a 2.2. No cerrar con /cerrar-total hasta que Jürgen dé el roadmap por bueno.

## Paso 0

*Decidido al empezar, 2026-10-21. Lo que dice «asumido» no lo preguntó nadie: es el default sensato.*

- **Se parte del roadmap propuesto, no de cero.** En `2.2` ya está `docs/ROADMAP.md` (PR #565, propuesta del 19-oct,
  1367 líneas), con `docs/criterios-de-version.md` y `docs/roadmap-asignacion.tsv`. La card «Decidir el roadmap de Yala de
  2.1 a 4.0…» (`…-9qwu`) espera la decisión de Jürgen sobre él. Esta sesión convierte esa propuesta en decisiones, y el
  `ROADMAP.md` definitivo la sustituye.
- **Rama base: `2.2`** (asumido). El encargo pide PR a 2.2 y el roadmap vive ahí. La rama nació de `origin/2.1`; se
  rehízo sobre `origin/2.2` antes del primer cambio.
- **Medido el 21-oct, no copiado de la propuesta:** de los lotes decididos de 2.2 están mergeados 01, 03, 04, 05, 06, 09,
  10, 11 y Siri gratis; abiertos los PR #571 (07, Yala IA), #576 (08, widgets e iPad) y #588 (12, administrar grupos). Sin
  decidir ni construir: el lote 2 (formulario de registro, 22 cards), parte de Grupos I (L12, 11 en curso y 8 listas) y
  Ajustes (L16, 17 listas). Esperan a Jürgen: 36 cards en QA y 10 en espera de decisión.
- **Las fechas las pone Jürgen.** Si no da una, la versión sale por criterio, sin fecha (asumido).
- **Nada de código, simulador ni `marketing/`.** El marketing entra en el roadmap como plan; lo ejecuta Lola.
- **El board se toca solo tras su sí**, y con `tablero editar` leyendo antes la nota que se sustituye.

## Resultado

**Jürgen aprobó el roadmap el 2026-10-21**, después de seis tandas de preguntas y cuatro rondas de cambios suyos.

- `docs/ROADMAP.md` es el definitivo, de 2.2 a 4.0, sin fechas. Sustituye a la propuesta del 19-oct; de 1367 líneas pasa
  a unas 420, porque la versión de cada card vive ahora en el tablero.
- `docs/criterios-de-version.md` pasa a vigente, con dos ajustes: sin fechas, y la excepción de las betas que solo miran y
  dejan borradores.
- `docs/DECISIONS.md` lleva la entrada «Roadmap de Yala de 2.2 a 4.0 — por tema y sin fechas».
- Se retira `docs/roadmap-asignacion.tsv`: ya está aplicado al tablero.

**Lo que Jürgen cambió sobre la propuesta:**
- Sin 2.1.1.
- El atajo del banco, gratis y sin nube.
- El correo, por reenvío, y «Conectar Gmail» cuando Google lo apruebe.
- Los conectores de Claude y ChatGPT pasan a 2.3 y también registran, siempre como borradores.
- Yala web beta en 2.3, y la web completa en 3.0.
- Repartir un recibo con IA en Grupos, en 2.3.
- 2.3 se aligera: iPad, Duo, tutoriales y «Empezar con datos» van a 2.4; manos libres, a 2.5.
- El lenguaje de Android se decide en su fase 0.

**Tablero:**
- Unas 435 cards cambian de versión, y 8 decisiones de pantalla de 2.2 se resuelven y pasan a «lista para lanzar».
- Se cierran el roadmap, momentic.ai, el rediseño de sesiones y el diseño del servidor MCP. «Siri en portugués» se funde
  en L15-5.
- Hay 8 cards nuevas: la ficha con «1 mes gratis» (Lola), la verificación de Google, «Conectar Gmail y Outlook», «Tu IA
  registra en Yala», Yala web beta, el Services ID y el cliente web, y el reparto de recibos con IA.

**Medido por el camino:**
- DMARC sigue en `p=none`.
- Esta Mac tiene Xcode 27.1.
- Un gasto de grupo no guarda foto.
- Ningún formulario de Grupos tiene voz ni foto.
