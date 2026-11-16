# Formularios guiados · inventario y recomendación

Medido leyendo el código de `2.3` el 2026-11-15 (base `d2cd2e75b`). La maqueta interactiva es `index.html` en esta carpeta; este fichero es su versión en texto.

## Recomendación

| # | Flujo | Valor | Esfuerzo | Hoy |
|---|---|---|---|---|
| 1 | Crear una cuenta | alto | bajo | 16 campos al crear (11 a la vista) |
| 2 | Crear un pago planificado | alto | medio | ≈25 campos, 8 escondidos en «Más opciones» |
| 3 | Crear un presupuesto | alto | bajo | 13 campos + 4 filtros |
| 4 | Crear un grupo | alto | medio | 7 campos, 4 escondidos en «Más opciones» |
| 5 | Crear un favorito | medio | bajo | 8 campos (10 en transferencia) |
| 6 | Anotar una deuda de antes (saldo inicial) | medio | bajo | 5 campos |
| 7 | Crear una categoría | medio | bajo | 4 campos + 4 por cada subcategoría, en dos pantallas |

Criterio: guiado para CREAR lo que se hace pocas veces y tiene jerga; formulario para lo diario y lo que ya viene relleno; editar siempre abre el formulario. Las preguntas de cada flujo están escritas como datos (texto, tipo de respuesta, por defecto, cuándo se salta, qué campo llena) para que las lea el mismo motor que hará Yala IA para presupuestos y pagos recurrentes.

## Inventario

### Crear o editar cuenta — Convertir

- Fichero: `Yala/App/Views/Accounts/AccountFormView.swift`
- Desde: Ajustes › Cuentas, Panel, selector de cuenta
- Campos: 16 al crear (11 a la vista); edición añade ajuste de saldo, líneas en otra divisa y archivar
- Obligatorios: Nombre (sin repetir), tipo, moneda, saldo inicial; en tarjeta, día de pago
- Qué confunde: «Signo» con «A favor / Consumido» en tarjeta, sin explicación; El mismo dato se llama «Saldo inicial», «Nuevo saldo», «Saldo actual» y «Saldo»; La moneda arranca siempre en soles (PEN), no en tu moneda principal; «Guardar» se apaga sin decir por qué si el nombre está repetido; En tarjeta, seis bloques antes de «Más opciones»; la otra divisa se ofrece en otra pantalla después de guardar

### Crear o editar pago planificado — Convertir

- Fichero: `Yala/App/Views/Planning/ScheduledPaymentEditorView.swift`
- Desde: Planificación › Pagos, «Más opciones…» de Hacer recurrente
- Campos: ≈25 campos; 8 escondidos en «Más opciones»
- Obligatorios: Nombre, monto, categoría, cuenta, cuándo (fecha o recurrencia)
- Qué confunde: «Fecha de pago» y «Fecha de inicio» son el mismo control con dos nombres; «Notificar días antes» enseña números sin unidad; «Descripción del gasto» es la nota, no el nombre; «Tiene fecha de fin» pone un año sin decirlo; En compartido el monto pasa a ser «Total de la factura» y la cuenta pasa a opcional

### Crear o editar presupuesto — Convertir

- Fichero: `Yala/App/Views/Planning/BudgetEditorView.swift`
- Desde: Planificación › Presupuestos
- Campos: 13 campos + 4 filtros
- Obligatorios: Nombre, límite, período; fechas si es «Único»
- Qué confunde: Pide el nombre antes de saber qué cuenta; «¿Qué gastos cuenta?» y «Subcategorías» en Filtros aplican el mismo criterio; Dos controles de aviso que dicen casi lo mismo; La moneda no se elige: cambia sola si eliges una sola cuenta; «X» cierra sin preguntar aunque haya cambios

### Crear o editar grupo — Convertir

- Fichero: `Yala/App/Views/Groups/GroupFormView.swift`
- Desde: Grupos › Nuevo grupo, bienvenida
- Campos: 7 campos; 4 en «Más opciones»
- Obligatorios: Nombre; tu nombre en el primer grupo
- Qué confunde: La moneda del grupo no se ve hasta encender «una sola moneda»; «Menos pagos… transferencias» suena a banco; Icono y color sin etiqueta; Las tres decisiones que cambian cómo se reparte viven plegadas

### Crear o editar favorito — Convertir

- Fichero: `Yala/App/Views/Favorites/FavoriteEditorView.swift`
- Desde: Favoritos › Nuevo
- Campos: 8 campos (10 en transferencia)
- Obligatorios: Nombre
- Qué confunde: Nombre y descripción son dos textos centrados iguales; Monto vacío se ve como «0.00» y quiere decir «sin monto»; Los chips vacíos enseñan el nombre del campo; La necesidad solo aparece tras elegir categoría

### Saldo inicial de un miembro — Convertir

- Fichero: `Yala/App/Views/Groups/GroupOpeningBalanceFormView.swift`
- Desde: Detalle del grupo, al aprobar a alguien
- Campos: 5 campos
- Obligatorios: Todos
- Qué confunde: «Saldo inicial» no dice que es una deuda de antes; El sentido de la deuda depende de dos filas; «Reemplazar» cambia uno anterior

### Crear o editar categoría y subcategoría — Convertir

- Fichero: `Yala/App/Views/Categories/CategoryDetailView.swift · SubcategoryDetailView.swift`
- Desde: Ajustes › Categorías
- Campos: 4 campos + 4 por subcategoría, en pantallas empujadas
- Obligatorios: Nombre y al menos una subcategoría
- Qué confunde: «Al menos una subcategoría» solo se dice al tocar «Guardar»; Cada subcategoría es otra pantalla; La necesidad se elige subcategoría por subcategoría; No se puede crear una categoría de ingreso

### Nuevo registro (gasto, ingreso, transferencia) — Se queda

- Fichero: `Yala/App/Views/Transactions/NewTransactionView.swift`
- Desde: Botón «+», Registros, Estadísticas, voz e imagen
- Campos: 10 a la vista (gasto) · cuenta pasa a origen y destino en transferencia
- Obligatorios: Monto, cuenta y categoría; origen y destino distintos en transferencia
- Qué confunde: «Categoría» es la subcategoría; Descripción y monto sin rótulo; «Mi parte» cambia el monto por tu parte; Atajos ! # @ solo los explica una pista que se apaga
- Por qué: Se usa varias veces al día y ya es una sola pantalla con la pregunta del monto. Un guiado lo haría más lento. Lo que sí ayuda ya existe: el tutorial de registro, los favoritos, la voz y la foto.

### Editar registro — Se queda

- Fichero: `Yala/App/Views/Records/TransactionDetailSheet.swift → NewTransactionView`
- Desde: Detalle del registro › Editar
- Campos: El mismo formulario
- Obligatorios: Los del registro
- Qué confunde: En gastos de grupo, una parte queda bloqueada
- Por qué: Editar es corregir un dato concreto: el formulario lo deja a la vista. Regla para todos: el guiado es para crear; editar abre el formulario.

### Gasto de grupo — Más adelante

- Fichero: `Yala/App/Views/Groups/GroupExpenseFormView.swift`
- Desde: Detalle del grupo, composer, Bandeja
- Campos: 10 campos
- Obligatorios: Descripción, moneda, monto, quién pagó, reparto; cuenta si pagas tú con reflejo
- Qué confunde: «Pagado por [ti] y dividido [en partes iguales]» son botones dentro de una frase; El mismo modo con dos nombres («Iguales» / «Partes iguales»); Un campo vacío en porcentaje o monto deja fuera a la persona sin decirlo; Una categoría de ingreso lo vuelve venta sin aviso
- Por qué: Es frecuente y ya va casi todo a un toque. Antes que un guiado conviene pulir sus confusiones en el formulario. El reparto sí podría ser un mini guiado al abrirlo («¿Quién pagó?» → «¿Cómo lo dividen?»).

### Saldar una deuda (liquidación) — Se queda

- Fichero: `Yala/App/Views/Groups/SettlementFormView.swift`
- Desde: Saldos › Saldar
- Campos: 6 campos
- Obligatorios: Monto
- Qué confunde: La fecha vive bajo el título «Nota»; «Saldar» suena a «saldo»; «≈» sin explicar
- Por qué: Llega con todo relleno desde la deuda: es un toque. Basta sacar la fecha de la caja «Nota».

### Presupuesto del grupo — Se queda

- Fichero: `Yala/App/Views/Groups/GroupBudgetSheet.swift`
- Desde: Ajustes del grupo
- Campos: 1 campo
- Obligatorios: Monto
- Qué confunde: «Tope» y «presupuesto» a la vez
- Por qué: Ya es una sola pregunta con su vista previa.

### Reflejar en tus cuentas (puente) — Se queda

- Fichero: `Yala/App/Views/Groups/BridgeActivationSheet.swift`
- Desde: Ajustes de Grupos o del grupo
- Campos: 1 decisión
- Obligatorios: —
- Qué confunde: «Importar todo el historial» crea borradores en la Bandeja y no lo dice
- Por qué: Es una decisión, no un formulario. Solo falta decir dónde llega el historial.

### «Tu parte» y «Mi parte» (calculadoras) — Se queda

- Fichero: `Yala/App/Views/Groups/SplitLines/ · Shared/SplitCalculatorSheet.swift`
- Desde: Éxito de un gasto de grupo, registro
- Campos: 3-4 por línea
- Obligatorios: Monto y categoría o cuenta
- Qué confunde: «Guardar línea» se apaga sin decir por qué; «Cuadra / Faltan / Sobran» sin decir de qué
- Por qué: Son calculadoras: se entienden mejor viendo todo a la vez.

### Crear o editar etiqueta — Se queda

- Fichero: `Yala/App/Views/Tags/TagFormView.swift`
- Desde: Ajustes › Etiquetas (y al vuelo en el registro)
- Campos: 4 campos
- Obligatorios: Nombre (1-20, sin repetir)
- Qué confunde: Nombre repetido apaga «Guardar» sin mensaje; «Activas» no dice qué pasa al apagarla
- Por qué: Nombre y color: ya es corto. Además casi todas se crean al vuelo desde el registro, con icono y color automáticos.

### Recordatorio personalizado — Se queda

- Fichero: `Yala/App/Views/Settings/NotificationEditorSheet.swift`
- Desde: Ajustes › Notificaciones › Añadir
- Campos: 5 campos
- Obligatorios: Nombre y mensaje
- Qué confunde: El nombre vive bajo el título «Mensaje»; «¿Qué días?» vacío quiere decir todos
- Por qué: Lo usa poca gente y son cinco campos a la vista.

### Línea del flujo de caja — Se queda

- Fichero: `Yala/App/Views/Reports/CashFlow/CashFlowAddLineSheet.swift`
- Desde: Reportes › Flujo de caja
- Campos: Tipo + 3 caminos de 2-4 campos
- Obligatorios: Nombre y origen
- Qué confunde: La línea personalizada acepta monto 0 o texto que no es número
- Por qué: Ya es un pequeño guiado (tipo → camino → datos).

### Hacer recurrente (desde un registro) — Se queda

- Fichero: `Yala/App/Views/Transactions/RecurringQuickSheet.swift · PagosRecurrentes/`
- Desde: Registro, detalle, Bandeja
- Campos: 0-1 (elige una fila)
- Obligatorios: —
- Qué confunde: —
- Por qué: Ya es un toque. Su «Más opciones…» abrirá el guiado de pago con lo del registro respondido.

### Propuesta de pago que se repite — Se queda

- Fichero: `Yala/App/Views/PagosRecurrentes/RecurringProposalSheet.swift`
- Desde: Tarjeta «Pagos que se repiten»
- Campos: 6 (casi todo detectado)
- Obligatorios: Monto y cuenta
- Qué confunde: «No es fijo» y «Ahora no» no dicen cuál es para siempre
- Por qué: Es la confirmación de algo que Yala detectó.

### Guardar como favorito — Se queda

- Fichero: `Yala/App/Views/Transactions/SaveAsFavoriteSheet.swift`
- Desde: Registro › Favorito
- Campos: 1 + detalles ya rellenos
- Obligatorios: Nombre
- Qué confunde: Si falla al guardar, no dice nada
- Por qué: Viene relleno: solo pide el nombre.

### Corregir el saldo de una cuenta — Más adelante

- Fichero: `Yala/App/Views/Accounts/AccountFormView.swift (edición, «Tu saldo»)`
- Desde: Editar cuenta
- Campos: 4-5 (según Yala, cuánto tienes, diferencia, cómo corregir)
- Obligatorios: Saldo real
- Qué confunde: «Ajustar por registro» y «Cambiar saldo inicial» son dos caminos con jerga
- Por qué: Buen candidato a un guiado corto («¿Cuánto tienes de verdad hoy?» → «¿Cómo lo corregimos?»), pero vive dentro de editar. Después de los siete.

## Preguntas de cada maqueta

### Crear una cuenta

| # | Pregunta | Cubre | Respuesta | Por defecto | Se salta si |
|---|---|---|---|---|---|
| 1 | ¿Qué cuenta quieres crear? | Tipo (General · Efectivo · Cuenta corriente · Ahorros · Tarjeta de crédito) | Tarjetas de opción con icono y frase | Ninguna marcada. El formulario arranca en «General», aquí llamado «Todo junto». | Nunca. Si se entra desde «Nueva tarjeta» se puede saltar con el tipo ya puesto. |
| 2 | ¿En qué moneda usas esta tarjeta? | Moneda + Otras divisas (las «líneas» de una tarjeta) | Chips de moneda, varias a la vez | Tu moneda principal de Yala marcada. Ojo: el formulario de hoy pone siempre soles (PEN), no lee tu moneda principal. | Si solo usas una moneda en Yala: se pone esa y no se pregunta. Se puede cambiar en la confirmación. |
| 3 | ¿Cómo se llama esta tarjeta? | Nombre de la cuenta (obligatorio, sin repetir) | Texto con ejemplos tocables | Vacío. En efectivo y «Todo junto» se propone el nombre («¿La llamamos «Efectivo»?» con «Sí, así está bien»). | Nunca. |
| 4 | ¿Quieres anotar los últimos 4 números? | Número de cuenta (opcional) | Campo numérico corto + «No hace falta» | Vacío | Efectivo y «Todo junto» (no tienen número). |
| 5 | ¿Cuánto debes hoy en soles? | Saldo inicial (obligatorio al crear) + Signo | Monto con teclado + atajos | Vacío | Nunca. |
| 6 | Lo sacamos con la app de tu banco | «¿No sabes tu saldo?» (la calculadora de saldo del formulario) | Dos montos y el resultado | — | Si no toca «No sé, ayúdame a sacarlo». |
| 7 | ¿Y en dólares? | Saldo inicial de la línea en otra divisa | Monto | Vacío | Si eligió una sola moneda. |
| 8 | ¿Qué día cierra tu tarjeta? | Día de corte (opcional) | Rejilla de días 1-31 | Ninguno («Sin definir») | Si no es tarjeta de crédito. |
| 9 | ¿Hasta qué día puedes pagarla? | Día de pago | Rejilla de días 1-31 | Ninguno marcado (el formulario pone el 1 sin preguntar) | Si no es tarjeta de crédito. |
| 10 | ¿Cuándo te recordamos pagarla? | Avisarme antes de pagar + Cuándo | Tarjetas de opción | 3 días antes (destacada). El formulario arranca apagado. | Si no es tarjeta, o si dijo «No lo sé» al día de pago. Sin día de cierre solo ofrece «El mismo día» y avisa sin monto. |
| 11 | ¿Lo que pasa en esta tarjeta cuenta en tus reportes? | Excluir de las estadísticas (en «Más opciones») | Dos tarjetas de opción | Sí, que cuente | Propuesta: no preguntarlo y dejarlo solo en la confirmación y en el formulario. Está aquí porque el encargo pide no quitar ninguna. |
| 12 | Revisa antes de crear | Todas las respuestas | Resumen con «Cambiar» por fila |  |  |
| 13 | ¡Lista! | — | Pantalla de éxito |  |  |
| 14 | «Usar formulario» con lo ya respondido | — | El formulario de siempre |  |  |

### Crear un pago planificado

| # | Pregunta | Cubre | Respuesta | Por defecto | Se salta si |
|---|---|---|---|---|---|
| 1 | ¿Es algo que pagas o algo que te pagan? | Gasto / Ingreso | Dos tarjetas de opción | Algo que pago (Gasto) | Modo «solo gastos», o si viene de «Hacer recurrente» con un registro. |
| 2 | ¿Qué pagas cada cierto tiempo? | Categoría (obligatoria) + ¿Es una suscripción? | Tarjetas con icono + interruptor | Ninguna marcada. «Es una suscripción» se enciende solo con las dos suscripciones. | Si viene de un registro con categoría. |
| 3 | ¿Cómo se llama? | Nombre del pago (obligatorio) + Logo | Texto con ejemplos; el logo se detecta solo | El nombre del registro si viene de uno. Logo: Automático. | Nunca. |
| 4 | ¿Cuánto pagas? | Monto (obligatorio) + Monto estimado | Monto + interruptor | Vacío · interruptor apagado | Nunca. |
| 5 | ¿Con qué lo pagas? | Cuenta (obligatoria; opcional si es compartido) | Lista de cuentas | La última usada, arriba | Si solo tienes una cuenta (se usa esa). |
| 6 | ¿Cada cuánto toca pagar? | Una sola vez / Repetir + Cada [N] [frecuencia] | Tarjetas de opción | Cada mes | Nunca. |
| 7 | ¿Qué día del mes? | Día del mes · ¿Qué días? (semana) · Fecha anual · Fecha de pago (una vez) | Cambia según la respuesta anterior: rejilla de días, días de la semana, mes y día, o fecha | Hoy | Nunca (cambia de forma). |
| 8 | ¿Desde cuándo empieza? | Fecha de inicio | Tarjetas de opción + calendario en «Otra fecha» | La próxima vez que toque (hoy si hoy es el día) | Si es «Una sola vez» (ya eligió la fecha). |
| 9 | ¿Tiene fecha de fin? | Tiene fecha de fin + Fecha de fin (en «Más opciones») | Tarjetas de opción | No tiene fin. (Hoy, al encenderlo, pone un año sin decirlo.) | Si es «Una sola vez». |
| 10 | ¿Te avisamos antes de que toque pagar? | Notificar en fecha de vencimiento + Notificar días antes | Tarjetas de opción | 3 días antes (el de hoy) | Nunca. |
| 11 | ¿Lo pagas con alguien más? | ¿Es un gasto compartido? (en «Más opciones») | Dos tarjetas de opción | No, es solo mío | Si no tienes grupos, o si es un cobro. |
| 12 | ¿En qué grupo y cómo lo dividen? | Grupo + Moneda (compartido) + División | Lista de grupos + chips de reparto | Reparto: el del grupo | Si respondió «No, es solo mío». |
| 13 | ¿Le pones alguna etiqueta? | Etiquetas (en «Más opciones») | Chips, varias a la vez | Ninguna | Si no tienes etiquetas, o si es compartido (hoy se oculta). |
| 14 | ¿Quieres que el registro lleve una nota? | Descripción del gasto (opcional) — es la nota | Texto + «Sin nota» | Vacía | Propuesta: saltarla siempre y dejarla en el formulario. Hoy se confunde con el nombre. |
| 15 | Revisa antes de guardar | Todas las respuestas + Activo | Resumen con «Cambiar» |  |  |
| 16 | ¡Anotado! | — | Pantalla de éxito |  |  |

### Crear un presupuesto

| # | Pregunta | Cubre | Respuesta | Por defecto | Se salta si |
|---|---|---|---|---|---|
| 1 | ¿Qué gastos cuenta? | ¿Qué gastos cuenta? (Todos mis gastos / Elegir categorías) | Dos tarjetas de opción | Ninguna marcada (el formulario arranca en «Todos») | Nunca. |
| 2 | ¿Cuáles? | Categorías (hoja «Elegir categorías») | Tarjetas que se marcan, con lo gastado este mes | Ninguna | Si eligió «Todos mis gastos». |
| 3 | ¿Algo que no quieras contar? | Filtros › Subcategorías | Chips, todas encendidas | Todas | Si eligió «Todos mis gastos». |
| 4 | ¿Cada cuánto se renueva? | Período (Semanal · Mensual · Anual · Único) | Tarjetas de opción | El de la pestaña desde la que se abrió (Mensual si no hay) | Nunca. |
| 5 | ¿Entre qué fechas? | Fecha inicial + Fecha final | Dos fechas | Hoy y hoy | Si no es «Una sola vez». |
| 6 | ¿Cuánto quieres gastar como máximo al mes? | Límite (obligatorio) + su moneda | Monto + sugerencias redondeadas de lo gastado | Vacío | Nunca. |
| 7 | ¿Cuenta lo que gastas en todas tus cuentas? | Filtros › Cuentas | Dos opciones; la segunda abre la lista de cuentas | En todas | Si solo tienes una cuenta. |
| 8 | ¿Solo los gastos con alguna etiqueta? | Filtros › Etiquetas | Dos opciones; la segunda abre los chips de etiquetas | Todas | Si no tienes etiquetas. |
| 9 | ¿Qué tipo de gasto cuenta? | Filtros › Necesidad del gasto | Chips, todos encendidos | Todos | Propuesta: saltarla siempre y dejarla en el formulario. Pocos la usan y pide entender la «necesidad». |
| 10 | ¿Cuenta tu parte de los gastos de grupo? | Contar mi parte de los gastos de grupo | Dos tarjetas de opción | Sí | Si no tienes grupos (como hoy). |
| 11 | ¿Te avisamos cuando vayas llegando al tope? | Notificar al alcanzar límite + porcentajes | Tarjetas de opción | 75 % y 100 % (el formulario arranca apagado) | Nunca. |
| 12 | ¿Lo quieres ver en tu Panel? | Mostrar en el widget | Dos tarjetas de opción | Sí (el formulario arranca apagado) | Nunca. |
| 13 | ¿Lo llamamos «Comida y salidas»? | Nombre del presupuesto (obligatorio) | Propuesta + «Ponerle otro nombre» | Se arma con lo elegido: «Mis gastos del mes», «Comida y salidas», «Viaje a Cusco» (fechas) | Nunca. |
| 14 | Revisa antes de crear | Todas las respuestas + Activo | Resumen con «Cambiar» |  |  |
| 15 | ¡Listo! | — | Pantalla de éxito |  |  |

### Crear un grupo

| # | Pregunta | Cubre | Respuesta | Por defecto | Se salta si |
|---|---|---|---|---|---|
| 1 | ¿Para qué es el grupo? | Icono y color (indirecto) | Tarjetas con icono | Ninguna marcada | Nunca. |
| 2 | ¿Cómo se llama? | Nombre (obligatorio) | Texto con ejemplos según «para qué es» | Vacío | Nunca. |
| 3 | ¿Cómo te llamas? | Tu nombre en el grupo (obligatorio en el primer grupo) | Texto | Vacío | Si ya tienes otro grupo (ya sabemos tu nombre). |
| 4 | ¿Le cambiamos el ícono o el color? | Icono y color (sin etiqueta hoy) | Rejilla de iconos + paleta | Los de «para qué es» | Propuesta: saltarla y dejarla en el formulario. |
| 5 | ¿Cómo llevamos las monedas? | Ver las deudas en una sola moneda (en «Más opciones») | Dos tarjetas de opción con ejemplo | Cada gasto en su moneda (apagado, como hoy) | Propuesta: si nunca usaste otra moneda en Yala, se salta y queda «cada gasto en su moneda». |
| 6 | ¿En qué moneda? | Moneda del grupo | Chips de moneda | Tu moneda principal (en el primer grupo, la de tu región) | Si eligió «Cada gasto en su moneda». |
| 7 | ¿Cómo suelen dividir los gastos? | Cómo se reparte un gasto nuevo (en «Más opciones») | Tarjetas con ejemplo | En partes iguales | Nunca. |
| 8 | ¿Juntamos las deudas para que haya menos pagos? | Menos pagos entre ustedes (en «Más opciones») | Dos tarjetas con ejemplo | Sí (como hoy) | Propuesta: saltarla y dejar «Sí». Pocos la cambian. |
| 9 | Revisa antes de crear | Todas las respuestas | Resumen con «Cambiar» |  |  |
| 10 | «Viaje a Cusco» está listo | — | Éxito = la hoja «Invitar» de hoy |  |  |

### Crear un favorito

| # | Pregunta | Cubre | Respuesta | Por defecto | Se salta si |
|---|---|---|---|---|---|
| 1 | ¿Qué registras seguido? | Gasto / Ingreso / Transferencia | Tarjetas de opción | Un gasto | Modo «solo gastos». |
| 2 | ¿De qué es? | Categoría (opcional) | Tarjetas de tus categorías más usadas + «Otra» | Ninguna | Si es transferencia. |
| 3 | ¿Con qué lo pagas casi siempre? | Cuenta · (transferencia: Origen y Destino) | Lista de cuentas | Ninguna | Nunca. En transferencia son dos preguntas seguidas, y la segunda no ofrece la primera. |
| 4 | ¿Es siempre el mismo monto? | Monto (opcional) | Monto + «Cambia cada vez» | Vacío | Nunca. |
| 5 | ¿Qué tan necesario es este gasto? | Necesidad (chip) | Tarjetas con frase | La de la categoría (Cafeterías → Opcional) | Ingreso, transferencia o sin categoría (como hoy). |
| 6 | ¿Le pones alguna etiqueta? | Etiquetas (chip) | Chips | Ninguna | Si no tienes etiquetas, o es transferencia. |
| 7 | ¿Quieres que lleve una nota? | Descripción (opcional) | Texto + «Sin nota» | Vacía | Propuesta: saltarla y dejarla en el formulario. |
| 8 | ¿Cómo lo llamamos? | Nombre del favorito (obligatorio) | Texto con ideas (categoría + nota) | Vacío | Nunca. |
| 9 | Revisa antes de guardar | Todas las respuestas | Resumen con «Cambiar» |  |  |
| 10 | ¡Guardado! | — | Pantalla de éxito |  |  |

### Anotar una deuda de antes (saldo inicial)

| # | Pregunta | Cubre | Respuesta | Por defecto | Se salta si |
|---|---|---|---|---|---|
| 1 | ¿Quién debía dinero antes de usar Yala? | Quién debe (obligatorio) | Lista de miembros | La persona recién aprobada, si se entra desde ahí | Nunca (si viene precargado, se ve marcado). |
| 2 | ¿A quién le debe Luis? | A quién (obligatorio) | Lista de miembros sin el anterior | Vacío | Si el grupo es de dos: es la otra persona. |
| 3 | ¿En qué moneda? | Moneda (obligatoria) | Chips de moneda | La del grupo | Propuesta: si el grupo lleva una sola moneda, se salta (se cambia en la confirmación). |
| 4 | ¿Cuánto le debe? | Monto (obligatorio) | Monto | Vacío | Nunca. |
| 5 | ¿Desde cuándo? | Fecha (solo pasado) | Dos opciones + calendario | Hoy | Propuesta: saltarla y dejar hoy. |
| 6 | Luis le debe S/ 120 a Ana | Todas las respuestas | Frase + resumen con «Cambiar» |  |  |
| 7 | ¡Anotado! | — | Pantalla de éxito |  |  |

### Crear una categoría

| # | Pregunta | Cubre | Respuesta | Por defecto | Se salta si |
|---|---|---|---|---|---|
| 1 | ¿Cómo se llama la categoría? | Nombre de la categoría (obligatorio) | Texto con ideas | Vacío | Nunca. |
| 2 | ¿Con qué ícono y color la reconoces? | Ícono y color | Rejilla de íconos sugeridos por el nombre + paleta | Ícono «tag» e índigo (los de hoy). Propuesta: sugerir el ícono por el nombre. | Nunca. |
| 3 | ¿Qué entra en «Mascotas»? | Subcategorías (al menos una) · Nombre de cada subcategoría | Chips sugeridos + campo para añadir | Ninguna marcada | Nunca. |
| 4 | ¿Qué tan necesario es cada uno? | Necesidad (de cada subcategoría) | Un selector por subcategoría | Sin clasificación (el de hoy) | Propuesta: se puede saltar con «Decidir después». |
| 5 | ¿La usas ya al registrar? | Usar al registrar (categoría y cada subcategoría) | Dos opciones | Sí | Propuesta: no preguntarla al crear (nadie crea una categoría para esconderla) y dejarla en el formulario. |
| 6 | Revisa antes de crear | Todas las respuestas | Resumen con «Cambiar» |  |  |
| 7 | ¡Lista! | — | Pantalla de éxito |  |  |


## Detalle de los formularios de Grupos
Medido en el código de `2.3` el 2026-11-15 (rama `encargo/2026-11-15-exploracion-formularios-guiados`, base `d2cd2e75b`).
Los textos salen de `Yala/Resources/es.lproj/Localizable.strings`.

## Crear o editar grupo — `Groups/GroupFormView.swift`

Hoja. Se abre con «Nuevo grupo» (Grupos) y, como primer grupo, desde la bienvenida (`isFirstGroupSetup`).

| Campo | Control | Obligatorio | Por defecto | Cuándo aparece |
|---|---|---|---|---|
| Icono y color | Círculo con lápiz → `IconColorPickerSheet` | No | `person.2.fill` · `#8B5CF6` | Siempre (sin etiqueta) |
| Tu nombre en el grupo | Texto | Sí | vacío | Solo el primer grupo |
| Nombre | Texto («Ej.: Viaje a Cusco») | Sí | vacío | Siempre |
| Menos pagos entre ustedes | Interruptor | No | Encendido (grupo nuevo) | En «Más opciones» |
| Ver las deudas en una sola moneda | Interruptor | No | Apagado | En «Más opciones» |
| Moneda | Fila → selector | No | Moneda preferida (o la de la región en el primer grupo) | Solo con el interruptor anterior encendido |
| Cómo se reparte un gasto nuevo | Menú: Partes iguales · Porcentaje · Monto exacto · Proporciones | No | Partes iguales | En «Más opciones» |

Tras crear: hoja «Invitar» («Invitar por WhatsApp u otra app» · «Más tarde»).

Confunde: la moneda del grupo no se ve hasta encender «una sola moneda»; «transferencias» suena a banco; icono y color sin etiqueta; tres de los seis campos viven plegados en «Más opciones».

## Gasto de grupo — `Groups/GroupExpenseFormView.swift`

Hoja. Entradas: detalle del grupo, botón de gasto (composer), Bandeja, convertir un registro.

| Campo | Control | Obligatorio | Por defecto | Cuándo aparece |
|---|---|---|---|---|
| Grupo | Pastilla | Sí (viene elegido) | El de la entrada | Si hay varios grupos, se puede cambiar |
| Fecha | Pastilla → hoja | Sí | Hoy | Siempre |
| Descripción | Texto | Sí | vacío | Siempre |
| Moneda | Pastilla → selector | Sí | La del grupo | Siempre |
| Importe | Monto | Sí | vacío | Siempre |
| Quién pagó | Avatares | Sí | Tú | Grupos de 3+ (en 2, «Opciones rápidas») |
| Reparto: modo | Segmentado Iguales · Porcentaje · Monto · Proporción | Sí | El del grupo | Al abrir «dividido» |
| Reparto: participantes y partes | Casillas o un campo por persona | Sí | Todos | Al abrir «dividido» |
| Cuenta | Pastilla → selector | Solo si pagas tú con el reflejo activo | Ninguna | Solo si pagas tú y se refleja en tus cuentas |
| Categoría | Pastilla → selector | No | Ninguna | Siempre |

Confunde: «Pagado por [ti] y dividido [en partes iguales]» son dos botones dentro de una frase; el mismo modo tiene dos nombres («Iguales» / «Partes iguales»); un campo vacío en porcentaje o monto deja fuera a la persona sin decirlo; «Restante» y «Te pasaste» no dicen de quién; una categoría de ingreso lo convierte en venta sin aviso.

## Saldo inicial de un miembro — `Groups/GroupOpeningBalanceFormView.swift`

Hoja. Detalle del grupo (dueño o admin) y tras aprobar a alguien.

| Campo | Control | Obligatorio | Por defecto | Cuándo aparece |
|---|---|---|---|---|
| Quién debe | Fila → miembros | Sí | El aprobado, si viene de ahí | Siempre |
| A quién | Fila → miembros | Sí | vacío | Siempre |
| Moneda | Píldora → selector | Sí | La del grupo | Siempre |
| Monto | Monto | Sí | vacío | Siempre |
| Fecha | Fecha (solo pasado) | Sí | Hoy | Siempre |

Confunde: «Saldo inicial» no dice que es una deuda de antes; el sentido de la deuda depende de las dos filas; si ya había uno entre esas dos personas, «Reemplazar» lo cambia.

## Liquidación (saldar) — `Groups/SettlementFormView.swift`

Hoja, desde «Saldar» en un saldo pendiente. Quién paga a quién viene del saldo.

| Campo | Control | Obligatorio | Por defecto | Cuándo aparece |
|---|---|---|---|---|
| Moneda del pago | Segmentado (original / ≈ convertida) | No | La original | Grupo de una moneda y deuda en otra |
| Cuánto se paga | Segmentado Todo · Una parte | No | Todo | Siempre |
| Importe | Monto | Sí | La deuda completa | Siempre |
| De qué cuenta sale | Fila → selector | No | Ninguna | Si pagas tú y se refleja en tus cuentas |
| Nota | Texto | No | vacío | Siempre |
| Fecha | Fecha | Sí | Hoy | Siempre (dentro de la caja «Nota») |

Confunde: «Saldar» suena a «saldo»; la fecha vive bajo el título «Nota»; «≈» no se explica.

## Presupuesto del grupo — `Groups/GroupBudgetSheet.swift`

Hoja desde Ajustes del grupo (solo admin). Un campo: el importe, con vista previa de lo gastado y de lo que quedaría.

## Reflejar en tus cuentas — `Groups/BridgeActivationSheet.swift`

Hoja de una decisión: «Empezar desde ahora» (por defecto) o «Importar todo el historial» (crea borradores en la Bandeja; el texto no lo dice).

## «Tu parte» — `Groups/SplitLines/`

Hoja para partir tu parte de un gasto en líneas: tipo (Gasto / Recarga), importe, categoría (gasto) o cuenta destino (recarga). «Guardar línea» se apaga sin decir por qué.
