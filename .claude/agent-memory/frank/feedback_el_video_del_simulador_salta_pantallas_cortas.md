---
name: el-video-del-simulador-salta-pantallas-cortas
description: simctl recordVideo durante un XCUITest no capturó la pantalla de éxito que el test SÍ tocó; para un «después» de una pantalla breve, condúcela a mano y haz screenshot
metadata:
  type: feedback
---

Un `simctl io recordVideo` grabado durante una corrida de XCUITest **no sirve** para capturar una pantalla que dura
menos de un segundo. Medido el 2026-10-07: el test encontró y pulsó `transaction_success_accept` (0,8 s entre
aparecer y el tap, según el log), y el vídeo, volcado fotograma a fotograma con `-fps_mode passthrough`, pasa del
formulario al Panel sin un solo fotograma de la pantalla de éxito.

**Why:** la grabación salta fotogramas bajo carga y el test pulsa en cuanto el elemento existe. El vídeo sí vale para
el «antes» de un fallo, porque el estado roto se queda quieto hasta el timeout.

**How to apply:** para el «después» de una pantalla breve, lanza la app con los mismos `-uitest-*` del test
(`simctl launch … -uitest -uitest-reset -uitest-skip-onboarding -uitest-seed minimal -AppleLanguages "(es)"
-AppleLocale es_PE`), condúcela con XcodeBuildMCP (`snapshot_ui` + `tap`/`type_text`) y `simctl io … screenshot`.
Son ~8 llamadas. Relacionado: [[capturas-sobreviven-en-worktrees-capturas]].
