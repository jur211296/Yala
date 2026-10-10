---
id: storage-mode-unknown-raw-reads-as-icloud
status: backlog
priority: very-low
area: "modo-nube, almacenamiento"
created: 2026-09-25
updated: 2026-10-08
source: "review adversarial de `an-undecodable-migration-phase-reads-as-never-started` (2026-09-25)"
---

# Si una versión anterior de Yala no reconoce el modo de almacenamiento guardado, lo lee como iCloud

## El problema, en lenguaje de usuario

Es el mismo caso que cerró `an-undecodable-migration-phase-reads-as-never-started`, en la otra mitad de la decisión: si
una versión más nueva de Yala guardara un modo de almacenamiento que una anterior no conoce, la anterior lo leería como
«iCloud». Con el registro de la migración diciendo «terminado» y el modo leído como iCloud, la app montaría el espejo de
iCloud sobre datos que ya viven en la nube.

## Por qué pasa (medido leyendo `StorageModePersistence.read` en `CloudSyncFlags.swift`; el escenario es INFERIDO)

Un `rawValue` desconocido de `storageMode` cae a `.icloud`. El comentario del propio fichero avisa de que el par cruzado
(modo contra fase) da doble escritura. Hoy `StorageMode` no tiene más casos que los que existen, así que solo muerde con
un downgrade tras añadir uno.

## Criterios de aceptación

- [ ] Un modo desconocido no se lee como `.icloud` en silencio; se decide hacia el lado que no monta nada que escriba.
- [ ] Test con un raw desconocido + control.

## Medido en 2.1 (triage 2026-10-08)

- `StorageModePersistence.read` (`CloudSyncFlags.swift`) sigue devolviendo `.icloud` cuando el `rawValue` no decodifica. Hoy `StorageMode` solo tiene los casos que se escriben, así que no es alcanzable hasta que se añada uno y alguien baje de versión.

Triage 2026-10-08: abierto · low → very-low · sigue igual, pero hoy no es alcanzable: hace falta un modo nuevo en una versión futura y volver a una anterior.
