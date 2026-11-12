# Proponer un roadmap real de Yala por versión (2.3, 2.4, 2.5, 3.0, 4.0…) con hitos, metas de bugs y criterios para asignar versión

## Contexto
Jürgen lanza 2.1 mañana (20-oct-2026). En el kanban del centro de mando hay muchísimas cards de Yala en 2.2 y muchísimas sin versión. Quiere un roadmap real y criterios claros para usar cuando lleguen ideas nuevas. Posicionamiento ya decidido: Yala no se vende como «la app privada». La estrategia es igualar funciones de competidores peruanos como Pablo (usapablo.com), por ejemplo la lectura automática del correo (ya tiene card en 2.2) y algún día un bot de WhatsApp, y después hacerlas mejor (mejor interfaz, quizá una mascota). La masa de usuarios llegará por Android o web, en la nube. Jürgen prefiere siempre lo más robusto y la mejor práctica.

## Qué se pide
SOLO planificación. No se toca código de la app ni el simulador.
1. Lee todas las cards abiertas de Yala con `tablero listar --proyecto Yala --json` (backlog, lista para lanzar, espera decisión, en curso, blocked, in qa), más STATE.md, DECISIONS.md (índice) y docs/TICKETS.md si existe. No leas el repo entero.
2. Agrupa las cards en temas y propón versiones: 2.2 (la que ya está en marcha: revisa si sobra o falta algo), 2.3, 2.4, 2.5, 3.0, 4.0 y las que hagan falta. Cada versión lleva un objetivo en una frase, los hitos, las cards que entran (por título), una meta de bugs (cuántos se atacan como mínimo y qué severidad tiene que quedar en cero) y su criterio de salida.
3. Escribe criterios de asignación de versión que se puedan seguir después: qué hace que algo sea parche, menor o mayor (3.0, 4.0), cómo pesan los bugs según su severidad, cómo pesan la paridad con la competencia, la plataforma (Android, web) y la deuda técnica, y un árbol de decisión corto para cuando llegue una idea nueva.
4. Señala las cards duplicadas, obsoletas o que necesitan decisión, sin moverlas.
Entregable: `docs/ROADMAP.md` y `docs/criterios-de-version.md`, en español neutro latinoamericano, más una tabla `docs/roadmap-asignacion.tsv` (titulo, version actual, version propuesta, motivo). El PR va contra 2.2.

## Qué NO hay que tocar
No muevas, edites ni crees cards: la asignación es una propuesta y la decide Jürgen. No toques código, Cloudkit Schemas, Yala.xcscheme ni encargos/pendientes/. No uses simuladores ni dispositivos (hay un QA guiado de 2.1 en curso en los iPhones y el iPad de Jürgen). No toques marketing/ ni Web/. En los documentos no pongas ids de card, solo títulos. No escribas «OpenAI» en textos de la app.

## Cómo se sabe que está bien
Cada card abierta de Yala aparece en la tabla con una versión propuesta. Cada versión tiene objetivo, hitos, meta de bugs y criterio de salida. Los criterios permiten asignar una idea nueva sin preguntar. El PR está abierto contra 2.2 (fetch y rebase justo antes de abrirlo, sin esperar CI). Después /cerrar-total.

## Paso 0 — decisiones

> Resueltas en autónomo (bypass): las recomendaciones se dan por buenas. Se discuten en el PR.

**D1 · ¿Contra qué rama va el PR?** → `2.2`, como dice el encargo.
Por qué: el encargo lo pide explícito. Alternativa descartada: commit directo a `2.1` por ser solo `docs/` (lo permite `CLAUDE.md`), porque el encargo manda.

**D2 · ¿Qué versiones hay?** → 2.1 · 2.1.1 (parche) · 2.2 · 2.3 · 2.4 · 2.5 · 3.0 (web) · 3.1 (plan dúo) · 3.2 (Watch) · 4.0 (Android).
Por qué: 2.1.1 recoge lo que salió del QA guiado del build 18; cada menor tiene un tema; cada mayor abre una plataforma o cambia el dueño de los datos. Alternativa descartada: meter los bugs del QA guiado en 2.2, que ya va llena.

**D3 · ¿Cómo se mide la severidad de un bug?** → Con la prioridad de la card (muy alta · alta · media · baja · muy baja), que ya usa la escala de `docs/TICKETS.md`.
Por qué: es un dato que ya existe en las 673 cards; inventar otra escala obligaría a re-triar todo. Alternativa descartada: severidad nueva por card, sin datos para hacerlo bien.

**D4 · ¿Fechas?** → No. Orden y cadencia sugerida, sin calendario.
Por qué: no hay datos de velocidad que respalden fechas; inventarlas sería estado inventado.

**D5 · ¿Qué versión lleva una card interna (tests, CI, docs)?** → La versión en la que conviene hacerla, con el motivo «interno».
Por qué: el criterio de aceptación pide versión para todas. Alternativa descartada: una columna «mantenimiento» que no es versión.

**D6 · ¿Se proponen movimientos dentro de 2.2?** → Sí: salen de 2.2 el correo del banco (a 2.3), cuotas, ahorros, deudas, mes financiero, hero y notificaciones (a 2.4) y el conector de Claude (a 2.5). Se queda la tarjeta de crédito con corte.
Por qué: 2.2 tiene 244 cards y es una versión de UX; la tarjeta de crédito comparte cambio de esquema con la tarjeta multidivisa. Queda como propuesta: decide Jürgen.

**D7 · Fuentes de competencia** → usapablo.com y goclever.app leídos hoy (19-oct-2026), más lo que traen las cards. Lo que no está en esas fuentes se marca como no verificado.
