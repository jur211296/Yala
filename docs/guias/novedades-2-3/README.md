# Guía de novedades 2.3 (TestFlight 2.3 (1))

Artifact para que Jürgen recorra como usuario todo lo que cambió de la 2.2 publicada a la 2.3 (1) de TestFlight
y deje notas «me gusta / mejorar / bug»: https://claude.ai/artifact/G74UBFLDowih9f2Rt5xaoS

Sus notas se guardan en la base del artifact, colección `notas` (un documento por ítem, con `veredicto`,
`comentario`, `titulo` y `area`). Una sesión las lee con `ArtifactData list` sobre esa URL.

## Qué hay aquí

- `inventario.json`: los 214 ítems (sin capturas). Campos: `id` (`<PR>-<n>`), `pr`, `titulo`, `area`, `seccion`
  (`nuevo` · `existente` · `ambos` · `fuera`), `tipo`, `ruta`, `que_cambio`, `por_que`, `estado` (`listo` ·
  `activable` · `todavia_no` · `fuera`), `activar`, `pro`, `como_probar`, `orden`.
- `plantilla.html`: la página; `__DATA__` se sustituye por el inventario con capturas.
- `armar_datos.py`: las correcciones aplicadas sobre la clasificación de los PR (estados medidos en producción,
  ítems que faltaban, lo que no entra en el build). Lee ficheros intermedios que no se guardan en el repo.

## Cómo se armó (15-nov-2026)

- **Alcance:** PR mergeados en `2.3` entre el tag `v2.2` y el corte del build, el merge del barrido final
  (commit `a64a2bafb`): el archivo de 2.3 (1) se hizo desde el bump de versión, que lo contiene. Se excluyen los
  merges de 2.2 en 2.3 (ya publicados) y los PR solo de tests, docs o proceso.
- **Fuera del build:** los PR mergeados después del corte (nube: cifrado y fotos a la vista, volver a tu iCloud;
  arreglo de Grupos en Yala web) y los PR abiertos de 2.3.
- **Estados medidos en producción el 15-nov:** `/config` del gateway de producción (`appleWebSignInRolloutPercent`
  0, `aiCloudExploreRolloutPercent` 0); rutas `/mail/*` presentes (401 con ruta existente, 404 sin ella); MX de
  `yalainbox.com` en Cloudflare. El gateway de producción corre la base `3b8529af1` (RUNBOOK-staging-ddl):
  incluye recibos de Grupos, `paymentHint` y gastos hormiga con IA, pero no el cupo de 5 recibos al día de Grupos.
- **Sin verificar:** la migración D1 y la regla de Email Routing del correo del banco en producción.
