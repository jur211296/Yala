---
id: import-activity-flag-describes-the-process-not-the-search
status: backlog
priority: low
area: "welcome, icloud, restore"
created: 2026-09-20
updated: 2026-09-20
source: "review adversarial (lente de poblaciones) de `restore-says-no-data-when-the-icloud-import-never-settled`, 2026-09-20"
---

# La señal que decide el desenlace de Restaurar habla de todo el proceso, no de esta búsqueda

## Medido (2026-09-20)

`iCloudSyncService.hasObservedImportActivity` es **monótono dentro del proceso**: se declara en
`iCloudSyncService.swift:92`, su única escritura de producción es `:346` (siempre a `true`) y el
único sitio que lo baja es `_testReset()` (`:701`). Una vez encendido, lo está hasta que la app
muere.

`RestoreImportSettlement` está documentado como «lo que sabemos del import **de esta espera**», y
`RestoreProgressView` lo alimenta con ese flag leído del singleton, **sin acotarlo a la ventana de
la búsqueda**. Dos consecuencias medibles:

- **En el segundo consumidor el flag puede llegar encendido de antes.** A
  `FullModeActivationView` (que monta el mismo `WelcomeRestoreView`) solo se llega tras un
  relanzamiento con el espejo adjunto, y ese arranque dispara eventos de import antes de que la
  persona navegue hasta «Restaurar».
- **`.inconclusive` deja de ser alcanzable** para el resto de la sesión en cuanto salta un solo
  evento, así que el desenlace pensado para el usuario nuevo desaparece para él si hubo cualquier
  actividad previa.

## Por qué es `low`

El daño hoy está acotado: el flag solo lo enciende un `.importEvent`, que implica que había algo
remoto, así que decir «los datos siguen llegando» rara vez es falso — y el caso en el que sí lo era
(el import que FALLA) se cerró el 2026-09-20 con el término de error vigente. Lo que queda es que
la señal responde a una pregunta más ancha que la que dice responder.

## Criterios de aceptación

- [ ] O la señal se acota a la ventana de la búsqueda (un contador o una marca por flujo), o su
      docblock deja de prometer que describe «esta espera».
- [ ] El recorrido desde `FullModeActivationView` queda medido, no inferido.

## Relación con otros tickets

- `restore-says-no-data-when-the-icloud-import-never-settled` — de donde sale.
