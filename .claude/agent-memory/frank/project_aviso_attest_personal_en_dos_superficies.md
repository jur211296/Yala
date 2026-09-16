---
name: aviso-attest-personal-en-dos-superficies
description: PR #177 — el aviso fijo del canal personal cerró el hermano de #176, y de paso arregló un check verde «Todo al día» que salía con el motor parado; queda un agujero conocido (el 401 de attest que el canal personal no distingue)
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
- **El agujero conocido, y es el que más importa**: el canal personal **no distingue su propio 401 de
  attest** (lo mapea a `.sessionExpired`) y `resolveAttest` borra la racha con un token cacheado que el
  gateway rechaza ⇒ **el aviso no puede salir para esa población, por construcción**. Está anotado
  dentro de `personal-sync-reads-an-offline-token-refresh-as-a-session-expiry`, con la instrucción de
  comprobar que el aviso aparece al arreglarlo. Si alguien reporta «no sale el aviso», mira ahí primero.
- **No hay seam de uitest para `storageMode == .cloud`** y eso acota la cobertura de toda esta familia
  (precedente: `SessionExitsPerCellUITests`). Si alguna vez merece la pena crearlo, es ticket propio:
  escribir ese modo cambia el montaje del store personal.
- Deja además `cloud-hydration-spinner-never-gives-up-without-attest` (el spinner «Descargando tus
  datos…» que gira para siempre y ahora contradice al aviso).

Relacionado: [[project_grupos_avisa_sin_attest]] · [[project_telefono_sin_attest_veredicto_y_salida]] ·
[[feedback_el_copy_que_promete_se_recorre]] · [[feedback_el_termino_nuevo_desarma_el_test_viejo]]
