---
name: aviso-attest-personal-en-dos-superficies
description: PR #177 — el aviso fijo del canal personal cerró el hermano de #176, y de paso arregló un check verde «Todo sincronizado» que salía con el motor parado; el «agujero» del 401 de attest se midió el 16-sep y no era del aviso
metadata:
  type: project
---

**El aviso fijo de «este teléfono no puede sincronizar tus datos» ya existe para el canal personal, en
dos superficies: el Panel y `syncStatusSection` de «Dónde viven tus datos».** PR #177 (2026-09-15),
cierra `cloud-tab-does-not-say-this-phone-cannot-sync-personal-data` en `done`, sin device-QA.

**Why.** Era el hermano de #176 (Grupos) que el propio #176 dejó anotado. La sorpresa fue la segunda
superficie: la sección de estado de Ajustes **pintaba un check verde «Todo al día» con el motor
parado**, porque su `else` daba por bueno todo estado que `refreshSyncBanner` no enumera y el attest
terminal deja el runtime en `.stoppedUntilRelaunch`, no en `.stoppedUntilSignIn`. Eso convirtió una
decisión de «¿Panel o Ajustes?» en «las dos, y la de Ajustes no es un extra».

**How to apply.**

- **Si vuelve a salir el tema, lo que manda es la rule**: `.claude/rules/gateway-attest.md` tiene las
  cuatro condiciones, el porqué de cada término y los residuales. No lo deduzcas otra vez.
- **El «agujero conocido» se midió el 2026-09-16 y no era un agujero del aviso**: el 401 de attest del canal
  personal llega después de que la puerta consiguiera el token, así que no es un teléfono sin App Attest y el
  aviso (que culpa al teléfono) no le corresponde. Ya se lee pasajero, con canario y sin tocar la racha. Si
  alguien reporta «no sale el aviso», la pregunta abierta es `cloud-attest-notice-does-not-cover-a-gateway-rejected-token`
  ([[tras-la-puerta-el-error-es-otro]]).
- **No hay seam de uitest para `storageMode == .cloud`** y eso acota la cobertura de toda esta familia
  (precedente: `SessionExitsPerCellUITests`). Si alguna vez merece la pena crearlo, es ticket propio:
  escribir ese modo cambia el montaje del store personal.
- Dejó además `cloud-hydration-spinner-never-gives-up-without-attest` (el spinner «Descargando tus
  datos…» que giraba al lado del aviso). **Cerrado el 2026-09-17 en el PR #189**:
  [[spinner-hidratacion-se-rinde]].

Relacionado: [[project_grupos_avisa_sin_attest]] · [[project_telefono_sin_attest_veredicto_y_salida]] ·
[[feedback_el_copy_que_promete_se_recorre]] · [[feedback_el_termino_nuevo_desarma_el_test_viejo]]
