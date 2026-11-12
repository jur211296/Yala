---
id: deleting-an-account-asks-nothing
status: done
area: accounts
priority: high
created: 2026-10-13
updated: 2026-10-14
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

## Resuelto (2026-10-14, auditoría UX 2.2 lote 7, B1)

«Eliminar cuenta» abre una alerta: «¿Eliminar «Cuenta Principal»?» y «Tiene 2,202 registros. No se borran: quedan en
Registros, sin cuenta. Si solo quieres dejar de verla, archívala. No se puede deshacer.» (sin registros: «No tiene
registros. No se puede deshacer.»). Lo que dice está medido en el simulador: tras confirmar, los registros siguen en la
lista de Registros, sin nombre de cuenta. Plural en los 12 idiomas base; las variantes con la forma plural.
XCUITest `AccountsCrudUITests.test_deleteAccount_asksFirst_cancelKeepsIt_confirmDeletesIt` (cancelar la deja, confirmar
la borra). Capturas en `~/Claude/entregas/Yala--auditoria-ux-2-2-lote-7-cuentas-categorias/capturas/` (`7.4-*` antes,
`B1-*` después).

Visto por el camino y no tocado: al quedarse sin cuenta, esos registros dejan de sumar en el resumen de Registros
(el ingreso y el gasto de arriba los excluyen), aunque sigan en la lista. El aviso no promete nada sobre los totales.
