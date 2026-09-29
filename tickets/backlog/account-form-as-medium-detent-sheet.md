---
id: account-form-as-medium-detent-sheet
status: backlog
priority: medium
area: "accounts, ui"
created: 2026-09-09
source: idea Jürgen 2026-09-09
---

# El alta de cuenta, en un sheet de media altura al estilo del nuevo Apple Wallet

## La idea

Apoyar el alta de cuenta en el patrón de **sheet a media altura** (`presentationDetents([.medium])`)
que estrenó el nuevo Apple Wallet: se abre por encima de lo que estabas mirando, ocupa media
pantalla y se cierra sin sacarte de sitio, en vez de tomar la pantalla entera.

## Por qué importa

Crear o editar una cuenta es una tarea de dos campos que hoy se lleva toda la pantalla. A media
altura se vuelve un gesto: ves de dónde vienes, rellenas y vuelves.

## Lo medido (2026-09-09)

- **El alta de cuenta no declara detent ninguno**: `.sheet(item: $sheets.accountFormSheet)` en
  `Yala/App/Views/Panel/PanelSheetsModifier.swift:40`, y cero `presentationDetents` en
  `Yala/App/Views/Accounts/AccountFormView.swift` — así que toma el grande por defecto.
- **El alta de transacción tampoco**, y esto conviene saberlo antes de decidir: se presenta con
  `.presentationDetents([.large])` **explícito** en `DetailContainerView.swift:720` y
  `RecordsStandaloneView.swift:393`. El `[.medium]` que hay dentro de
  `NewTransactionView.swift:455` es de un sub-sheet interno, no del formulario.
- **El patrón ya existe en la app**: hay un helper de Design System,
  `DS.Adaptive.sheetDetents(_:)` (`Yala/App/Theme/DesignTokens.swift:436`; desde el 29-sep, en la vista,
  `.yalaSheetDetents(_:)`, que decide por la ventana), y ~16 sheets ya abren
  en `[.medium]`. No hay que inventar nada, sólo aplicarlo.

## La pregunta que falta (para Jürgen, antes del spec)

La idea llegó como «mejorar nuevo registro con detent medium **para cuentas**» y admite dos
lecturas: que pase a media altura el formulario **de cuenta**, o que lo haga el alta de
**transacción** («nuevo registro») y las cuentas vayan detrás. Medido arriba: hoy **ninguno de los
dos** usa medium, así que la pregunta sigue viva y no la contesta el código.

## Estado

Idea capturada, **sin spec**.

## Relacionados

- [[accounts-need-more-visibility-in-the-ui]] — la otra mitad del mismo deseo.
- [[panel-accounts-redesign]] — ya pedía «clic abre sheet, editar dentro del sheet».
