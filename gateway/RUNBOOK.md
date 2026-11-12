# Gateway · runbook de despliegues pendientes

El Worker no se despliega solo: `deploy:staging` y `deploy:production` los corre Jürgen a mano (`README.md`, «Deploy»).
Aquí se apunta lo que está mergeado y espera despliegue, con cómo comprobarlo. Lo desplegado se borra de aquí.

**Nada pendiente** (2026-11-02). Los dos entornos corren el manifest de Grupos **v3** (g29_01, card xi74: el autor de
gastos y liquidaciones), desplegado desde la rama `encargo/2026-11-02-grupos-autor-del-gasto` sobre `origin/2.2`, sin
más cambios de gateway que ése: staging `453090c6`, producción `9b651957`. Personal sigue en v6. Detalle en
`docs/RUNBOOK-staging-ddl.md`, entrada g29_01.

**Sigue en pie el guard de `predeploy:*`** (`scripts/check-manifest-not-older.mjs`): para el despliegue si el árbol trae
un manifest más viejo que el desplegado. **`1.0` no trae ese guard**, así que desde `1.0` nada lo para: el Worker de
producción no se despliega desde `1.0` ni desde ninguna rama sin `manifest_version: 3`. Forzar desde 2.2:
`ALLOW_MANIFEST_DOWNGRADE=1`, y solo junto con los `*_rollback.sql`.
