---
id: restore-found-state-leaves-no-breadcrumb
status: backlog
priority: low
area: "welcome, icloud, restore, observabilidad"
created: 2026-09-21
updated: 2026-09-21
source: "review adversarial de `restore-treats-budgets-and-groups-as-no-data` (2026-09-21), hallazgo 6 de la lente de consumidores"
---

# El único desenlace del restore que no deja rastro es el que sale bien

## Medido (2026-09-21)

`RestoreBreadcrumb` se emite en `.wiped` (`WelcomeRestoreView.swift:195`), `.importIncomplete`
(`:118`), `.cloudPaused` (`:257`), `.cloudUnverified` (`:260`), en el asentamiento
(`RestoreProgressView.settled`) y en el destino (`ContentView.swift:847`). **En `.found` no hay
ninguno.**

## Por qué importa, y por qué ahora

El bug de este flujo reproduce en **CloudKit Production**, donde no hay dSYM ni simulador: el log
es la única ventana, y eso está escrito en `RestoreImportSettlement.settledEmpty` como la razón de
existir de la señal entera.

Desde `restore-treats-budgets-and-groups-as-no-data` (2026-09-21) los presupuestos cuentan para
`hasAnyData`, así que un teléfono que antes registraba `importIncomplete` puede ahora irse por
`.found` **sin registrar nada** hasta el `destination`. La serie de `importIncomplete` cambió de
definición con ese build y no hay ninguna que recoja lo que se fue.

## Qué haría falta

Un `RestoreBreadcrumb.found(...)` con las cifras que decidieron, para poder distinguir en Console
«se encontró corpus de iCloud» de «se encontró poco y se siguió igual». Es aditivo y no cambia
ninguna decisión.

## Relación con otros tickets

- `restore-treats-budgets-and-groups-as-no-data` — de donde sale.
- `restore-says-no-data-when-the-icloud-import-never-settled` — el que creó la señal.
