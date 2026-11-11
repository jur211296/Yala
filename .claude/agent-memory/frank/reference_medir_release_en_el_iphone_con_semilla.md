---
name: medir-release-en-el-iphone-con-semilla
description: Cómo medir con Instruments en el iPhone 14 una build optimizada con la semilla de diez años sin tocar los datos reales de Yala Dev, y qué falla por el camino (xctrace, simbolización, capturas)
metadata:
  type: reference
---

Medido el 2026-11-11 (lote de Estadísticas con diez años, Mini, iPhone 14 por cable, iOS 27.2):

- **La semilla y el almacén de pruebas solo existen con `DEBUG`.** Truco que funcionó: copia aparte del código
  (`git archive HEAD` o `rsync` del worktree a la scratchpad) con `DEBUG` añadido SOLO en la línea de `Release-Dev` del
  `project.pbxproj` (`SWIFT_ACTIVE_COMPILATION_CONDITIONS = "DEBUG DEV_BUILD $(inherited)"`). Pasarlo por línea de
  comandos lo aplica también a los paquetes SPM y `IssueReporting` no compila. Copia `Secrets.xcconfig` a mano.
- **Se lanza con `-uitest -uitest-skip-onboarding -uitest-seed pesado` y SIN `-uitest-reset`** (Device MCP `launch_app`):
  siembra en `YalaModel-UITest`, aparte de los datos reales; el reset borraría preferencias del aparato. Sin `-uitest`
  abre el almacén real (sale la bienvenida): no lo toques. Instalar encima (`devicectl device install app`) conserva lo
  sembrado. El período vuelve a «Este mes» en cada lanzamiento.
- **xctrace**: `--attach <pid>` (de `devicectl device info processes`); por nombre («Yala Dev») a veces no lo encuentra,
  y justo después de otra grabación da «Cannot find process» unos segundos: reintenta. En el simulador xctrace no se
  engancha (sandbox): ahí, `sample`. La tabla útil es `potential-hangs` + `time-profile` (`tagged-backtrace`, no
  `backtrace`). `--all-processes` no se deja simbolizar con el dSYM.
- **`save_screenshot` con `overwrite` pide aprobación en Device MCP** y caduca a los 2 min: usa un nombre nuevo.
  Las notificaciones (Slack) salen en las capturas: mira antes de guardar. El OCR de `tap_text` falla a ratos
  (`CRImageReaderError`): usa refs de `list_elements` o ids.

Relacionado: [[conducir-el-iphone-real-con-device-mcp]], [[medir-un-cuelgue-de-tipos-con-sample]].
