# Auditoría UX 2.2 · lote 2: apuntar un movimiento a mano

Card: tablero-auditoria-ux-2-2-lote-2-apuntar-un-movim-likq (Yala, 2.2, high). Card madre ogl6: no la muevas.
Lote 2 del mapa (docs/ux/mapa-de-flujos-2.2.md en origin/2.2), 12 flujos: gasto, ingreso, transferencia, fecha, nota con atajos @ ! #, categoría y necesidad, etiquetas, otra divisa, calcular mi parte, guardar y usar favoritos, hacerlo recurrente.
Numera las mejoras L2-1, L2-2… y agrega la sección del lote 2 al HTML acumulado sin borrar el lote 1. Sesión de entregas: ~/Claude/entregas/Yala--auditoria-ux-2-2-lote-2-apuntar-a-mano/.

## Reglas
Base y PR: **2.2**. Totalmente autónomo: Jürgen duerme; nunca AskUserQuestion ni preguntas, decide tú. Como máximo 1 simulador; `xcrun simctl shutdown all` al terminar. NINGÚN simulador de 9:00 a 11:00 Lima: a las 9:00 apágalo, sigue con código/informe/HTML, y retoma el simulador después de las 11:00. Sin deploy. Cierra con /cerrar-total.

## Paso 0 — decisiones

> Resueltas en autónomo (bypass, Jürgen duerme): las recomendaciones se dan por buenas. Se discuten en el PR.

**D1 · Base y PR** → la rama nacía de `origin/2.1` con tres commits ajenos de marketing; se reinició sobre `origin/2.2` (7000aef89, con el lote 1 mergeado) antes de tocar nada. PR contra `2.2`.
Por qué: lo pide el encargo y esos tres commits no son de esta sesión. Alternativa descartada: arrastrarlos al PR.

**D2 · Qué se implementa** → nada de UX: se propone (corrección de Jürgen del lote 1, 06:19). Solo se arreglan bugs claros, cada uno con su card. Cada mejora va a `informe.md`, al HTML acumulado y a una card «espera decisión» (jurgen, 2.2) con A/B/C.
Por qué: manda el formato del informe sobre el «implementa lo acotado» del brief madre.

**D3 · Cómo se recorre** → simulador iPhone 17 Pro (iOS 27.0), Yala Dev. Dos montajes: `-uitest-seed sin-registros` (solo cuentas y categorías, como alguien recién llegado) y `-uitest-seed realista` (etiquetas, divisas, pagos planificados). Tras sembrar, se relanza sin `-uitest` para ver banners de guía y tips, que los XCUITest ocultan.
Por qué: el formulario es el mismo para todos, pero lo que ve alguien nuevo depende de datos y guías. Alternativa descartada: onboarding a mano por cada montaje (ya auditado en el lote 1).

**D4 · Tickets abiertos y cards de 2.2** → no se rehacen; se citan en la tabla. La divisa del importe la rediseña «Tarjeta con varias divisas, entrega 3»: lo de otra divisa se propone sin rehacer esa card.

**D5 · Horario del simulador** → todo el simulador antes de las 9:00 o después de las 11:00 (Lima); en la franja, código, informe, HTML y cards.

**D6 · Ampliación de Jürgen a media sesión (2026-10-13, ~07:48 y ~08:05 Lima)** → además de UX, auditoría UI del lote: (a) montos y calculadoras clarísimos para cualquier perfil; (b) que la persona entienda cada paso con microcopy, ejemplos y ayuda contextual, **sin pasos adicionales y sin sentirse nunca perdida**; (c) el glass se queda, pero todo con glass no da foco a nada: jerarquizar con contraste, rellenos (lo elegido va relleno de color, no solo con contorno), acentos, efectos; (d) colores, efectos, transiciones y animaciones para que nada aburra. **Adaptar la app, no transformarla.** Referencia principal: `~/Claude/referencias-ui/kargul-2026-10-07/`. Cada propuesta lleva captura antes, maqueta después (renderizada en el simulador con un parche que no se commitea), A/B/C con recomendación y card en espera de decisión.
Alcance: **solo lo del lote 2** (Jürgen: «si tu lote no tiene calculadoras, no es tuyo»). Dentro: «Calcular mi parte», los montos del formulario y el tipo de cambio de la transferencia. Fuera: calculadoras del onboarding y del formulario de cuenta (lotes 1 y 7), y el «Registra tu primer gasto» marcado por el saldo inicial (lote 5: va a card, no se arregla aquí).

**D7 · Simulador de 9:00 a 11:00** → hoy se puede usar (Lola no lo usa), siempre uno y apagado al terminar. Sustituye a D5 solo por hoy.

---
# Brief madre (método, formato de informe y HTML acumulado)
---
esfuerzo: high
---
# Auditoría de UX por flujos para 2.2 — Fase 1: mapa de todos los flujos y lotes

**Card:** `tablero-auditoria-de-ux-por-flujos-para-2-2-mapa-ogl6` (Yala 2.2, prioridad very-high). Pedido de Jürgen (12-oct 06:24): es lo PRIMERO que se trabaja en 2.2. 2.2 se centra en UX más funcionalidades nuevas (Siri con IA, el conector MCP, etc.). Se lanza cuando 2.1 esté fuera.

## Fase 1 (esta sesión): el mapa
1. Identificar **TODOS** los flujos que puede vivir un usuario en la app, incluso los pequeños. Ejemplos mínimos: crear cuenta, editar cuenta, entrar a cuentas desde Ajustes, crear un registro, crear un registro con voz, crear un registro con imagen (y compartir fotos/PDF), onboarding completo, onboarding solo gastos, los pasos de la primera vez en Yala, los tips en pantalla que sombrean el resto, presupuestos, pagos planificados, Bandeja, grupos (crear, invitar, unirse, liquidar), Estadísticas/Tendencias, Yala IA/chat, widgets, Siri/Centro de Control, notificaciones, nube/iCloud (activar, cerrar sesión, restaurar), Yala Pro/compras, Ajustes (divisa, idioma, exportar, borrar), iPad (soltar archivos, multiventana).
2. Fuentes: navegación del código (vistas, coordinadores, `docs/entry-points.md`), `docs/glosario.md` con grep, tickets y XCUITests existentes. No leas el repo entero: recorre las pantallas desde los puntos de entrada.
3. Entregable: `docs/ux/mapa-de-flujos-2.2.md` con cada flujo (nombre en lenguaje de usuario, punto de entrada, pantallas que recorre, ficheros principales, si tiene XCUITest) y su **lote**. Los flujos muy chicos se juntan en un mismo lote; cada lote debe caber en una sesión.
4. Crear **una card de 2.2 por lote**: `tablero crear --proyecto Yala --titulo "Auditoría UX 2.2 · lote N: <flujos>" --version 2.2 --prioridad high --asignado frank --estado backlog --contexto "<flujos del lote>" --hecha-cuando "<criterio de fase 2>" --enlace "Mapa|<url del doc en 2.2>" --agente frank` (sin --fecha). Lista las cards en el cierre, en el orden recomendado (lo más usado y lo de la primera vez primero).
5. No cambies código de producto en esta fase.

## Fase 2 (una sesión por lote, se lanza después): qué tiene que hacer cada lote
Revisar cada flujo del lote con **cinco lentes de usuario**:
1. Conoce apps financieras.
2. Nunca bajó una app financiera, pero sabe registrar sus gastos.
3. Nunca registró sus gastos y probablemente no entiende ciertos términos.
4. Viene de Excel.
5. Quiere lo más fácil posible: no va a leer toda la pantalla ni seguir cincuenta pasos.
Para cada flujo, decidir si ya es amigable para cualquier usuario o si necesita: mejores textos, un proceso más corto, botones o textos de ayuda, o una UI actualizada (puede haber quedado desfasada con los cambios recientes). Implementar lo acotado, con **capturas antes/después** (`capturas/antes-*.png`, `capturas/despues-*.png`) siguiendo `~/Claude/referencias-ui/README.md`, y crear card para lo que necesite decisión de Jürgen. Deja esta sección copiada en el documento del mapa para que cada sesión de lote la lea.

## Reglas
- Arranca sobre `origin/2.2` si existe (si no, sobre `origin/2.1` y dilo). PR contra esa rama.
- Textos en español neutro; los 16 idiomas solo si cambias copy (fase 2).
- Si usas simulador para capturas del mapa: `nice -n 10 xcodebuild -jobs 2`, load < 8, pipeline serial y un solo simulador, apagado y borrado al terminar. DerivedData de la sesión y cachés de XcodeBuildMCP retiradas al cerrar sin preguntar.

## Cómo se sabe que está bien
`docs/ux/mapa-de-flujos-2.2.md` con todos los flujos y sus lotes; una card de 2.2 por lote en el tablero; PR abierto. Al terminar, `/cerrar-total` (Mini limpia).


## Formato del informe por lote (Jürgen, 2026-10-13 06:19 Lima; manda sobre lo anterior)
Formato del informe que pide Jürgen para cada lote: (1) capturas de cada pantalla del flujo, sacadas en el simulador y guardadas en ~/Claude/entregas/<sesión>/capturas/ con nombres claros; si aplica, un boceto o mock de la propuesta. (2) Un informe en español en entregas/<sesión>/informe.md con las mejoras numeradas; para cada una: problema, tipo de usuario afectado, captura, opciones A/B/C y cuál recomiendas. (3) No implementes cambios de UX; solo propone. Arregla únicamente bugs claros, y cada uno en su propia card. (4) Crea una card en espera decisión (assignee jurgen, versión 2.2) por cada mejora de UI, con sus opciones. Sigue en 2.2 y no uses el simulador de 9:00 a 11:00 Lima.


## HTML acumulado (Jürgen, 2026-10-13 06:21 Lima)
Además del informe.md: crea o actualiza el HTML acumulado ~/Claude/propuestas/auditoria-ux-2.2/auditoria-ux-2.2.html. Debe ser autocontenido y tener una sección por lote con un índice arriba. Cada mejora lleva su número (L1-1, L1-2…), el problema, el tipo de usuario, las capturas (con la imagen en base64 o copiada en ~/Claude/propuestas/auditoria-ux-2.2/img/), las opciones A/B/C y tu recomendación. Tiene que verse bien en el móvil. Agrega tu lote sin borrar los anteriores.
