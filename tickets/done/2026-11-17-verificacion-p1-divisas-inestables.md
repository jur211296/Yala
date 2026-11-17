---
id: 2026-11-17-verificacion-p1-divisas-inestables
status: done
priority: medium
area: "tests, fx, ci"
created: 2026-11-17
updated: 2026-11-17
card: tablero-unit-inestable-storeremotechange-dropsth-kxh2
source: "propuesta de verificación del 17-nov (P1, primera parte), aprobada por Jürgen"
---

# Las pruebas de la caché de divisas caían a ratos en el CI y pasaban al repetirlas

En dos semanas hubo 65 rescates «Rescatado al repetirlo» en el job `tests`, 60 de la familia `CurrencyConverter*`
(`CurrencyConverterLatestRateArrivalTests` 39 en tres casos, `CurrencyConverterRowMemoTests` 16). Incluye la card
«Unit inestable: storeRemoteChange_dropsTheCache cayó una vez en el CI y pasó al reintento».

## Hecho cuando

La familia entera pasa al menos 50 veces seguidas sin un rojo, con la causa raíz arreglada y sin subir esperas ni
añadir reintentos.

## Causa (medida)

- **Dónde caía.** Las anotaciones de las últimas 120 corridas del CI dan 17 rescates de la familia, y los logs dicen lo
  mismo en todos: el control «la caché está llena» (`_testCacheState != nil`, líneas 92, 104 y 116 de
  `LatestRateArrivalTests`), `_testCacheState?["PEN"] == 3.8` (línea 76), `cacheAfterFirst == cacheAfterSecond` en
  `CacheTests`, y en `RowMemoTests` «Ninguna de 5 pasadas salió sin avisos ajenos», con un único
  `NSPersistentStoreRemoteChangeNotification · NSPersistentStoreCoordinator · otro hilo` en CADA una de las 5.
- **Qué la vaciaba.** El conversor vacía su caché y su memoria de filas con cualquier `ModelContext.didSave`,
  `.NSPersistentStoreRemoteChange` o aviso de tasas del proceso, a propósito (`currency-fx.md`). Las suites del CI corren
  en serie, así que el aviso no venía de otra suite: una sonda en el simulador (40 guardados en un store en memoria con
  solo `ExchangeRate`) mide que **cada `save()` postea exactamente un `.NSPersistentStoreRemoteChange` en otro hilo, en
  carrera con la vuelta del `save()`**: de 2 ms antes a 0,17 ms después en la Max. En el runner del CI llega más tarde y
  cae entre el llenado de la caché y el control. Es el eco del `save()` del propio fixture; por eso las 5 ventanas de
  `RowMemoTests` salían sucias.
- **No es un bug de producción.** Retirar la caché con ese eco es el diseño (cuesta una relectura). El comentario del
  conversor que decía que en un store en memoria ese aviso llegaba «síncrono» era falso y se corrigió.

## Resolución

- `CurrencyConverter.init(notificationCenter:)`, con `.default` por defecto: la app no cambia. Las pruebas que miran si
  la caché o la memoria SIGUEN llenas le dan un centro propio y postean ahí (`LatestRateArrivalTests` «cada aviso por
  separado», `RowMemoTests`, `CacheTests`). El eco de sus guardados ya no las alcanza.
- `RowMemoTests` deja de repetir la ventana hasta 5 veces (`ForeignDropRecorder`/`inACleanWindow`): era un reintento.
- El cableado con el centro real queda fijado aparte, con aserciones que un aviso de más no cambia:
  `theAppsConverters_listenOnTheDefaultCenter` (el conversor por defecto y el compartido oyen `.default`; control: el
  seam sí lo cambia) y `eachNotificationOnTheDefaultCenter_dropsTheCache` (los tres avisos en el centro real vacían la
  caché). `todaysRowSavedByAnotherContext` sigue con un guardado de verdad; su `== 3.8` pasa a «no se queda con 3.0».
- Regla nueva en `.claude/rules/testing.md`.

## Medición (Max, iPhone 17 Pro iOS 27.2, en serie como el CI, 10 de 12 núcleos ocupados)

- **Antes** (`origin/2.3`): la familia entera (8 suites) 50 veces seguidas → **1 corrida roja de 50**,
  `storeRemoteChange_dropsTheCache` en la línea 92, el mismo control que en el CI. En local el eco casi siempre llega
  antes; en el CI cayó en 17 de 120 corridas.
- **Después**: 50 veces seguidas → **50 de 50 en verde**, 0 rojos, 0 fallos de infraestructura (49 pruebas por corrida,
  2.450 en total). Con una tasa local tan baja, 0/50 no lo prueba por sí solo: lo cierra que el eco ya no llega a las
  pruebas que miran «sigue llena».
- **`-test-iterations` no sirve con Swift Testing** en este Xcode (27.2): la corrida pedida con 60 iteraciones ejecutó
  cada prueba una vez. Las repeticiones son 50 invocaciones de `xcodebuild test-without-building`.
- **Mutantes** sobre el conversor, cada uno con rojo: centro ignorado (usa siempre `.default`) → 6 pruebas; sin el
  observador de cambio del store → 3; sin el de guardado → 4.
- **Observar**: dos semanas, hasta el 2026-12-01, sin un rescate de `CurrencyConverter*` en el CI. Si aparece, se reabre
  con su log.
