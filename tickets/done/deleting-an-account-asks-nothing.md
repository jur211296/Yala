---
id: deleting-an-account-asks-nothing
status: backlog
area: accounts
priority: high
created: 2026-10-13
updated: 2026-10-13
source: docs/ux/mapa-de-flujos-2.2.md (auditoría UX 2.2, fase 1)
---

# Borrar una cuenta no pide confirmación

**Clase:** bug de UX con riesgo de datos. Lo revisa el lote 7 de la auditoría UX 2.2.

## Qué pasa

En el formulario de una cuenta en edición, el botón «Eliminar cuenta» borra al primer toque y cierra la hoja.
No hay alerta ni diálogo de confirmación. Los registros de esa cuenta se quedan sin cuenta.

## Medido en el código (2026-10-13, rama 2.2 @ e7e9feda8)

- `Yala/App/Views/Accounts/AccountFormView.swift`: el `Button(role: .destructive)` llama a `handleDeleteTapped()`,
  que llama directamente a `deletionService.deleteAccount(account)` y a `dismiss()`.
- `Yala/Services/EntityDeletionService.swift` `deleteAccount`: borra la cuenta y re-codifica los presupuestos afectados.
  No toca los registros.

## Por qué importa

Para el resto de borrados de la app hay confirmación (presupuestos, categorías, etiquetas, grupos). Un toque
accidental al fondo del formulario se lleva una cuenta y descuelga su historial, sin forma de deshacer.

## Hecho cuando

Borrar una cuenta pide confirmación y dice qué pasa con sus registros (cuántos y a dónde van), con XCUITest
que cubra cancelar y confirmar.
