---
id: adopt-orphan-with-a-fresh-hlc-beats-the-absent-leaders-edit
status: backlog
priority: low
area: "modo-nube, migración, adopt"
created: 2026-09-24
updated: 2026-10-08
source: "review adversarial de `claim-grants-a-takeover-after-the-leader-passed-the-cutover` (2026-09-24), lente de consumidores"
---

# La huérfana que sube el adopt gana a la edición que el líder ausente aún no subió

## El problema, en lenguaje de usuario

El teléfono A activa la nube, crea un gasto justo al final, lo edita sin conexión y se queda sin abrir Yala. El teléfono B
entra en la cuenta entretanto y sube ese gasto tal como lo vio en iCloud. Cuando A vuelve, su edición puede perder frente a
la copia que subió B, y un gasto que A borró puede reaparecer.

## Lo medido (2026-09-24, leyendo el código) e inferido

- Medido: el adopt sube sus huérfanas con un HLC acuñado en el momento del adopt (`CloudSyncEngine`, `clock.send(now:)`);
  el residual del líder lleva el HLC de la transacción del History en que se escribió.
- Medido: desde g16_04 B puede adoptar con la migración de A abierta (antes solo tras el `complete` de A, con el residual
  de A ya en el backend). Ese orden es nuevo.
- Inferido (sin reproducir): la edición de A, con HLC anterior, pierde el LWW contra la huérfana de B; un borrado de A
  resucita la fila. Sin duplicados: la fila conserva su `syncID`.

## Criterios de aceptación

- [ ] Medido con un test si la edición del líder que vuelve pierde contra la huérfana del adoptador, y decidido si se
      corrige o se acepta como residual.

## Medido en 2.1 (triage 2026-10-08)

- `CloudSyncEngine.enqueueSnapshotRows`, la vía de las huérfanas del adopt, sigue acuñando el HLC con `clock.send(now:)` en el momento de encolar.
- Sigue sin test que mida la edición del líder que vuelve contra la huérfana del adoptador: ningún test ni commit cita este ticket.

Triage 2026-10-08: abierto · low → low · el HLC fresco de las huérfanas sigue igual y falta el test que pide el criterio; secuencia rara (líder que edita sin red y no vuelve a abrir mientras otro adopta).
