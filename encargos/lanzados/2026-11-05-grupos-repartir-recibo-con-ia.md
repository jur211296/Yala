# Grupos: repartir un recibo con IA (foto o voz)
toca: formulario de gasto de grupo, gateway IA (líneas de recibo + reparto), Bandeja si aplica

Rama base: 2.3. Un solo PR contra 2.3, un solo cierre. Máquina: Mini (o la libre). Puede usar simulador; pipeline serial.

## Contexto
Card: «Grupos: repartir un recibo con IA — foto o voz, «quién comió qué» y elegir a quién se cobra cada cosa (Pro)» (tablero-grupos-repartir-un-recibo-con-ia-foto-o-fu74). Cierre autónomo. Decisión Jürgen 21-oct. Relacionada: «Dividir pago grupal escaneando un recibo» (misma ola; no dupliques flujo).

Hoy un gasto de grupo no se puede apuntar con voz ni foto (solo rodeo por Bandeja) y se reparte por persona, sin líneas.

## Qué se pide
1. En el grupo: «Añadir gasto» › «Desde un recibo» (foto o voz).
2. Gateway: lee líneas del recibo + frase de quién comió qué; pantalla de revisión del reparto; se guarda como gasto de grupo (Pro). Sin guardar líneas permanentes ni cambiar el esquema de datos más de lo mínimo.
3. `tablero`: en curso al empezar; in qa al cerrar, con guion corto de prueba.
4. Si falta una decisión de producto que cambie el resultado: `preguntar-bot` (no asumas).

## Hecha cuando
- Un recibo de restaurante de cinco líneas, con una frase de quién comió qué, queda repartido bien a la primera o con un solo ajuste, y se guarda como gasto de grupo.
- Card en in qa.
- `/cerrar-total` con «Saltado o asumido sin preguntar».

PREGUNTAR, NO SALTAR. `tablero` + /cerrar-total.

## Paso 0 — decisiones

> Resueltas en autónomo (bypass): las recomendaciones se dan por buenas. Se discuten en el PR.
> D1 y D5 los contestó Jürgen (2026-11-05 21:15 Lima, vía el bot dueño).

**D1 · Dónde vive «Desde un recibo»** → dentro de Nuevo gasto del grupo, un botón arriba («Desde un recibo»); el «+» sigue abriendo el formulario a un toque.
Por qué: el gasto normal no pierde un toque y el recibo es un modo del mismo formulario. Alternativa descartada: menú en el «+» (dos toques para lo de siempre). **Jürgen: dentro del formulario, sin menú B; el diseño concreto lo elijo yo.**

**D2 · Cómo se guarda** → la revisión produce una `GroupExpensePrefillTemplate` con reparto `.exact` y abre el formulario de siempre ya rellenado; la persona guarda ahí.
Por qué: reusa guardado, puente, cuenta, categoría y pantalla de éxito sin tocar el esquema (el encargo: sin líneas permanentes). Alternativa descartada: guardar desde la revisión (duplicaría el camino de guardado y sus puertas).

**D3 · Tareas del gateway** → dos tareas nuevas: `receipt.photo` (cubo `vision`, exige imagen) y `receipt.voice` (cubo `voice`, `notePairing: consume`). Mismo esquema de salida.
Por qué: el cubo sale de la tarea y la foto gasta foto y la voz gasta voz, como pide la card (cupo 5 y 5). Alternativa descartada: una sola tarea (no puede caer en dos cubos ni exigir imagen a medias).

**D4 · Nombres del grupo** → no salen del teléfono. La IA copia los nombres tal como están en la frase (`@me` para «yo», `@all` para «todos») y Swift los casa con los miembros; un nombre que no casa se enseña en la revisión.
Por qué: mismo molde que el medio de pago (`PaymentMethodAccountLogic`): no cambia lo que sale del teléfono y un nombre inventado no casa con nadie. Alternativa descartada: mandar la lista de miembros (dato nuevo hacia el proveedor, decisión de privacidad).

**D5 · Propina, servicio, impuestos y descuentos** → **no se reparten solos (Jürgen).** Las líneas de ese tipo que lea la IA llegan «sin incluir»; la persona las incluye con un atajo por línea («Según lo que consumió cada uno», «Partes iguales» o personas concretas), y puede añadir propina o servicio que no estén en el recibo con atajos (10 %, 15 %). El total del gasto es solo lo incluido.
Por qué: decisión de Jürgen, que descartó repartirlos en proporción o a partes iguales por defecto.

**D6 · Línea sin nadie asignado** → «entre todos»: los que aparecen en alguna línea del recibo; si nadie aparece, todo el grupo. Se ve así en la revisión y se cambia con un toque.
Por qué: la frase suele nombrar solo lo individual («Ana el lomo») y lo demás es compartido.

**D7 · Frase de quién comió qué con foto** → campo de texto opcional junto a la foto (el teclado trae su dictado, que no gasta nota de voz). El modo voz es una nota que dicta líneas y reparto juntos: transcribir + `receipt.voice`.
Por qué: foto + frase = un uso de foto; no se cobra una nota extra por dictar el reparto.

**D8 · Pro** → la entrada se ve para todos; la llamada pasa por el servidor como foto y voz hoy: Free gasta su prueba y al agotarla sale «Ya usaste…» con «Ver Yala Pro». Consentimiento de datos de IA antes de la primera llamada, el mismo de foto y voz.
Por qué: igual que la foto y la voz del registro personal; no hay bloqueo local por Pro para ellas.

**D9 · Despliegue del gateway** → no lo hago yo: el RUNBOOK dice que el Worker lo despliega Jürgen a mano, y hay otras cuatro sesiones vivas tocando el gateway (desplegar desde esta rama quitaría lo suyo). Va a «Necesita de ti» con su entrada en el RUNBOOK; hasta el despliegue, la app enseña el error de siempre.
Por qué: acceso y riesgo para otros. Alternativa descartada: desplegar staging desde la rama.

**D10 · Relación con «Dividir pago grupal escaneando un recibo»** → no se toca: esa card espera una propuesta visual elegida por Jürgen (botón en el registro personal, nombres libres, resumen para compartir). La lógica de reparto queda reusable para ella.
