---
id: adopt-after-the-cutover-needs-a-marker-the-leader-never-exported
status: backlog
priority: medium
area: "modo-nube, migración, adopt"
created: 2026-09-24
updated: 2026-09-24
source: "review adversarial de `claim-grants-a-takeover-after-the-leader-passed-the-cutover` (2026-09-24), lente de consumidores"
---

# El adopt tras el cutover pide un marcador que el líder puede no haber exportado

## El problema, en lenguaje de usuario

El teléfono A llega al paso en que el servidor ya da la activación por buena, pero se queda sin conexión antes de dejar su
marca en iCloud. Más de una hora después, el teléfono B quiere entrar en la cuenta y tiene algo escrito que la nube no
conoce. B no puede entrar: la app le dice que no puede comprobar que esos datos son de esta cuenta. Si A vuelve, se
arregla solo; si A no vuelve (o su activación se deshizo porque la marca nunca llegó a iCloud), B no entra nunca con sus
datos.

## Lo medido (2026-09-24, leyendo el código)

- `migrated_at` lo estampa `confirmCutoverServer` en `cutover(.pending) → .serverConfirmed`, ANTES de escribir y exportar
  el marcador (`MigrationStateMachine.swift`, el bloque «cutover — STRICT order»).
- Desde g16_04, con `migrated_at` puesto y el lease vencido, `claim_account` da `existing_stable` → adopt. Antes daba el
  relevo, y la identidad de la ida probaba el linaje por identidades compartidas (`checkForwardLineage`), sin marcador.
- El adopt exige el marcador de la cuenta en el store local en cuanto hay una fila huérfana o sin identidad fuera de las
  tablas exentas (`MigrationWorkExecutor.adoptLineageGate` / `adoptLineageProven`); sin él, `.lineageUnproven`.
- Dos casos: (1) A dormido en `cutover(.markerWritten)` con el marcador sin exportar — B bloqueado hasta que A exporte; (2)
  A agota el tope del marcador (`markerExportStalled`) y vuelve a iCloud BORRANDO el marcador, con `migrated_at` puesto y
  la migración abierta en el servidor (residual ya escrito en ese `case`) — B bloqueado mientras A no reintente.
- En `cutover(.mirrorOff)` (el «cierra y reabre Yala») el marcador ya está exportado: ahí el adopt de B sí prueba linaje.

## Candidatas (decisión técnica, sin medir)

- Cliente: en el adopt, sin marcador, aceptar como prueba de linaje lo mismo que la ida (`checkForwardLineage`: alguna
  identidad compartida con el backend). Hay que medir que no reabre `adopt-uploads-a-foreign-corpus-without-a-lineage-check`.
- Servidor: una señal de «marcador exportado» (una acción de `migration_progress`) y que la rama de g16_04 la exija; sin
  ella, el relevo de antes. Cambia el protocolo del líder.

## Criterios de aceptación

- [ ] Un segundo teléfono con datos propios entra en una cuenta cuyo líder pasó el cutover del servidor sin exportar el
      marcador, o hay una salida escrita para ese caso.

Relacionado, no duplicado: `cutover-marker-without-a-session-locks-out-the-second-device` (el marcador existe pero con el
hash vacío). Las dos candidatas de aquí cerrarían también ese.
