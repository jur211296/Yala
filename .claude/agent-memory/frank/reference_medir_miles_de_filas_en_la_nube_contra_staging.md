---
name: medir-miles-de-filas-en-la-nube-contra-staging
description: Cómo medir en una sesión cuánto tarda en viajar a otro dispositivo un lote grande (import, deshacer) en modo nube, sin teléfonos: dos stores en el simulador contra el Worker de staging.
metadata:
  type: reference
---

Medido el 2026-11-22 (lote 1 de Importar registros, en la Mini): `YalaTests/ImportarLote1/ImportarLote1NubeStagingTests`
copia el arnés de `CloudSyncE2EStagingTests` (dos stores en disco, `drainOnce` + `SyncPushClient.push` en A,
`pullAndApplyOnce` en bucle en B). Credenciales: `set -a; source ~/Secrets/yala-supabase-test/test-users.env; set +a` y
`TEST_RUNNER_YALA_CLOUD_E2E=1 TEST_RUNNER_USER_A_PASS="$USER_A_PASS"` delante del `sim-lock.sh -- xcodebuild … test`.

**How to apply:** pon a B al día ANTES de medir (si no, mides el corpus entero del usuario A). Con 3.000 filas la corrida
dura ~14 min: más de los 10 min del Bash, así que va en segundo plano. Deja las filas borradas en el usuario A (staging
no admite DELETE). Relacionado: [[secretos-de-staging-en-la-mini]].
