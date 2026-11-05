---
id: restore-inside-full-mode-activation-cannot-read-the-beacon
status: backlog
priority: low
area: "welcome, restore, faro"
created: 2026-11-05
updated: 2026-11-05
source: "review adversarial del lote N3 (2026-11-05)"
---

# Restaurar dentro de «Activar Yala completo» no puede leer el faro

## Qué le pasa al usuario

Desde una sesión solo de grupos, «Activar Yala completo» → «Restaurar» con la búsqueda vacía nunca dice que la nube está en pausa, aunque el Apple ID tenga cuenta en la nube.

## Medido (2026-11-05)

`FullModeActivationView.swift` monta `WelcomeRestoreView` desde la sesión solo grupos. Ahí la puerta del iCloud-KV (`OwnerKeyValueStore`) está cerrada, y `yala.cloud.accountLinked` no es una de las claves que se leen con la puerta cerrada: `CloudBeacon().isCloudAccountLinked` da `false` siempre. El repintado del faro tardío (lote N3) escucha bien, pero lee `false`.

## Qué hay que decidir

Si el faro entra en las señales que se leen con la puerta cerrada (es del Apple ID, no de la persona), o se acepta el residual.
