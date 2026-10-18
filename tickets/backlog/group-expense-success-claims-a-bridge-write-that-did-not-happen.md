---
id: group-expense-success-claims-a-bridge-write-that-did-not-happen
status: backlog
priority: low
area: "groups, bridge, expense-form"
created: 2026-10-18
updated: 2026-10-18
source: "auditoría UX 2.2 · L13-3 (review adversarial de la implementación)"
---

# La pantalla de «¡Gasto agregado!» puede decir que se apuntó algo que el puente no escribió

Desde L13-3 la pantalla de éxito de un gasto de grupo dice qué se apuntó en tus finanzas
(`GroupExpenseSuccessLogic.personalOutcome`): «−S/ 150 en Cuenta Principal», «Te espera en la Bandeja» o «Tu parte,
S/ 40, en tus finanzas». La decisión espeja las ramas de `GroupTransactionBridge.bridgeExpense`, pero sin leer lo que el
puente hizo de verdad. Hay seis casos en los que el puente no escribe nada y la pantalla lo afirma igual:

- el dominio de Grupos está sellado en este teléfono tras «Empezar de cero»;
- el grupo está oculto;
- el gasto está en el libro de conservados al desasociar;
- no se resuelve el miembro propio;
- el puente aún no tiene contexto;
- `bridgeExpense` lanza un error.

Son casos raros. Lo encontró la review adversarial del 2026-10-18; las ediciones con el puente encendido ya se corrigieron
en ese mismo PR.

## Hecho cuando

La línea de «qué se apuntó» sale de lo que el puente devolvió (o se calla cuando no escribió), con test de cada uno de los
seis casos.
