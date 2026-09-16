---
id: cloud-signout-drops-unsynced-preference-changes-without-counting-them
status: backlog
priority: low
area: "modo-nube, sesión, preferencias"
created: 2026-09-15
updated: 2026-09-15
source: "hallazgo de `cloud-phone-without-app-attest-cannot-sign-out-with-personal-changes` (2026-09-15)"
---

# Al cerrar sesión en la nube, los cambios de preferencias sin subir se pierden sin que ningún aviso los cuente

## El problema, en lenguaje de usuario

Cambio una preferencia —la divisa, un aviso— y cierro sesión antes de que suba. El cierre termina sin decir nada, y en mi
otro teléfono esa preferencia sigue como estaba.

## Lo medido (leído en el código, sin ejecutar)

- El cierre en la nube solo espera al outbox del dominio: `CloudMigrationController.pushAllPendingForSignOut` decide con
  `livePendingUploadCount()`, que cuenta filas de `SyncOutbox`. Las preferencias viven aparte, en `PrefsOutbox`, y suben en
  el paso 5.5 de cada ciclo (`CloudSyncRuntime.syncPrefsOnce`).
- Si esa subida falla, las entradas se quedan, y el teardown del cierre las borra sin mirarlas:
  `CloudSyncRuntime.teardownGuestSession` → `prefsOutbox?.purgeAll()`. Nada bloquea ni avisa.
- Con un teléfono sin App Attest, las preferencias no suben nunca: el ciclo corta en su puerta antes del paso 5.5. Desde el
  2026-09-15 el aviso de ese cierre cuenta los cambios que se pierden, y la cifra solo incluye las filas de `SyncOutbox`.
- Sin medir: cuántas preferencias quedan así en campo. No hay canario del purgado.

## Lo que hay que decidir

1. Esperar también al outbox de preferencias en el cierre, como al del dominio.
2. Contarlas en los avisos de pérdida, sin bloquear.
3. Aceptarlo: son preferencias, y la cuenta conserva su último valor subido.

## Relación con otros tickets

- `cloud-phone-without-app-attest-cannot-sign-out-with-personal-changes` — el aviso cuya cifra no las incluye.
- `prefs-synced-keys-upload-not-download` y `language-override-bypasses-the-cloud-prefs-channel` — el mismo canal.
