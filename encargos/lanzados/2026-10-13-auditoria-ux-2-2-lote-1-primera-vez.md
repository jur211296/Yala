# Auditoría UX 2.2 · lote 1: primera vez: bienvenida y onboarding personal

Card: tablero-auditoria-ux-2-2-lote-1-primera-vez-bien-j3b2 (Yala, 2.2, high). Card madre: ogl6 (no la muevas).

## Contexto
Fase 2 de la auditoría UX de 2.2. Brief madre: ~/Claude/tmp-frank/auditoria-ux-flujos-2-2.md (léelo entero: método, cinco lentes, formato de PR). Mapa: docs/ux/mapa-de-flujos-2.2.md en origin/2.2 (PR #481), sección del lote 1. Referencias UI: ~/Claude/referencias-ui/README.md.

Lote 1 (13 flujos): pantalla de carga, elegir idioma, presentación y «Empezar», volver al selector, «Es mi primera vez» con iCloud privado, reabrir Yala a mitad, traer datos o empezar de cero, borrar datos previos, onboarding completo, onboarding «solo gastos», volver atrás o cerrar el onboarding, oferta de prueba Pro al terminar, actualización obligatoria.

Cinco lentes: (1) conoce apps financieras · (2) nunca usó una pero registra gastos · (3) nunca registró y no entiende términos · (4) viene de Excel · (5) quiere lo más fácil y no lee.

## Qué hacer
1. Recorre cada flujo en el simulador y en el código; captura antes.
2. Veredicto por flujo y lente en una tabla del PR: ya está bien / textos / más corto / ayuda / UI.
3. Implementa lo acotado contra 2.2 con capturas antes/después y copy en los 16 idiomas. Tests con -only-testing y /gate.
4. Lo que sea decisión de Jürgen: card propia (Yala, 2.2, frank, espera decisión) con opciones.

## Hecha cuando
Cada flujo del lote 1 tiene veredicto con las cinco lentes en la tabla del PR; lo acotado está implementado en un PR a 2.2 (fetch + rebase sobre origin/2.2) con antes/después y 16 idiomas; las decisiones tienen card.

## Reglas
Base y PR: **2.2**, nunca 2.1. Totalmente autónomo: Jürgen duerme; nunca AskUserQuestion ni preguntas, decide tú. Como máximo 1 simulador; `xcrun simctl shutdown all` al terminar. NINGÚN simulador de 9:00 a 11:00 Lima: en esa franja pausa o salta el trabajo con simulador y sigue con lo demás. Sin deploy. Cierra con /cerrar-total.

## Paso 0 — decisiones

> Resueltas en autónomo (bypass): las recomendaciones se dan por buenas. Se discuten en el PR.

**D1 · Base y PR** → la rama está rebasada sobre `origin/2.2` (43d874cf9, con el mapa del PR #481) y el PR va contra `2.2`.
Por qué: lo pide el encargo. Alternativa descartada: 2.1, prohibida.

**D2 · Qué se implementa y qué va a card** → se implementa copy, orden y arreglos de layout que no cambian qué se pide ni cuántos pasos hay. Quitar o fusionar pantallas, mover la oferta Pro, cambiar la duración de la pantalla de carga o qué pregunta el onboarding va a card de Jürgen con opciones.
Por qué: es el criterio del mapa («lo que cambia el producto va a card»). Alternativa descartada: rediseñar el onboarding entero en esta sesión, que es decisión de producto.

**D3 · Cómo se recorre sin iCloud ni App Attest** → simulador iPhone 17 Pro (iOS 27.0), app Yala Dev instalada limpia y lanzada sin `-uitest` para ver lo que ve una persona nueva; los flujos que el simulador no alcanza (1.6 reabrir, 1.7 iCloud con datos, 1.13 forzar actualización) se juzgan sobre el código y, si hay seam `-uitest-*`, con él.
Por qué: el simulador no tiene cuenta de iCloud ni App Attest. Alternativa descartada: inventar capturas de lo no alcanzado.

**D4 · Tickets abiertos del lote** → no se rehacen; se citan en la tabla. Los de restore y empezar de cero son del lote 6.
Por qué: regla 5 del mapa.

**D5 · Horario del simulador** → todo el trabajo con simulador antes de las 9:00 o después de las 11:00 (Lima); en la franja, código, copy y tests unitarios sin simulador.

**D2 bis · Corrección de Jürgen a mitad de sesión (2026-10-13, ~06:15)** → **no se implementa UX: se propone.** Solo se arreglan bugs claros, cada uno con su card. Entregables: capturas en `~/Claude/entregas/Yala--auditoria-ux-2-2-lote-1-primera-vez/capturas/`, `informe.md` con mejoras numeradas (problema, usuario, captura, A/B/C, recomendada), una card «espera decisión» (jurgen, 2.2) por mejora, y la sección del lote en `~/Claude/propuestas/auditoria-ux-2.2/auditoria-ux-2.2.html`. Sustituye a D2.
Qué se hizo con lo ya implementado: los 12 cambios de copy se revirtieron y sus capturas quedan como maqueta («PROPUESTA») de la opción recomendada. Se quedan cuatro bugs: B1 selector de idioma sin salida, B2 nombre de categoría cortado, B3 «Error de compra» sin compra, B4 «Personalizacao» sin tildes.
