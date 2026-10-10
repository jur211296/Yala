---
id: settings-sign-out-scope-says-groups-stay-in-an-account-that-may-not-exist
status: backlog
priority: low
area: "modo-nube, sesiones, copy"
created: 2026-09-29
source: "review adversarial del PR #302 (`apple-id-close-notice-does-not-say-what-else-the-close-does`)"
updated: 2026-10-08
---

# La hoja de «Cerrar sesión» de Ajustes dice que los grupos siguen en una cuenta que quizá no existe

## Qué pasa

En la celda C (sesión privada sin cuenta en la nube) cuyo teléfono guarda grupos del canal nuevo —una sesión de grupos
que caducó—, Ajustes enseña la hoja del «equipo» (`DestructiveScopeLogic.signOutOperation(forgetsBackendGroups: true)`),
y su fila de grupos dice **«Este dispositivo olvidará tus grupos (siguen en tu cuenta)»** (`settings.scopeForgetGroups`).

Eso no siempre es cierto en esa celda:

- Si la cuenta de grupos se **borró** desde otro dispositivo, las filas del teléfono son huérfanas: no siguen en ninguna
  cuenta.
- Si las filas son de **otra cuenta** (el caso que abrió el bloqueo `groupsChangesFromAnotherAccount`, 2026-09-28), no
  están en la cuenta de quien lee.

En la celda D sí es cierto: hay sesión viva y el cierre sube los grupos antes de borrar.

## Por qué no entró en #302

#302 arregló la hoja del cambio de Apple ID y allí la frase se escribió sin decir dónde siguen los grupos («También se
quitan los grupos que hay en este teléfono»). Ajustes es otra pantalla con otra pregunta. El matiz es de lectura
(inferido de leer el código, no reproducido en un dispositivo).

## Lo que hay que decidir

¿La fila de grupos de la celda C deja de afirmar dónde siguen, o se mantiene porque el caso de cuenta borrada o ajena es
marginal? Si cambia, es una fila propia para `forgetsBackendGroups` en C, distinta de la de D.

## Medido en 2.1 (triage 2026-10-08)

- `DestructiveScopeSheet.swift` sigue pintando `L10n.Settings.scopeForgetGroups` en sus tres ramas, con «(siguen en tu cuenta)» en los 7 idiomas. Ningún commit lo toca tras el que abrió el ticket (`9c9fb7ccc`).
- Recomendación para la decisión: una fila propia para la celda C que diga que el teléfono olvida sus grupos sin afirmar dónde siguen. Con eso sigue en low: el cierre no hace perder nada que siguiera a salvo, solo lo describe mal.

Triage 2026-10-08: abierto · low → low · la frase sigue igual en la celda C, pero solo miente cuando la cuenta de grupos se borró o es de otra persona, y el cierre no pierde nada que no estuviera ya fuera de esa cuenta.
