---
id: group-expense-views-redesign
status: in-progress
priority: medium
area: "groups"
created: 2026-10-04
source: encargo 2026-10-04-mejorar-vistas-del-registro-en-grupos · tablero tablero-mejorar-vistas-del-registro-en-grupos-ix2y
---

# Rediseñar lo que se ve al abrir un gasto de grupo (detalle y edición)

## Por qué está parado

Espera la decisión de Jürgen entre A, B y C (lienzo:
https://claude.ai/artifact/V6KSmFBBVbxWRqEang9kPm). No se implementa hasta que elija.

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
