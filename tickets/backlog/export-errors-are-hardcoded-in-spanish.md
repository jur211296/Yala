---
id: export-errors-are-hardcoded-in-spanish
status: backlog
priority: low
area: "export, l10n"
created: 2026-09-15
updated: 2026-09-15
source: "review adversarial de `cloud-phone-without-app-attest-cannot-sign-out-with-personal-changes` (2026-09-15)"
---

# Los errores del asistente de exportación salen en español en todos los idiomas

## El problema, en lenguaje de usuario

Tengo la app en inglés. Exporto mis datos, algo falla, y el aviso me dice «No se encontraron transacciones que cumplan los
filtros seleccionados.».

## Lo medido (leído en el código, sin ejecutar)

- `TransactionsExportError.errorDescription` devuelve tres literales en español, sin `ls()`
  (`Yala/Utils/TransactionsExportService.swift`, el `enum` de errores).
- El asistente pinta `recoverySuggestion ?? localizedDescription` del error (`ExportSummaryStepView`), así que ese texto
  llega tal cual a los 16 idiomas. El título del aviso sí está traducido (`export.exportError`).
- La exportación que ofrece el aviso de cerrar sesión en la nube sin App Attest ya no los usa: tiene sus dos textos propios
  desde el 2026-09-15 (`SignOutBlockedCopy.personalExportFailureMessage`).

## Lo que hay que decidir

1. Traducir los tres textos y que el asistente los lea con `ls()`.
2. Que el asistente use textos propios por caso, como el aviso del cierre.

## Relación con otros tickets

- `cloud-phone-without-app-attest-cannot-sign-out-with-personal-changes` — donde se vio.
