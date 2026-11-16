# Guía de novedades 2.3 (TestFlight 2.3 (2))

Artifact para que Jürgen recorra como usuario antiguo o nuevo todo lo que cambió de la 2.2 publicada a la 2.3 (2) de
TestFlight, con lo que todavía no llegó, y deje notas «me gusta / mejorar / bug»: https://claude.ai/artifact/G74UBFLDowih9f2Rt5xaoS

Sus notas se guardan en la base del artifact, colección `notas` (un documento por ítem, con `veredicto`,
`comentario`, `titulo` y `area`). Una sesión las lee con `ArtifactData list` sobre esa URL.

## Qué hay aquí

- `inventario.json`: los 241 ítems (sin capturas). Campos: `id` (`<PR>-<n>`, estable entre versiones: las notas se
  guardan por id), `pr`, `titulo`, `area`, `seccion` (`nuevo` · `existente` · `ambos` · `fuera`), `tipo`, `ruta`,
  `que_cambio`, `por_que`, `estado` (`listo` · `activable` · `todavia_no` · `fuera`), `activar`, `pro`, `como_probar`,
  `orden` (recorrido del usuario nuevo), `build` (`1` · `2` · `web` · `no`), `nuevo_guia` y `cambio_guia` (qué cambió
  desde la versión anterior de la guía).
- `plantilla.html`: la página; `__DATA__` se sustituye por el inventario con capturas. Los dos recorridos guiados
  (`ROUTES.existente` y `ROUTES.nuevo`) van escritos ahí, por id.
- `construir.py <salida.html> [capturas.json]`: arma la página. Las capturas (un objeto id → data URI) no se guardan:
  se sacan del bloque `<script id="data">` del artifact publicado.
- `actualizar_2026_11_16.py`: el delta del 16-nov aplicado sobre el inventario del 15-nov (ya aplicado; no se repite).
  La próxima actualización: un script igual, que primero ponga `nuevo_guia` a false en todo.
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

## Actualización del 16-nov-2026 (TestFlight 2.3 (2))

- **Corte de la 2.3 (2):** el merge de Yala web en producción (`b2db13a35`), base del PR del número de build. Subida a
  TestFlight el 16-nov a las 16:30 (Lima). Entran los PR mergeados entre los dos cortes: nube (cifrado y fotos, volver a
  iCloud, cambiar de cuenta), archivar cuentas, Grupos (lote 01), VoiceOver, Tendencias, calendario, categorías,
  nota de salud, hacer recurrente, «Tu saldo hoy», ficha de cuenta, tarjetas personalizables, bugs del barrido y la parte
  de la app de «Tu IA registra en Yala».
- **Todavía no en TestFlight:** importar de Splitwise o Tricount (mergeado a las 16:51, después del corte), y en cola de
  auto-merge voz/foto/Yala IA de Grupos como en personal y los filtros rápidos de Registros.
- **Medido en producción el 16-nov:** `/config` del gateway igual que el 15-nov (`appleWebSignInRolloutPercent` 0);
  conector de IA de producción sin desplegar (Cloudflare 1042 en `yala-mcp-production`); Yala web 200 en
  `app.yala-app.pe`. El cupo de recibos de Grupos se da por activo porque el gateway de producción se desplegó desde 2.3
  ese día (deducido del despliegue, sin probar 6 recibos).
