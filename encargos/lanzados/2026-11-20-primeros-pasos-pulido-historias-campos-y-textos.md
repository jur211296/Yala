Yala
# Primeros pasos: intros como historias, campos legibles, botones «No deseo crear» y textos nuevos
---
toca: Yala/App/Views/Onboarding/PrimerosPasos/,Yala/App/Views/Planning/AsistentePagoPlanificado/,Yala/App/Views/Shared/AsistenteCreacion/Presupuesto/,Yala/App/Views/Accounts/AsistenteCuenta/,Yala/App/Tips/,Yala/App/DesignSystem/,YalaTests/PrimerosPasosPulido/,tickets/backlog/2026-11-19-primeros-pasos-pulido.md,tickets/done/2026-11-19-primeros-pasos-pulido.md
esfuerzo: high
cierre: cierra-sola
depende: Yala/welcome-carrusel-barras-y-toque-lote,Yala/pago-planificado-logo-propio-foto,Yala/solo-gastos-primeros-pasos-y-panel-progresivo,Yala/temas-repintado-ajustes-y-contraste-lote
---

Rama base: 2.3. Jürgen probó los Primeros pasos en la build 2.3 (5) el 19-nov a las 22:06 y dejó estos ajustes, todos ya decididos. Un PR y un cierre. Parte de lo que dejaron las sesiones de Welcome (barras tipo historia) y de Panel progresivo: reutiliza esos componentes en lugar de duplicarlos.

## Ajustes
1. **Intros como historias de Instagram.** Las intros de cada paso no tienen «Omitir», solo el botón de acción. Tocar la mitad derecha avanza; la izquierda vuelve; mantener el dedo presionado pausa la barra. Usa el mismo comportamiento de las barras del Welcome.
2. **Paso de la cuenta.** El nombre viene precargado según el tipo elegido («Efectivo», «Tarjeta de crédito», etc.) y se puede editar.
3. **Contraste de los campos.** El texto escrito casi no se ve; pasa en todos los campos completables. Arréglalo en el estilo común de campos para toda la app (mínimo WCAG AA 4.5:1 en temas claro y oscuro), no campo por campo.
4. **Cards vecinas del mismo alto.** Si dos cards están lado a lado (por ejemplo «No lo sé» y «Prefiero no decirlo»), tienen el mismo alto aunque una ocupe dos líneas.
5. **Campos con texto y número** (como «Día» con el número del día): alinea el texto y el número, con espacio entre ambos para que no se peguen.
6. **Volver un paso conserva lo llenado.** Lo que el usuario escribió queda lleno y se puede editar; nada se limpia al volver.
7. **«No deseo crear…».** En el primer paso real de presupuesto va «No deseo crear ningún presupuesto», y en el de pago planificado, «No deseo crear ningún pago planificado». Ese botón no va debajo de otro botón.
8. **Pagos planificados, primer paso.** El título pasa a «Elige un pago que hagas cada cierto tiempo» (reemplaza «¿Qué pagas cada cierto tiempo?»). Agrega «También identificaremos automáticamente tus pagos fijos a los 3 meses».
9. **Último paso de presupuesto.** Algo como «Puedes crear hasta X presupuestos gratis y medir tus gastos en lo que quieras, al nivel que quieras», con X igual al límite gratis real del código, y la opción de crear otro ahí mismo.
10. **Último paso de pago planificado.** Algo como «Puedes crear hasta X pagos fijos gratis y recordar los gastos que quieras», con X igual al límite real, y la opción de crear otro ahí mismo.
11. **Coach tip al terminar presupuesto o pago planificado.** Debe apuntar de verdad al «Más» (hoy queda corrido) y, cuando es un solo paso, el botón dice «Entendido», no «Omitir».
12. **Paso 6.** Abre el «Más» automáticamente para mostrar lo que hay, y el mensaje cierra con «Entendido».

Fuera de este encargo, porque van a maqueta para que Jürgen decida: el paso 7, la sheet de los 7 pasos, los coach tips de Ajustes y Pro, y la sheet de prueba de 30 días. No los toques.

Textos en español neutro latinoamericano. Ajusta la redacción final si queda mejor, sin cambiar el sentido, y anótalo.
Card: «Primeros pasos: intros como historias, campos legibles, botones “No deseo crear” y textos nuevos». Tests en `YalaTests/PrimerosPasosPulido/`. El artifact muestra el antes y el después de cada punto, con capturas reales del simulador o del iPhone 14.

## Cómo trabajar
- iPhone 14 (Jürgen, 19-nov): queda conectado a la Mini para cualquier sesión de cualquier máquina vía DeviceMCP. Antes de recurrir al simulador, verifica de verdad si está libre (que responda y que ninguna otra sesión lo esté usando en ese momento); no lo des por ocupado sin comprobarlo. Si lo usas, suéltalo al terminar.
- Textos nuevos en su propia tabla, nunca en Localizable.strings. Nunca un botón debajo de otro.
- En la Max puedes usar un segundo simulador además del de otra sesión, o el iPhone 14 por DeviceMCP; en la Mini, uno solo. No uses `-derivedDataPath /tmp/claude-*`.
- Nada en producción (ni CloudKit ni Supabase).
- Commit y PR sin firma de IA, contra 2.3. Deja el auto merge activado y no cierres hasta ver el PR dentro de 2.3. Si hay conflicto o el CI falla por tu PR, arréglalo tú. Si tras unos 45 minutos el CI sigue rojo por algo ajeno, cierra y anota el motivo.
- Lo menor y reversible se decide con la opción recomendada y se anota. Lo vital, según el modo fijado al arrancar: en semi (05:30–20:00) preguntas y esperas con la sesión viva; en nocturno (20:00–05:30) dejas un checkpoint recuperable y una card «Espera decisión» para Jürgen, sin cerrar como completo, sin mergear ni desplegar lo incompleto.
- Entregable del cierre: artifact visual de Claude (capturas antes y después, comparación de los Primeros pasos), nunca Markdown ni PDF.
- Cierre: `/cerrar-total`, con «Saltado o asumido sin preguntar» y «Decidido sin consultar», cada uno con motivo o «Nada», y el link del artifact.

## Paso 0

Decidido antes de tocar código (modo semi; todo menor y reversible, sin preguntas vitales):

1. **Historias.** El comportamiento va en la pieza común `TutorialStoryPage`, con el reloj y la regla de mitades del
   Welcome (`WelcomeShowcaseLogic.StoryClock` y `tapStep`): toque derecho avanza, izquierdo vuelve, mantener pausa. Fuera
   «Omitir este paso» de las intros de los pasos 2, 3 y 4. El paso 7 hereda los gestos (pieza común) pero conserva su pie:
   está fuera del encargo.
2. **Saltar los pasos 3 y 4.** Sin «Omitir» en la intro, la salida es «No deseo crear ningún…» en la primera pregunta,
   como última respuesta de la lista (no es un botón bajo otro botón: es una respuesta más, como «No, gracias»). Da el
   paso por omitido, igual que antes «Omitir este paso».
3. **Paso 2 (registro).** Su intro pierde «Omitir este paso»; se sale con el «‹» de arriba, como en las otras intros.
4. **Nombre de la cuenta.** Un campo precargado con el nombre del tipo («Efectivo», «Tarjeta de crédito»…), editable, con la
   flecha de enviar. Desaparecen «Sí, ese nombre» / «Otro nombre».
5. **Contraste de campos.** No existe un estilo común de campo: se crea `yalaFieldText()` en `DesignSystem/` (texto en
   `Color.primary` explícito y tinte de cursor del tema) y lo usan todos los campos de Primeros pasos y de los tres
   asistentes. La causa se mide antes de arreglar.
6. **Cards vecinas.** «No lo sé» / «Prefiero no decirlo» y cualquier par de opciones en fila: mismo alto (`maxHeight`
   + `fixedSize` vertical en la fila).
7. **Texto y número.** «Día» y el número (y el símbolo de la moneda y el monto) en la misma línea base y misma letra,
   con `DS.Spacing.sm` entre ambos.
8. **Volver conserva.** Al volver a una pregunta se rellena desde lo ya respondido (cuenta: nombre, saldo, días; pago: día
   «Otro»). Nada se vacía.
9. **Límites.** Presupuestos: 3 gratis (`ProFeature.budgets.freeLimit`), leído del código. **Pagos planificados no tienen
   límite** en el plan gratis: el texto dice «todos los que quieras» en vez de inventar una X. «Crear otro» en el final de
   los dos; en presupuesto solo si el límite lo deja.
10. **Guía tras el paso 3 y 4.** Se mide por qué la flecha no cae en «Más» y se corrige en `TabBarItemLocator`. La tarjeta
    de un solo paso (sin contador) dice «Entendido» y lo cierra, en vez de «Omitir».
11. **Paso 6.** Abre «Más» solo y enseña directamente la tarjeta de Estadísticas con «Entendido».
12. **Textos nuevos** en su propia tabla (`PrimerosPasosPulido.strings`), 16 idiomas.
