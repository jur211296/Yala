# Implementar lo ya decidido de la Auditoría UX 2.2 · lote 9 (presupuestos)

Base y PR: **2.2**. `lanzar-sesion` te deja sobre origin/2.1: antes del primer commit haz `git fetch origin && git switch -C encargo-tmp origin/2.2` (o rebasa tu rama sobre origin/2.2) y comprueba que `git log origin/2.2..HEAD` sale vacío. PR contra 2.2.

## Qué implementar
Las cards de Yala versión 2.2 en **backlog** cuyo título empieza por «UI 2.2 · L9-» o «UX 2.2 · L9-» (y los «Bug 2.2» de esos mismos lotes): `tablero listar --proyecto yala --version 2.2 --estado backlog --json` y filtra. Implementa todas: con la decisión de Jürgen si está escrita en la card (contexto, nota o siguiente paso), y si no, con la opción recomendada (ver abajo).
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

## Paso 0 (Frank, 2026-10-17)

14 cards L9, todas con decisión de Jürgen escrita. Lo que la sesión decide (opción recomendada / criterios permanentes):

- **Cifra común (L9-1, L9-6, L9-10)**: «lo que queda» = límite − gastado; «al día» = lo que queda ÷ días que faltan (hoy incluido), solo en un período en curso con algo por gastar. Una función pura compartida (`BudgetRemainingLogic`) con tests.
- **L9-1 fila**: a la derecha «Te quedan» + importe (o «Te pasaste por» en rosa); bajo el nombre una sola línea gris «S/ 1,408.00 de S/ 1,800.00 · 18 días». Para que no se parta en el iPhone 17 Pro: `ViewThatFits` prueba con decimales y luego sin decimales. «Pasado» → «Cerrado» (cambio de valor de `budgets.period.past`, que también usan el detalle y la tarjeta del Panel).
- **L9-6 detalle**: arriba el período explícito («octubre de 2026», «13 – 19 oct», «2026», o las fechas del único) en lugar de «PEN»; cifra grande = lo que queda; línea gris gastado de límite; bajo la barra «% gastado» y «S/ X al día». Decidido por la sesión: no repito «Te quedan» bajo la barra porque ya es la cifra grande (L9-1 manda alinearlas).
- **L9-2**: tarjeta «¿Qué gastos cuenta?» bajo el monto (rotulado «Límite»), con «Todos mis gastos» relleno por defecto y «Elegir categorías» (abre el selector de siempre, que ya baja a subcategorías). Fila y detalle dicen «Todos tus gastos» sin filtro. Banner de filtros de abajo se queda.
- **L9-3**: línea bajo el selector de tipo; el + abre el editor en el tipo de la pestaña (`initialPeriodType`).
- **L9-4**: botón «Activar alertas» en el aviso del editor (enciende el general y pide permiso a iOS si no se ha pedido; denegado → abre Ajustes de iOS). Detalle: «Alertas apagadas en Notificaciones».
- **L9-5**: la notificación lleva `budgets/<uuid>`; el toque deja el id pendiente en un holder observable y Presupuestos abre ese detalle en su tipo y período actual. Título «Presupuestos». Sin destino nuevo de router (el id viaja aparte; el destino sigue siendo `.budgets`, que ya sabe aplazarse en frío).
- **L9-7**: título por tipo («…cada semana/mes/año frente a tu límite»), barras gris neutro y rosa solo > límite, cifras «3K», sin degradados, etiqueta del límite arriba a la izquierda; el selector de período pasa a ser cabecera de «Gasto del período».
- **L9-8**: mensual = `UIDatePicker` `.yearAndMonth` en rueda; semanal y anual = `Picker` `.wheel` nativo. Sin franjas. El rótulo de mes pasa a plantilla localizada («octubre de 2026»).
- **L9-9**: banner neutro «3 presupuestos activos en el plan gratis» (sin rojo, sin estrella) solo en el límite; hoja: «Con el plan gratis tienes 3 activos. Desactiva uno o pásate a Pro». La estrella de la hoja ya es sólida sin halo desde L4-12: se queda.
- **L9-10**: el fallback «los dos más cerca del límite» ya existe en 2.2 (L3-13); falta el enlace «Elegir cuáles» y la fila con lo que queda + «gastado de límite · %».
- **L9-11**: hueco de la vista previa reservado desde el principio («Marca hasta 3»), réplica del widget mediano con lo gastado real (la vista del widget vive en otro target: réplica con sus tokens).
- **L9-12**: «Mostrar en el widget» en la pulsación larga de la fila y un interruptor en el editor; respeta el tope de 3 de la pantalla de favoritos.
- **L9-13**: «Contar mi parte de los gastos de grupo» + ayuda; solo si hay al menos un grupo visible.
- **L9-14**: «¿Eliminar «Mudanza»?» / «Tus gastos no se borran: solo este límite.» en el editor y en Perfil › Presupuestos.

Asumido: textos en 16 idiomas; nada toca esquema de iCloud ni borra datos.
