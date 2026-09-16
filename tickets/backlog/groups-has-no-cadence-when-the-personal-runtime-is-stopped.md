---
id: groups-has-no-cadence-when-the-personal-runtime-is-stopped
status: backlog
priority: low
area: "groups, modo-nube, sync"
created: 2026-09-16
source: "review adversarial de `groups-loop-in-backoff-ignores-the-return-to-foreground` (2026-09-16), lente del criterio"
---

# Con el motor personal parado, los grupos dejan de sincronizar y volver a la app no lo arregla

## El problema, en lenguaje de usuario

En Modo Nube, si el motor personal se detiene —cuenta suspendida, o este teléfono deja de poder demostrar que
es un iPhone de verdad— los cambios de mis grupos dejan de subir y de bajar también. Salir y volver a la app
no los mueve.

## Lo medido (2026-09-16, leído en el código, sin ejecutar)

Con el runtime personal encendido y el dominio elegible, Grupos **no tiene loop propio**: su ciclo viaja como
paso 5.6 del ciclo personal.

- `Yala/Services/CloudSync/Groups/GroupsSyncClient.swift:432` — `startIfEligible` se abstiene del loop propio
  con `CloudSyncFlags.syncRuntimeEnabled && CloudSyncRuntime.canRunDomain()`.
- `CloudSyncRuntime.canRunDomain()` (`Yala/Services/CloudSync/CloudSyncRuntime.swift:250`) mira el modo, la
  fase de migración, el par `.cloud`+mirror y los dos mount-mismatch. **No mira el `state` del runtime.**
- `CloudSyncRuntime.handleBecameActive` (`:407-409`) retorna SIN ciclar en `.stoppedUntilRelaunch`, `.idle` y
  `.idleSignedOut`.

⇒ con el runtime en `.stoppedUntilRelaunch` —403 de cuenta no disponible, o attest terminal— el gate de
abstención sigue diciendo «el personal cadencia» aunque no cadencie nadie: Grupos no arranca su loop y el
personal no lo mueve. El foreground no lo rescata, porque ahí quien decide es el runtime personal y su
`.stoppedUntilRelaunch` está pegado a propósito (S6).

## Por qué no lo arregló el ticket que lo encontró

`groups-loop-in-backoff-ignores-the-return-to-foreground` despierta el loop de Grupos cuando ese loop EXISTE.
Aquí no existe: el canal se abstuvo. Es la misma promesa —volver a Yala mueve mis grupos— rota por otro sitio,
y arreglarla toca a qué le pregunta el gate, no al sueño.

## Por dónde va

- El gate de abstención debería preguntar si el runtime personal **va a cadenciar de verdad**, no solo si el
  dominio es elegible: `canRunDomain()` más un estado que cadencie.
- Cuidado con lo contrario: si Grupos arranca su loop propio y el personal vuelve a `.running`, hay que evitar
  los dos loops. El docblock de `startIfEligible` dice que las transiciones las media el relaunch en v1, y ese
  es el diseño que habría que revisar entero.
- Mídase antes la población: cuánta gente está en `.cloud` con el runtime parado. Puede ser de laboratorio, y
  entonces no vale el riesgo de tocar el gate.

## Relación con otros tickets

- `groups-loop-in-backoff-ignores-the-return-to-foreground` — el hermano que cerró la mitad del loop vivo.
- `cloud-tab-does-not-say-this-phone-cannot-sync-personal-data` — el aviso de ese mismo motor parado.
