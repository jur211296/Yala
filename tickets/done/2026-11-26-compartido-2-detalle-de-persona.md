---
id: 2026-11-26-compartido-2-detalle-de-persona
status: done
priority: high
area: groups
created: 2026-11-26
updated: 2026-11-26
---
# Compartido 2: el detalle de una persona

Decisión de Jürgen (26-nov, 13:18 Lima) sobre la maqueta v2 (`docs/propuestas/compartido-grupos-personas-v2/`): detalle de
persona aprobado tal cual. Lote 2 de 3 (1: sección y chips; 3: invitar a una persona y entrada sin grupo obligatorio).
Card del tablero: «Grupos: deudas directas con personas fuera de grupos (2.3)».

## Qué cambia para quien usa la app

- En Compartido › Personas, **tocar una tarjeta abre a esa persona**, como se abre un grupo: su nombre como título
  grande, la cifra arriba y los mismos chips «Gastos · Saldos · Estadísticas» (icono en los tres, nombre solo en el
  elegido).
- **Filtro de grupo** junto al rótulo de la cifra, en las tres páginas: «Todos los grupos · <cada grupo> · Sin grupo».
  Es la cápsula de Estadísticas del grupo. La cifra dice «Con Ana te deben» o, con un grupo elegido, «En Viaje a Cusco
  te deben… Solo este grupo.».
- **Gastos**: los gastos donde estáis los dos, de todos los grupos y de lo sin grupo, y los pagos entre los dos; cada
  fila dice su grupo (con su color) o «Sin grupo». Tocar un gasto abre su detalle y «Editar» el formulario de siempre.
  Arriba, la fila «Nuevo gasto · Voz · Foto · Yala IA» de siempre, con los grupos que compartes y el del filtro
  marcado.
- **Saldos**: con un grupo elegido, la página de Saldos del grupo con lo vuestro y el «Saldar» de siempre. Con «Todos
  los grupos», una tarjeta con lo que te debe (o le debes), **el desglose por grupo** y **«Saldar todo»**: si es un solo
  pago abre el formulario de siempre; si son varios, una hoja los enumera («Viaje a Cusco · Ana te paga S/ 110.00») y
  apunta un pago por grupo y moneda, con «Deshacer» de todos.
- **Estadísticas**: las del grupo con el filtro («Total gastado juntos», «¿Quién puso más?» con Tú y la persona juntados
  entre grupos, «Mi parte») y, con «Todos los grupos», **«Por grupo»**: cuánto te debe en cada grupo, con una barra.
- El detalle de un grupo normal no cambia.

## Cómo está hecho

- Un `GroupDetailViewModel` por grupo compartido (`CompartidoPersonDetailModel`): deudas, gastos y pagos salen del mismo
  cálculo que el detalle de cada grupo. La lógica que filtra y suma es pura (`CompartidoPersonDetailLogic`), en céntimos
  enteros: lo que se salda grupo a grupo suma exactamente lo de «Todos los grupos».
- Las páginas son las del grupo con parámetros opcionales (cabecera propia, «yo» por gasto, etiqueta de grupo, alias de
  miembros, filtro y «Por grupo» en Estadísticas). Sin ellos, el detalle de grupo es el de antes (lo fija un test).
- La tarjeta de Personas guarda dónde está la persona (`Person.memberships`); el detalle se empuja desde
  `GroupsContainerView` con `.compartidoPersonDestination`.
- Textos nuevos solo en `Compartido.strings`, en los 16 idiomas (voseo en es-AR).

## Pruebas

- `YalaTests/CompartidoDetallePersona/`: lógica (filtro, cifra, desglose, saldar exacto por grupo y moneda, gastos
  compartidos, alias, «Por grupo») y cableado (membresías, Estadísticas con alias y sin ellos, detalle de grupo sin
  piezas nuevas, textos en 16 idiomas).
- `YalaUITests/CompartidoDetallePersona/`: abrir a Ana desde Personas con los tres chips y el filtro, el desglose y
  «Saldar todo»; elegir un grupo deja el «Saldar» de siempre; el detalle de grupo sin filtro. Más las capturas.

## Fuera

- Invitar a una persona, sus ajustes y «¿Con quién?» en Nuevo gasto: lote 3.
- Confirmar pagos pendientes con «Todos los grupos»: se hace eligiendo el grupo (la página lo dice).

## QA en el iPhone (cuando puedas, no bloquea)

1. Yala Dev en el iPhone de pruebas, con al menos una persona que esté en dos de tus grupos.
2. Compartido › chip Personas › toca su tarjeta: se abre con su nombre, la cifra y los tres chips.
3. Toca «Todos los grupos» y elige un grupo: la cifra dice «En <grupo>…» y Gastos solo enseña ese grupo.
4. Saldos con «Todos los grupos»: el desglose suma la cifra. «Saldar todo» enumera un pago por grupo y moneda;
   apúntalos y toca «Deshacer» en el aviso: vuelve todo como estaba.
5. Saldos con un grupo elegido: «Saldar» abre el formulario de siempre.
6. Vuelve a Grupos y abre un grupo: se ve como antes, sin filtro.
