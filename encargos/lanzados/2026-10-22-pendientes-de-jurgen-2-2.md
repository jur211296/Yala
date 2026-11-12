# Sesión paralela viva: acompañar a Jürgen con sus 12 pendientes de 2.2, uno por uno, a su ritmo

## Contexto
Jürgen pidió (22-oct) una sola sesión paralela que quede viva y que él vaya atacando cuando pueda. Corre en paralelo a la cola de sesiones Yala, así que NO usa el simulador ni compila (para no chocar con la sesión de la cola). Las cards están en el tablero (`tablero listar --proyecto Yala --version 2.2 --json`), en backlog, con la nota «Sesión paralela · Pendientes de Jürgen 2.2». Lee `tablero ver <id>` de cada una para el contexto completo.

Los 12 pendientes:
1. Device-QA: unos 27 tickets en tickets/qa esperan un iPhone real (guion qa/guion-tanda.md; faltan los 4 más recientes y el bloque F va siempre al final).
2. DMARC sigue en p=none: la re-comprobación del 15-sep venció.
3. Dos teléfonos que cambian «desde este mes» la misma línea del flujo de caja se pisan: decidir si se arregla o se acepta.
4. El token de gestión de Supabase de la Mini da Invalid access token: rotarlo.
5. Encender Yala IA ampliada en la nube (staging → producción), pasos en docs/ai-cloud-vs-private-2026-10.md §7.
6. Ficha de la App Store: «1 mes gratis» en lugar de «30 días» (lo ve con Lola, lane marketing).
7. Ficha de la App Store: quitar «detección de gastos hormiga» (lo ve con Lola, lane marketing).
8. Comparativa (chips) y Estadísticas (frase con menú) responden lo mismo con dos controles distintos: Jürgen elige uno.
9. Pedir la beta review en App Store Connect para el grupo externo de TestFlight.
10. Publicar la web de invitación (PR #593) en producción.
11. Revisar las Novedades de 2.2 antes de publicarla.
12. Revocar el token de gestión de Supabase «yala-mcp-fase0», o confirmar que ya no existe.

## Qué se pide
- Arranca con un menú corto en español: los 12 pendientes, en una línea cada uno, con lo que le toma a Jürgen (minutos aproximados y si necesita el iPhone, un panel web o solo una decisión). Recomienda por dónde empezar.
- Cuando Jürgen elija uno, prepárale todo para que lo haga rápido: los pasos exactos, los links, y las opciones con una recomendación si es una decisión. Lo que puedas hacer tú sin él (leer código, redactar textos, preparar el guion de QA, revisar DNS con dig, revisar el PR) hazlo antes y déjaselo listo.
- Cuando Jürgen confirme que hizo algo o decida, registra en el tablero: `tablero editar <id> --nota` (la nota reemplaza a la anterior, así que conserva el texto previo debajo) y `tablero mover <id> --a done` cuando quede resuelto, firmando con `--agente frank`. Si una decisión genera trabajo de código, crea una card nueva en «lista para lanzar» versión 2.2 con `--agente frank`, en lugar de hacerlo tú.
- Los 6 y 7 son de la lane marketing de Lola: prepara el resumen para que Jürgen lo vea con Lola; no edites marketing/.

## Qué NO hay que tocar
- Nada de simulador, xcodebuild ni dispositivos reales de Jürgen.
- No hagas commits de código de la app ni toques el uncommitted de ~/Yala (Yala.xcscheme, encargos/pendientes/, archivos .ckdb).
- No imprimas secretos ni tokens. No hagas deploys a producción ni cambies DNS sin la confirmación explícita de Jürgen en esta sesión.
- Nunca escribas «OpenAI» en textos de la app o marketing.
- Todo lo que le escribas a Jürgen va en español neutro latinoamericano.

## Cómo se sabe que está bien
Es una sesión de larga vida: no cierra sola ni corre /cerrar-total. Termina cuando los 12 pendientes estén resueltos o Jürgen la dé por cerrada; entonces deja un resumen de qué quedó hecho, qué se decidió y qué cards nuevas salieron.
