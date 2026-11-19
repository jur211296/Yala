---
id: 2026-11-17-asistente-nueva-cuenta
status: done
priority: medium
area: ux
created: 2026-11-17
updated: 2026-11-18
source: encargo 2026-11-18-asistente-nueva-cuenta (Jürgen, 17-nov 20:51 Lima, serie de asistentes de creación)
---
# «Nueva cuenta» por pasos, con «Usar formulario»

Jürgen (17-nov): al tocar crear, en vez del formulario, un proceso por pasos con una pregunta clara por pantalla,
valores sugeridos y progreso arriba; arriba y siempre a la vista, la salida al formulario de siempre con lo ya
respondido; al final un resumen breve y el botón de crear. Segunda vista de la serie, sobre el patrón compartido que
dejó «Nuevo presupuesto».

## Qué cambia para quien usa la app

- Ajustes › Cuentas › «+» y las entradas del Panel («Agregar cuenta» del carrusel, «Tus finanzas», el vacío sin
  cuentas) abren un asistente: ¿Qué tipo de cuenta es? → ¿En qué moneda? → ¿Cómo la llamamos? → ¿Cuánto tienes hoy?
  (en tarjeta, ¿Cuánto debes hoy?) → en tarjeta, ¿Qué día cierra? → ¿Hasta qué día puedes pagarla? → ¿Cuándo te
  recordamos pagarla? (solo si sabe el día de pago) → ¿La creamos así?
- Cada pregunta llega con lo sugerido ya marcado: cuenta corriente, la moneda principal, el nombre del tipo (sin
  repetir el de otra cuenta), saldo 0, días «No lo sé» y el recordatorio un día antes.
- El nombre repetido avisa y apaga «Siguiente», como el formulario.
- El resumen enseña la tarjeta de la cuenta como quedará; cada respuesta se toca para cambiarla.
- «Usar formulario» arriba a la derecha: el formulario de siempre, a pantalla grande, con lo respondido (tipo, color,
  moneda, nombre, saldo y, en tarjeta, días y recordatorio). Su X pregunta antes de tirarlo.
- La X del asistente (y bajar la hoja), con algo respondido, pregunta antes de descartar.
- Editar una cuenta sigue en el formulario. Crear una cuenta desde Nuevo registro («Crear otra cuenta») y desde «falta
  un paso» (Estadísticas, Registros) no cambia: siguen en el formulario.

## Paso 0 y «Decidido sin consultar»

En el encargo (`encargos/lanzados/2026-11-18-asistente-nueva-cuenta.md`, viaja al PR). Resumen:

- Preguntas y textos de «Primera cuenta» de Primeros pasos; solo el tipo lleva pregunta nueva («¿Cuál creamos
  primero?» no vale fuera de Primeros pasos).
- Una sola moneda, como el formulario: el formulario no admite otras monedas al crear, así que no podrían pasar a
  «Usar formulario».
- Se guarda con `FirstAccountCreator` (el de Primeros pasos).
- Cinco pruebas de interfaz que creaban una cuenta por el formulario pasan antes por «Usar formulario»
  (`pasarAlFormularioDeNuevaCuenta`).

## Pendiente (fuera del encargo)

- El patrón compartido no trae una pieza para elegir un día del mes: el asistente usa una rueda propia dentro de
  `AsistenteTarjeta`. Si pago planificado la necesita, conviene subirla al patrón.
- Tras crear desde el formulario, una tarjeta ofrece añadir otra divisa y una moneda que no es la principal ofrece
  verla en el Panel; desde el asistente no. Se decide si el asistente debe ofrecerlo.
- `FirstAccountFlowView` (Primeros pasos) no se tocó.

## Guion para probarlo en el iPhone (no frena el merge)

1. Abre Yala Dev en el iPhone 14 y ve a Ajustes (tu avatar) › Cuentas › «+».
2. Elige «Tarjeta de crédito» y toca «Siguiente» en cada pregunta. En el nombre, escribe el de una cuenta que ya
   tengas: debe salir «Ya tienes una cuenta con ese nombre.» y «Siguiente» apagado. Cámbialo.
3. En el día de cierre y el de pago gira la rueda; en el recordatorio elige uno. iOS puede pedir el permiso de avisos.
4. En «¿La creamos así?» toca «Tipo» para cambiarlo y vuelve con «Siguiente»: debe regresar al resumen.
5. Toca «Crear cuenta». Esperado: la hoja se cierra y la tarjeta aparece en la lista con lo que debes.
6. Repite desde el Panel («Agregar cuenta» del carrusel de «Tus finanzas»). En la segunda pregunta toca «Usar
   formulario». Esperado: el formulario con el tipo y la moneda; su X pregunta «¿Descartar cambios?».
