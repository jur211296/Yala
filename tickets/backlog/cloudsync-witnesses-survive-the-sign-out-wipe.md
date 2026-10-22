---
id: cloudsync-witnesses-survive-the-sign-out-wipe
status: backlog
priority: low
area: "modo-nube, settings"
created: 2026-09-11
source: "review adversarial del plan del paso 9 (`session-exits-one-verb-per-session`)"
updated: 2026-10-08
---

# Auditar los testigos `cloudSync.*` que sobreviven al borrado de cierre de sesión

`DataWipeService.removeUserPreferenceKeys` excluye el prefijo `cloudSync.*` a propósito: esas claves las
gestiona el boot-wipe en su orden kill-safe. Desde el paso 9 ese boot-wipe cierra también sesiones
PRIVADAS, y un testigo de la vida que se cierra que sobreviva decide cosas de la siguiente. El paso 9
retiró los dos que encontró (`groupsOnlyNeutralMount` ya estaba; `privateChoseWithoutICloud` es nuevo).

## Qué hacer

Recorrer todas las claves `cloudSync.*` y clasificarlas: de la instalación (se quedan), de la vida que se
cierra (el hook las borra) o de la cuenta (no aplican). Un test por clase.

## Instancia medida (2026-09-27, review adversarial de `private-gate-back-from-found-keeps-a-resumed-arm`)

`cloudSync.icloudCorpusWipeArmed` sobrevive al cierre de sesión: el hook (`SwiftDataConfiguration`, junto a
`armNeutralMount`) retira «a medias» pero no el arm. Un arm que el arranque deja puesto para reintentar (fallo `.untouched`
del aviso tardío, `ContentView.runLateICloudMirrorCheck`) llega así a la vida siguiente, y `presentNextOnboardingScreen`
manda a la persona nueva a la puerta privada en vez de a la pantalla de inicio. La puerta vuelve a medir, así que no borra
nada sin preguntar. Leído en código, no recorrido.

## Medido en 2.1 (triage 2026-10-08)

- La instancia del 2026-09-27 sigue viva: el hook de cierre de `SwiftDataConfiguration` (junto a `armNeutralMount`) retira `clearICloudCorpusWipeLeftHalfway`, `clearICloudCorpusWipeCancelledInCloudNotice` y `clearICloudCorpusWipeWaiver`, pero no llama a `clearICloudCorpusWipeArm`, así que `cloudSync.icloudCorpusWipeArmed` pasa a la vida siguiente.
- La auditoría completa (clasificar todas las claves `cloudSync.*` con un test por clase) sigue sin hacerse; los commits posteriores (`b26cebed2`, `9e5b6b0bf`) añadieron marcas nuevas sin ella.

Triage 2026-10-08: abierto · low → low · `cloudSync.icloudCorpusWipeArmed` sigue sobreviviendo al hook de cierre; la puerta vuelve a medir y no borra sin preguntar.
