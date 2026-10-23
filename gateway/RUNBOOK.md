# Gateway · runbook de despliegues pendientes

El Worker no se despliega solo: `deploy:staging` y `deploy:production` los corre Jürgen a mano (`README.md`, «Deploy»).
Aquí se apunta lo que está mergeado y espera despliegue, con cómo comprobarlo. Lo desplegado se borra de aquí.

**Nada pendiente** (2026-10-22). Los dos entornos corren `origin/2.2` en `5fb3a3f88`: staging `043cdff6`, producción
`2e2c05c4`. Los dos anuncian `manifestVersion 3`. Entraron así el manifest v2 y v3 (g18_01 y g21_01 aplicados antes en
cada base), el olvido del contador de uso en «Eliminar mi cuenta» y la ráfaga por minuto separada de la sincronización
(primera foto). Detalle en `docs/RUNBOOK-staging-ddl.md`, entradas g18_01 y g21_01.

**Sigue en pie el guard de `predeploy:*`** (`scripts/check-manifest-not-older.mjs`): para el despliegue si el árbol trae
un manifest más viejo que el desplegado. **`1.0` no trae ese guard**, así que desde `1.0` nada lo para: el Worker de
producción no se despliega desde `1.0` ni desde ninguna rama sin `manifest_version: 3`. Forzar desde 2.2:
`ALLOW_MANIFEST_DOWNGRADE=1`, y solo junto con los `*_rollback.sql`.
