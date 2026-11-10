# Lote · Texto al máximo: cifras cortadas y zona fija de Guardar
toca: NewTransactionView, GroupExpenseFormView, OnboardingView, Tendencias, Bandeja/voz, Resumen, pago planificado

Rama base: origin/2.2 en jur211296/Yala. Un solo PR contra 2.2, un solo cierre. Máquina: la libre (Mini o Max). Usa simulador (pipeline serial, sim-lock). Cierre autónomo.

## Contexto
Dos cards en «lista para lanzar», prioridad alta, versión 2.2, halladas en el barrido final (PR #813):
1. «Con el texto al máximo, cifras cortadas o partidas: saldo de Tendencias, borrador de voz, fichas de Resumen y botones del pago» (tablero-con-el-texto-al-maximo-cifras-cortadas-o-vd5r).
2. «Con el texto al máximo, la zona fija de «Guardar» pisa el formulario: Nuevo registro, Nuevo gasto de Grupos y el onboarding» (tablero-con-el-texto-al-maximo-la-zona-fija-de-g-3nos).

## Qué se pide
1. Cifras: a AX5 en iPhone 17e las cuatro cifras se leen enteras y los dos botones del pago caben; capturas antes/después a AX5 y diff de píxeles a tamaño normal.
2. Zona fija de Guardar: aplicar safeAreaBar (o equivalente) en NewTransactionView (SaveAreaPlacement), GroupExpenseFormView y OnboardingView; capturas antes/después a tamaño normal y a AX5 en 17e y 17 Pro.
3. `tablero`: en curso al empezar; in qa al cerrar con guion corto.
4. Si falta una decisión de producto que cambie el resultado: `preguntar-bot` (no asumas).

## Qué NO hay que tocar
Marketing/, despliegues a producción, la cola de TestFlight.

## Hecha cuando
- Las dos cards cumplen su hechaCuando.
- Gate en verde; capturas en capturas/ del worktree.
- Termina con /cerrar-total.

## Paso 0 — decisiones

> Resueltas en autónomo (bypass): las recomendaciones se dan por buenas. Se discuten en el PR.

**D1 · ¿Qué pieza para la zona fija de Guardar?** → `safeAreaBar(edge: .bottom)` en lugar de `safeAreaInset` en las tres pantallas (Nuevo registro, Nuevo gasto de Grupos, onboarding).
Por qué: es la propuesta de la card y el molde que ya usa `YalaStepGuide`; da el difuminado nativo del borde del scroll. Alternativa descartada: pintar un fondo opaco detrás de los botones (tapa en seco y cambia el aspecto también a tamaño normal).

**D2 · ¿Se revisan los otros 18 `safeAreaInset(edge: .bottom)`?** → No en este PR; se cuentan y se deja la lista en el ticket.
Por qué: el encargo nombra tres pantallas y la regla de la casa es alcance mínimo; cada una necesita su captura a AX5. Alternativa descartada: migrar los 21 a ciegas.

**D3 · Botones del pago planificado** → con el mes en curso, la misma `ViewThatFits` (fila; si no cabe, uno debajo del otro) que ya usan los otros dos casos.
Por qué: a tamaño normal la fila cabe y no cambia nada; reutiliza el molde de la misma vista. Alternativa descartada: apilar por `isAccessibilitySize` (dos formas distintas para un mismo texto según el contenido).

**D4 · Fichas de Resumen** → con texto de accesibilidad, una columna en vez de dos y el importe sin cortar.
Por qué: a AX5 media pantalla no da para «Subcategoría principal» ni para el importe; a tamaño normal la rejilla sigue igual.

**D5 · Borrador de voz y Tendencias del Panel** → con texto de accesibilidad, el importe baja a su propia línea (molde `AdaptiveRowStack`, inline donde el `Spacer` difiere) en vez de partirse o llevar elipsis.
Por qué: regla de la casa «una cifra no se corta». A tamaño normal, el mismo `HStack` de siempre.

**D6 · Lista de Pagos planificados en el iPad (punto 4 del ticket, fuera del hechaCuando)** → entra si la causa es la misma fila concepto-importe; si no, se apunta en «Encontrado».

**D7 · Evidencia** → conductor XCUITest temporal (no se commitea), «antes» con la build de la base y «después» con la del PR, en 17e y 17 Pro, oscuro, normal y AX5; diff de píxeles a tamaño normal.

**D8 · Tono del botón desactivado dentro de la barra (decidido por Jürgen en la sesión, 2026-11-05)** → se mantiene `safeAreaBar` y, a tamaño normal, el texto del «Guardar»/«Siguiente» desactivado conserva el gris de antes (164-165); con texto grande, el del sistema.
Cómo: iOS lo atenúa aunque la etiqueta se marque habilitada (medido 101), así que `YalaPrimaryButton(keepsDisabledToneInBar:)` lo pinta encima del botón al 50 %.
