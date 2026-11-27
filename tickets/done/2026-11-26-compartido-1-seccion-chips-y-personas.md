---
id: 2026-11-26-compartido-1-seccion-chips-y-personas
status: done
priority: high
area: groups
created: 2026-11-26
updated: 2026-11-26
---
# Compartido 1: la sección «Compartido» con chips Grupos | Personas

Decisión de Jürgen (26-nov, 13:18 Lima) sobre la maqueta v2 (`docs/propuestas/compartido-grupos-personas-v2/`):
nombre «Compartido», Grupos y Personas aprobados. Lote 1 de 3 (2: detalle de persona; 3: invitar a una persona y entrada
sin grupo obligatorio). Card del tablero: «Grupos: deudas directas con personas fuera de grupos (2.3)».

## Qué cambia para quien usa la app

- La pestaña Grupos se llama **«Compartido»** (título grande y barra), en los 16 idiomas. La barra que cada uno ordenó
  se conserva: la pestaña no cambia de identificador.
- Bajo el título, los chips **«Grupos | Personas»**, los de Planificación.
- En los dos chips, igual que hoy: «Te deben en total» con la línea de archivados, la fila «Nuevo gasto · Voz · Foto ·
  Yala IA» y «Dividir una boleta».
- **Grupos**: la lista de hoy y «Ver archivados (N)», sin cambios.
- **Personas**: una tarjeta por persona con algo pendiente, con dónde compartes con ella («En Piso compartido · Viaje a
  Cusco») y una fila por moneda («Beto te debe S/ 140.00»). Las personas a mano bajan a «Ver liquidadas (N)», con el
  pliegue de los archivados. Sin nadie pendiente, una línea lo dice.
- En la barra, «Añadir persona» ocupa el sitio de «Nuevo grupo» en el chip Personas (por ahora abre el alta de grupo de
  hoy; crear la persona es el lote 3).
- Por dentro, una persona es un grupo de dos con una marca (`SplitGroup.isPerson`, `split_groups.is_person`, manifiesto
  de Grupos v4). Un grupo marcado no sale en la lista de Grupos; su saldo va a la tarjeta de la persona como «Sin grupo».
  Esquema aprobado por Jürgen el 26-nov: migración `qa/cloud/g37_01_group_is_person.sql` aplicada en staging; producción,
  no.

## Paso 0 — decisiones

Las de `encargos/lanzados/2026-11-26-compartido-1-seccion-chips-y-personas.md`, «Paso 0». Lo esencial: la misma cifra
arriba en los dos chips; una persona en varios grupos se junta solo por su cuenta (nunca por el nombre); el neto de cada
persona suma las deudas que su grupo ya enseña (con «Menos pagos» y «Ver en una moneda» del grupo), archivados incluidos;
«liquidada» es neto cero con al menos un gasto o pago contigo.

## Fuera (lotes 2 y 3)

- Abrir una persona (detalle con Gastos, Saldos y Estadísticas).
- Crear una persona ya marcada desde «Añadir persona», con el texto de su invitación (lote 3).
- La migración `g37_01` en producción y el Worker v4 desplegado: los decide Jürgen (orden: SQL → Worker → app).
- Invitar a una persona y la entrada sin grupo obligatorio.
- La tarjeta «Sin grupo» de la maqueta, en el chip Grupos: resume lo que solo existirá con el lote 3.

## Hecha cuando

- Un usuario con grupos ve «Compartido», cambia entre Grupos y Personas, ve sus personas con deudas y las liquidadas, y
  todo lo de Grupos sigue igual. Lo fijan `YalaTests/CompartidoSeccionPersonas/` y
  `YalaUITests/CompartidoSeccionPersonas/`.

## Device-QA (iPhone 14)

No frena el merge.

1. Abre Compartido con tus grupos de verdad: el título y la barra dicen «Compartido» y la lista de Grupos es la de antes.
2. Toca «Personas»: cada persona sale una vez, con los grupos donde comparten y lo que te debe o le debes en cada moneda.
   Compara una con su tarjeta de grupo: la cifra tiene que cuadrar.
3. Baja hasta «Ver liquidadas» (si tienes a alguien a mano) y ábrelo.
4. Cambia a Grupos y vuelve: «Nuevo grupo» y «Añadir persona» se turnan en la barra.
