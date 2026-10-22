---
name: paso12-dominio-preferencias
description: PR #149 retira la puerta de dominio por sesión y apaga la entrada de M1; el paso 12 quedó redefinido por cuatro decisiones de Jürgen del 12-sep y una premisa suya que era imposible
metadata:
  type: project
---

**El paso 12 del rediseño de sesiones NO era ejecutable como estaba escrito, y ahora está partido.**
PR #149 (`encargo/2026-09-12-paso12-pra-sessiondefaults`) entrega solo el tercio mecánico.

**Why:** el ticket pedía derivar todo de dos ejes, pero **el eje 1 —«¿hay sesión privada?»— no tiene
fuente propia**: las seis veces que `hasPrivateSession` aparece en producción se construye como
`!SessionState.shared.isGroupInviteMode`, o sea a partir del flag que el propio ticket borra. Y dos
tests pinnean ese literal (`CloudSignOutFlowLogicTests:679` y `:683`). Medido el 2026-09-12.

**Las cuatro decisiones de Jürgen de ese día (mandan sobre el ticket, ya escritas dentro de él):**

1. **El eje 1 se escribe como MARCA POSITIVA persistida, con backfill de un arranque.** Descartado
   derivarlo de la presencia del store en disco: un gate derivado de una ausencia falla abierto. El
   backfill **no** contradice su derogación del punto 7 — aquélla retiraba estados legacy muertos;
   esto escribe por primera vez la celda normal, la de casi todo el parque.
2. **Dos entregas.** El tercio mecánico aparte porque es no-op demostrable.
3. **`StorageMode` se acota fuera del ticket**: no es dark (el gateway sirve `CLOUD_MODE_ROLLOUT_PERCENT=100`)
   y es el SSOT del mount.
4. **El cambio de Apple ID sale a ticket propio**: `apple-id-change-should-close-the-private-session`.

**El hallazgo que más caro habría salido, y vino de la review adversarial:** yo afirmé que el flag
compilado de M1 estaba en `false`. **Estaba en `true`** (`CloudSyncFlags.swift:498`); lo único que
apagaba la entrada era un percent de servidor, y **staging lo sirve al 100**. Retirar el aislamiento
dejando la entrada abierta convierte un rollout en una fuga. Se apagó el compilado en el mismo PR,
por decisión suya.

**How to apply:**

- **El alcance real del paso 12 es ~4× el escrito**: 115 ficheros de producción + 46 de tests, no 33.
  Y `git grep`, nunca `grep -r`: hay un worktree vivo DENTRO del árbol (`.claude/worktrees/`) que
  infla los conteos.
- Antes de seguir con el PR-B, **el eje 1 hay que diseñarlo**: dónde se persiste la marca, quién la
  escribe en el alta y cómo se hace el backfill. Sin eso, seis decisiones de producto —incluido qué
  se borra al cerrar sesión— cuelgan de nada.
- `SessionShape` **no puede llamarse `SessionState`**: ya existe un tipo con ese nombre, 815 líneas,
  que es otra cosa (notificaciones de inbox, deep links de widgets).
- Lo que queda vivo de `SessionDefaults` tras #149 es solo el cajón (`suiteName`, `suite`,
  `seedDeviceKeysIfNeeded`, `destroySuite`), y sus únicos consumidores son dos hooks de M1 en
  `SwiftDataConfiguration`. Cae entero con el PR-B.

Relacionado: [[project_rediseno_sesiones_dos_ejes]] · [[feedback_el_ancla_que_no_existe]] ·
[[feedback_mi_refutacion_falla_abierto]]
