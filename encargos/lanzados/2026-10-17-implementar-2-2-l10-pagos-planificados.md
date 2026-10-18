# Implementar lo ya decidido de la Auditoría UX 2.2 · lote 10 (pagos planificados)

Base y PR: **2.2**. `lanzar-sesion` te deja sobre origin/2.1: antes del primer commit haz `git fetch origin && git switch -C encargo-tmp origin/2.2` (o rebasa tu rama sobre origin/2.2) y comprueba que `git log origin/2.2..HEAD` sale vacío. PR contra 2.2.

## Qué implementar
Las cards de Yala versión 2.2 en **backlog** cuyo título empieza por «UI 2.2 · L10-» o «UX 2.2 · L10-» (y los «Bug 2.2» de esos mismos lotes): `tablero listar --proyecto yala --version 2.2 --estado backlog --json` y filtra. Implementa todas: con la decisión de Jürgen si está escrita en la card (contexto, nota o siguiente paso), y si no, con la opción recomendada (ver abajo).
- Fuente de cada decisión: la card, el informe del lote en ~/Claude/entregas/Yala--auditoria-ux-2-2-lote-*/informe.md, el HTML ~/Claude/propuestas/auditoria-ux-2.2/auditoria-ux-2.2.html y los «Criterios UX/UI permanentes de Jürgen» del brief madre ~/Claude/tmp-frank/auditoria-ux-flujos-2-2.md (léelos: sin degradados, etc.).
- Mueve cada card a in progress al empezar y a done al cerrar (`--agente frank`). Textos nuevos en los 16 idiomas.
- AUTONOMÍA FIN DE SEMANA (Jürgen 16-oct 22:25): Jürgen ya respondió las dudas de estos lotes y no estará en el escritorio. Si al implementar sale una duda (o una card del lote sin decisión explícita), elige TÚ la opción recomendada del informe/HTML (o la que mejor cumpla los Criterios UX/UI permanentes), impleméntala y anótala en la card («Decidido por la sesión: opción recomendada X, porque…») y en el informe. No dejes nada en espera decisión salvo que sea irreversible (borrar datos, esquema de iCloud, cobros): eso sí queda para Jürgen.
- Prueba según /barrido-qa en el simulador. Antes y después en capturas para el cierre.

## Reglas
- Sin esperar el CI de nadie; `git fetch && git rebase origin/2.2` justo antes de abrir tu PR.
- 1 simulador a la vez; apágalo y borra tu DerivedData al terminar. Mira `df -h /` antes de compilar.
- En `~/Yala` (árbol principal) no toques los `.ckdb` sin commitear, `Yala.xcscheme` ni `encargos/pendientes/`. No toques tmux `salud--*`, `sat-lab--*`, `clinicas-dentales-bi--*`.
- Todo ticket nuevo lleva su card.
- Cierra con /cerrar-total.

## Card extra que va en este lote (sale del lote 9)
- «Pagos planificados: el selector de período se cierra al arrastrar la rueda» (backlog, v2.2). En el lote 9 se arregló la misma rueda en presupuestos: ahora es la rueda de iOS y ya no cierra la hoja al arrastrarla. Haz lo mismo en pagos planificados, reutilizando esa solución si se puede. Muévela a in progress al empezar y a done al cerrar.

## Paso 0 (sesión, 2026-10-17)

Modo: autónomo de fin de semana. Base `origin/2.2`, PR contra 2.2. Sin cambios de modelo SwiftData ni de esquema de iCloud.

Decisiones tomadas por la sesión (la card no las cerraba):
- **L10-1**: «Saltados» y «Pausados» van en secciones propias al final (Por pagar · Pagados · Saltados · Pausados). Mezclar un saltado bajo «Pagados» diría algo falso.
- **L10-1 C**: tercera vista «Línea de tiempo» en el mismo selector (Lista · Línea de tiempo · Calendario). Se quita la cabecera «Todos» que repetía la pestaña.
- **L10-2**: los chips «Pagado/Pendiente» dejan de ser filtros: las secciones de L10-1 ya separan lo pagado.
- **L10-4**: se implementa sin enseñar maqueta (Jürgen no está; es reversible). Arriba nombre, monto, subcategoría, cuenta (la última usada) y cuándo (hoy por defecto) con línea resumen; lo demás en «Más opciones». La lista «Próximas fechas» se resume en la línea («Primer pago: … · luego …»).
- **L10-6**: las pestañas Recurrentes/Suscripciones/Todos no se renombran (son tipos de pago, no otro nombre del concepto).
- **L10-7**: «Reanudar» mueve la próxima fecha a la primera desde hoy: lo que cayó en pausa no se cobra.
- **L10-8**: se quita la nota de «fechas estimadas» (contradecía el «Pagado» real).
- **L10-9/L10-11**: «Apuntarlo ahora» y «Pagar ahora» abren el formulario de la Bandeja con título propio, «Guardar» y vuelta al detalle sin «Aprobar siguiente». En un pago compartido no se ofrecen (se aprueba desde la Bandeja con el formulario de grupo).
- **L10-16**: «Tú» una vez en la división de cualquier gasto de grupo (el componente es compartido; «Tú (Tú)» estaba mal en todas).
