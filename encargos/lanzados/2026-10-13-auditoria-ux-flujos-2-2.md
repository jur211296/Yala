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


## Reglas de esta sesión (2026-10-13)
Base y destino: la rama **2.2** (recién creada desde 2.1). Todo PR va contra 2.2, no contra 2.1. Totalmente autónomo: Jürgen duerme; nunca AskUserQuestion ni preguntas, decide tú. Como máximo 1 simulador; `xcrun simctl shutdown all` al terminar. NINGÚN simulador de 9:00 a 11:00 Lima: en esa franja pausa o salta el trabajo con simulador y sigue con lo demás. Cierra con /cerrar-total.

## Paso 0

Decisiones tomadas por Frank el 2026-10-13 (sesión autónoma, sin nadie delante):

1. **Base.** `origin/2.2` existe y apunta al mismo commit que `origin/2.1` (`e7e9feda8`). Rama `encargo/2026-10-13-auditoria-ux-flujos-2-2` sobre ella; PR contra `2.2`.
2. **Entrega por PR aunque el diff sea solo `docs/`.** El `CLAUDE.md` deja ir directo a la rama principal los diffs sin compilar, pero el encargo pide PR contra `2.2` y manda el encargo. Gate: solo la validación del índice (no hay nada que compilar).
3. **Sin simulador en fase 1.** El mapa sale del código, `docs/entry-points.md`, el glosario, los tickets y los XCUITest. Las capturas son trabajo de fase 2, por lote. Así tampoco choca con la franja 9:00–11:00.
4. **Qué cuenta como flujo:** algo que una persona hace con una intención propia y termina (o abandona). Las pantallas sueltas que solo se leen entran como flujo de «consultar X». Los avisos que la app saca sola entran agrupados por familia.
5. **Lotes:** por afinidad de pantallas (una sesión de fase 2 abre un solo simulador y recorre una zona de la app), de 3 a 8 flujos cada uno, y ordenados por uso y por primera vez.
6. **Ideas de 2.2 ya en el tablero** (deudas, ahorros con metas, cuotas, hero personalizable, tarjeta multidivisa, Siri con IA, MCP): no son flujos que existan hoy. Se citan en el lote al que tocarán, para que la revisión no rehaga algo que esas cards van a cambiar.
7. **Enlace de las cards:** `https://github.com/jur211296/Yala/blob/2.2/docs/ux/mapa-de-flujos-2.2.md`, que vale en cuanto el PR entre en `2.2`.
8. **Card madre** (`…-mapa-ogl6`): se queda en curso con el enlace al mapa y al PR, porque su «hecha cuando» incluye la fase 2 entera.
