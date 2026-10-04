---
id: group-expense-views-redesign
status: qa
updated: 2026-10-04
priority: medium
area: "groups"
created: 2026-10-04
source: encargo 2026-10-04-mejorar-vistas-del-registro-en-grupos · tablero tablero-mejorar-vistas-del-registro-en-grupos-ix2y
---

# Rediseñar lo que se ve al abrir un gasto de grupo (detalle y edición)

## Qué se decidió

- **Propuesta B** (Jürgen, 2026-10-04), con la referencia que mandó de otra app: barra partida por persona
  con su monto debajo.
- **«B con aire»**, el mismo día, tras ver la B construida «demasiado apretada»: grupo y fecha en una línea
  pequeña y las secciones plegables, abiertas de una en una.
- **Frase tipo Splitwise**, tras un feedback externo («Splitwise es más fácil; la barra es ruido a primera
  vista»): el editor plegado es la frase «Pagado por [Ana] y dividido [en partes iguales]», con las dos piezas
  tocables. La barra solo aparece con «Reparto» abierto; en el detalle, solo si el reparto no es igual. En
  grupos de 2, una pastilla con la frase entera abre las opciones rápidas, y «Más opciones» despliega el reparto.
- **Piezas tocables con fondo** (última vuelta): en reposo, el tinte del tema; abiertas, el tema sólido.
  Aprobado con ese único cambio.
- Lienzo de las propuestas: https://claude.ai/artifact/V6KSmFBBVbxWRqEang9kPm. Capturas finales en
  `~/Claude/worktrees/_capturas/2026-10-04-mejorar-vistas-del-registro-en-grupos/final/`.

## Qué cambia para el usuario

- **Al tocar un gasto** (detalle): «Tu parte» en una frase («Le debes a Ana» · S/ 40, o «Caro te debe»),
  y la lista de quién pone cuánto, con quién pagó. Si el reparto no es igual, además la barra con un color por
  persona. Si el gasto llegó a tu registro personal, una fila «En tus finanzas» con la cuenta y el monto.
- **Al editar o crear**: grupo y fecha en una línea pequeña. Debajo del monto, «Pagado por [Ana] y dividido
  [en partes iguales]»; cada pieza abre ahí mismo los avatares o el reparto (Iguales · % · Monto · Partes, la
  barra y el cuadre). Sin hojas aparte. «Tú» sin paréntesis; color del tema en lugar del turquesa.
- **Grupos de 2**: una pastilla «Pagado por ti y dividido en partes iguales» que abre las cuatro opciones
  rápidas; «Más opciones» despliega el reparto completo.
- **Si pagaste tú**, la cuenta se pide a la vista y, si falta, lo dice («Selecciona una cuenta» con aviso).

## Guion de QA en el iPhone (Jürgen)

**Dónde:** en el **TestFlight 15** (versión 2.1, subido el 2026-10-04 desde `2.1`), con tus grupos de verdad.
Yala Dev no sirve: no tiene grupos de 3. Es el paso R11 de `qa/guion-tanda.md`.

1. Grupos › un grupo de 3 › toca un gasto con partes iguales que pagó otra persona: «Tu parte · Le debes a
   <nombre>» y la lista de las tres personas, **sin barra**.
2. Toca **Editar**: grupo y fecha en una línea pequeña; debajo del monto, «Pagado por <nombre> y dividido en
   partes iguales», con las dos piezas en el tinte del tema.
3. Toca la pieza del modo: se abre el reparto (pieza en tema sólido) con la barra. Cambia a **Porcentaje** y
   pon montos distintos; toca la pieza del pagador: el reparto se pliega y salen los avatares. Elige otra
   persona y **Guardar**. Vuelve a abrir el gasto: el detalle muestra ahora la barra.
4. En un grupo de 2: la pastilla con la frase entera; tócala, elige «Pagó <otra> · es todo tuyo» y mira la
   frase. Vuelve a tocarla › **Más opciones**: se abre el reparto completo.
5. Un gasto que pagaste tú sin cuenta enlazada: «Cuenta · Selecciona una cuenta» con aviso y Guardar apagado;
   al elegir cuenta, Guardar se enciende.
6. Repite 1-2 con tamaño de texto grande y en modo claro (la frase pasa a dos líneas si no cabe).

## Qué se ve hoy (recorrido del 2026-10-04, base `2653f06fa`)

Capturas en `~/Claude/worktrees/_capturas/2026-10-04-mejorar-vistas-del-registro-en-grupos/antes-*.png`
(seed `grupos`, iPhone 17 Pro).

- **Abrir un gasto.** Hoja media con el total, «Mercado · 15 oct. 2026» y tres filas: Pagado por,
  tu parte (Te prestaron / Prestaste) y Tipo de división. **No dice cuánto pone cada persona**: para
  verlo hay que entrar a Editar y abrir la hoja de división.
- **Si pagaste tú**, la fila dice «Pagado por (Tú)», con paréntesis. En la hoja de división se lee
  «Tú (Tú)».
- **Editar.** Hoja grande con un hueco vacío arriba (unos 300 pt entre el chip del grupo y la fecha),
  chips «Pagado por» y «Dividido» en turquesa —fuera del color del tema— y la categoría sola abajo.
  Pagador y reparto se cambian en hojas aparte; la de división tiene el control segmentado en
  turquesa y los checks en índigo.
- **Grupo de dos.** Un chip-resumen («Caro te debe S/ 200.00») en lugar de las dos líneas.

## Las tres propuestas

Mismos datos en todas: «Mercado», S/ 120.00, pagó Ana, a partes iguales entre Ana, Beto y tú.

| | Detalle | Edición | Tamaño |
|---|---|---|---|
| **A** | El de hoy + tarjeta «Reparto» (cada persona y su monto, quién pagó) | El de hoy sin hueco, chips en el color del tema | El más pequeño |
| **B** | «Tu parte» arriba en una frase, barra y lista del reparto, y «En tus finanzas» (cuenta y categoría) cuando hay movimiento personal enlazado | Quién pagó con avatares y el reparto dentro del formulario (Iguales · % · Monto · Partes) | Medio: reusa el VM y la lógica de división |
| **C** | Un solo registro: cada dato se toca y se cambia ahí; «Guardar cambios / Descartar» al tocar algo | — (es la misma pantalla) | El más grande: rehace el flujo de dos fases y sus XCUITest |

Común a las tres: «Tú» sin paréntesis; color del tema en vez del turquesa.

Recomendación (por producto): **B**. El detalle contesta lo que se abre a buscar —quién pone qué y qué
te toca— y la edición deja de ir y volver entre hojas. Separa ver de editar a propósito: un gasto de
grupo lo ven todos los miembros, y C hace fácil cambiarlo sin querer.

## Hallazgos que salieron (con ticket propio)

- `group-expense-edit-save-disabled-without-saying-the-account-is-missing` (medium)

## Para quien implemente

- Detalle: `GroupExpenseDetailSheet`. Ya recibe `share`, `bridgeTransaction` y `memberNameLookup`;
  para el reparto completo hacen falta los `SplitShare` del gasto (el padre es `GroupDetailView`).
- Edición: `GroupExpenseFormView` + `GroupExpenseViewModel`. B mueve a línea lo que hoy hacen
  `MemberPickerView` y `GroupSplitSelectorView`; la lógica de reparto (`purgeEmptyParticipants`,
  balanceo) no cambia.
- XCUITest que fijan el flujo actual: `GroupsSmokeUITests` (`group_expense_detail_edit`,
  `group_expense_split_chip`, `group_expense_paidby_chip`, `group_expense_twoperson_chip`).
