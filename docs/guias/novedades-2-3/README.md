# Guía de novedades 2.3 (TestFlight 2.3 (10))

Artifact para que Jürgen recorra como usuario antiguo o nuevo todo lo que cambió de la 2.2 publicada a la 2.3 (9) de
TestFlight, con lo que todavía no llegó, y deje notas «me gusta / mejorar / bug»: https://claude.ai/artifact/G74UBFLDowih9f2Rt5xaoS
(cuenta de la Mini: solo se publica desde la Mini). La versión de la 2.3 (7) queda en
https://claude.ai/artifact/3PhSbBHvWRMX3pohZw5Gty, de la cuenta de la Max.

Sus notas se guardan en la base del artifact, colección `notas` (un documento por ítem, con `veredicto`,
`comentario`, `titulo` y `area`). Una sesión las lee con `ArtifactData list` sobre esa URL.

## Qué hay aquí

- `inventario.json`: los 375 ítems (sin capturas). Campos: `id` (`<PR>-<n>`, estable entre versiones: las notas se
  guardan por id), `pr`, `titulo`, `area`, `seccion` (`nuevo` · `existente` · `ambos` · `fuera`), `tipo`, `ruta`,
  `que_cambio`, `por_que`, `estado` (`listo` · `activable` · `todavia_no` · `retirado` · `fuera`), `activar`, `pro`, `como_probar`,
  `orden` (recorrido del usuario nuevo), `build` (`1` a `8` · `web` · `no`), `nuevo_guia` y `cambio_guia` (qué cambió
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

## Actualización del 23-nov-2026 (TestFlight 2.3 (7))

- **Alcance:** los PR mergeados en `2.3` desde el corte de la 2.3 (2) hasta el de la 2.3 (7), que lleva también
  «Hacer recurrente» con pantalla de éxito. 131 PR revisados: 120 ítems nuevos de 78 PR que cambian la app y 52 PR
  descartados (web, pruebas, CI, docs, maquetas o proceso), con su motivo en `delta_2026_11_23.json`; el de Yala IA al
  100 % solo cambia un ítem existente (Navegadores conectados).
- **`build` de cada ítem nuevo:** la primera build de TestFlight que lo llevó (3 a 7), por la hora de merge frente al
  PR del número de cada build.
- **Cambios sobre ítems existentes:** 28, con su `cambio_guia`. Estado nuevo `retirado`: lo que llegó en una build y
  otra posterior reemplazó (las categorías sugeridas bajo el monto, la barra de búsqueda de Registros, la hoja «Ver
  los 7 pasos», entre otros). Importar de Splitwise o Tricount, voz/foto/Yala IA de Grupos y los filtros rápidos de
  Registros pasan a «listo» (entraron en la 2.3 (3)).
- **Medido en producción el 23-nov:** `/config` del gateway con `aiCloudExploreRolloutPercent` 100 y
  `appleWebSignInRolloutPercent` 0; `mcp.yala-app.pe` y `app.yala-app.pe` responden 200.
- **Notas de Jürgen:** la colección `notas` del artifact estaba vacía el 23-nov. Si dejó notas, quedaron solo en el
  navegador de su teléfono.
- **Capturas:** las 16 del iPhone 14 se conservan salvo la de los logos de pagos (mostraba los distintivos viejos), y
  se suman 6 del simulador con el seed `realista`: bienvenida, hoja de Salud financiera, Nuevo registro, Estadísticas,
  Pagos planificados con «Reusar» y Flujo de caja.
- **Script:** `actualizar_2026_11_23.py` aplica el delta (ya aplicado; no se repite).

## Actualización del 24-nov-2026 (TestFlight 2.3 (8))

- **Alcance:** los PR mergeados en `2.3` desde el corte de la 2.3 (7) hasta el de la 2.3 (8), con «Estadísticas ›
  Resumen: opción B» dentro. 18 PR revisados: 14 ítems nuevos (todos llegan en la 2.3 (8)), 10 cambios sobre ítems
  existentes con su `cambio_guia`, y 4 PR descartados con su motivo en `delta_2026_11_24.json`.
- **Conector de Grok:** el arreglo que deja conectar Grok Bot y Grok web es del servidor; no viaja en la build y
  espera su despliegue. Se anota en el ítem de «Ajustes › Tu IA».
- **Medido en producción el 24-nov:** `/config` del gateway igual que el 23-nov (`aiCloudExploreRolloutPercent` 100,
  `appleWebSignInRolloutPercent` 0); `mcp.yala-app.pe` y `app.yala-app.pe` responden 200.
- **Notas de Jürgen:** la colección `notas` estaba vacía el 24-nov en las dos guías (la de la Mini y la de la Max):
  no hay notas que marcar como resueltas.
- **Capturas:** se conservan las 21 anteriores y se suman 4 del simulador con el seed `realista` y la rama de la build:
  Estadísticas › Resumen, «Ver subcategorías» en el Flujo de dinero, Pagos planificados en línea de tiempo y Avisos del
  banco.
- **Recorrido del usuario antiguo:** suma 10 pasos con lo nuevo de la build 8.
- **Script:** `actualizar_2026_11_24.py` aplica el delta (ya aplicado; no se repite).

## Actualización del 25-nov-2026 (TestFlight 2.3 (9))

- **Alcance:** los PR mergeados en `2.3` desde el corte de la 2.3 (8) hasta el de la 2.3 (9). 7 PR revisados: 5 ítems
  nuevos (cuatro de la Bandeja sin duplicados y el paso 3 de Gmail del correo del banco), 6 cambios sobre ítems
  existentes con su `cambio_guia` y 2 PR descartados con su motivo en `delta_2026_11_25.json`.
- **iCloud:** la build 9 escribe `CD_InboxDraft.CD_joinRecordRaw`; Dan lo desplegó en Production en los dos contenedores
  el 25-nov (medido con `cktool` a las 06:24) antes de subirla.
- **Medido en producción el 25-nov:** `/config` del gateway igual que el 24-nov (`aiCloudExploreRolloutPercent` 100,
  `appleWebSignInRolloutPercent` 0); `mcp.yala-app.pe` y `app.yala-app.pe` responden 200.
- **Capturas:** se conservan las anteriores; la build 9 no suma capturas nuevas.
- **Recorrido del usuario antiguo:** suma 5 pasos (los cuatro de la Bandeja y Gmail).
- **Script:** `actualizar_2026_11_25.py` aplica el delta (ya aplicado; no se repite).

## Actualización del 25-nov-2026, tarde (TestFlight 2.3 (10))

- **Alcance:** los PR mergeados en `2.3` desde el corte de la 2.3 (9) hasta el de la 2.3 (10). 9 PR revisados: 5 ítems
  nuevos (bugs de cuenta en la nube, «Esto leí» y el chip de Estadísticas), 1 cambio sobre un ítem existente (Primeros
  pasos en un teléfono que tuvo Yala antes) y 6 PR descartados (número de build, servidor, CI y pruebas) con su motivo en
  `delta_2026_11_25_build10.json`.
- **iCloud:** la build 10 no escribe campos nuevos; el esquema de Producción de los dos contenedores coincide con el del
  repo (medido con `cktool export-schema` el 25-nov).
- **Capturas:** se conservan las anteriores y se suma 1 del simulador: «Esto leí» con la moneda cambiada a dólares.
- **Recorrido del usuario antiguo:** suma 2 pasos («Esto leí» con moneda y la hoja de varios).
- **Script:** `actualizar_2026_11_25_build10.py` aplica el delta (ya aplicado; no se repite).
