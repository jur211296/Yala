---
id: nuevo-registro-exito-no-aparece
status: done
priority: high
area: "transactions, success-screen"
created: 2026-11-23
updated: 2026-11-23
card: tablero-nuevo-registro-la-pantalla-de-exito-no-a-z7wz
source: "Jürgen, 2026-11-23 7:28, iPhone con la build de TestFlight de 2.3"
---

# Nuevo registro: la pantalla de éxito no aparece al guardar

Jürgen, en su iPhone con la 2.3 de TestFlight: al guardar registros nuevos ya no sale la pantalla de éxito. Decisión del
mismo día: **la pantalla de éxito aparece siempre al guardar un registro nuevo, sin excepciones.**

## Hecho cuando

Al guardar cualquier registro nuevo (gasto, ingreso o transferencia) la pantalla de éxito aparece siempre, con pruebas que
lo cubren.

## Causa (medida)

No era el rediseño B1. Era una regla vieja de la 2.2 (UX 2.2 · L2-5, decidida el 14 y el 21-oct):
`TransactionSaveFeedbackLogic` solo daba la pantalla completa mientras la persona llevara 3 registros o menos
(`transactionsSavedCount`); desde el cuarto, el formulario se cerraba con el aviso breve «Gasto guardado · Editar ·
Deshacer». Con cualquier uso real ese contador pasa de 3 enseguida, y la pantalla de éxito «desaparecía».

## Resolución (2026-11-23)

- `TransactionSaveFeedbackLogic.feedback(isEdit:)`: registro nuevo → pantalla completa; edición → «Cambios guardados». Se
  retira el umbral y el caso del aviso breve.
- `NewTransactionView.finishSave` ya no lee el contador.
- «Agregar otro» no cambia: deja la hoja abierta con su aviso y no enseña la pantalla de éxito (otro flujo).
- «Hacer recurrente» no cambia: cierra con «Guardado · se repetirá cada mes». Pendiente de que Jürgen diga si también
  debe llevar la pantalla de éxito.
- Pruebas: `YalaTests/NuevoRegistroExitoSiempre/` (lógica y cableado) y
  `YalaUITests/NuevoRegistroExitoSiempre/` (gasto, ingreso y transferencia con 5 registros ya guardados; la de gasto,
  roja con el código anterior). Las pruebas del aviso con «Deshacer» pasan a provocarlo con «Hacer recurrente».
