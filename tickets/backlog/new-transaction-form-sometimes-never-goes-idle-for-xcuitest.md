---
id: new-transaction-form-sometimes-never-goes-idle-for-xcuitest
status: backlog
priority: medium
area: "testing, transactions"
created: 2026-11-05
updated: 2026-11-05
source: "lote T3 de XCUITest intermitentes en iPhone (encargo 2026-11-05-lote-t3-xcuitest-intermitentes-iphone)"
---

# A veces, tras escribir el importe en «Nuevo registro», la app no queda en reposo para XCUITest

## Lo medido (2026-11-05, iOS 27.2)

- **iPhone SE**, `EdgeCasesUITests.test_extremeMinimumAmountSaves`, 1 de 3 iteraciones: desde `Type '0.01'` cada gesto
  esperó 60 s a «Wait for com.jurgenschmidt.yala.dev to idle» y acabó en «App animations complete notification not
  received, will attempt to continue». 16 esperas así; el caso pasó en **999,8 s** (los otros dos, ~43 s).
- **iPhone 17 Pro**, `ExternalEntryForeignSheetUITests.test_halfFilledFormInAnotherTab_trialExpired_waitsForTheForm`,
  1 de 3: lo mismo desde `Type '1234'`, 7 esperas de 60 s; pasó en **454 s** (los otros, ~35 s).
- En los dos casos empieza al escribir en el campo del importe de «Nuevo registro», y no vuelve a reposo hasta salir.
  No hay `repeatForever`, `TimelineView` ni `phaseAnimator` en `Yala/App/Views/Transactions`.

- **iPhone 17 Pro, en el gate del mismo día**, `TransactionFormDecided02UITests.test_afterThreeRecords_openingAnotherFormRetiresTheNotice`:
  desde `Type '25'`, 8 esperas de 60 s; el aviso «guardado» (`saved_record_notice`, 3 s de plazo) ya se había ido cuando
  llegó la consulta, el caso falló y XCUITest **se colgó casi 2 h** en «Requesting snapshot of accessibility hierarchy»
  hasta que se mató la corrida. En ese tiempo el simulador acumuló 16 GB de adjuntos en el `tmp/Attachments` de su daemon
  de tests.

## Por qué importa

Ya no es solo tiempo: tumba casos con plazos cortos y puede colgar una corrida entera (el gate, la nocturna). Además, una corrida que debía durar 40 s dura 8-16 min. En el CI eso se come el
tope de las tandas de UI, y un caso con un plazo propio corto puede caer por el tiempo perdido delante.

## Qué mirar

Qué sigue animando con el campo del importe enfocado en esa corrida (el instrumento: `log stream` del simulador con
`CA` / `UIKit` y el vídeo de la corrida con `simctl io recordVideo`, porque un caso en verde no deja vídeo). Candidatos sin
medir: la animación del importe al escribir, el cursor, o algo del Panel de debajo.
