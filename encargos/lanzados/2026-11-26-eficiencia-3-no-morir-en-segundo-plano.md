Yala
# Eficiencia 3: Yala no muere en segundo plano (cortar recálculos al irse y Spotlight fuera del hilo principal)
---
toca: Yala/App/AppBootstrapper.swift,Yala/Services/Spotlight/SpotlightIndexService.swift,Yala/App/ViewModels/PanelViewModel.swift,Yala/App/Views/Panel/PanelView.swift,YalaTests/EficienciaSegundoPlano,docs/qa/rendimiento-iphone14-2026-11-26/despues-eficiencia-3-no-morir-en-segundo-plano/,tickets/backlog/2026-11-26-eficiencia-3-no-morir-en-segundo-plano.md,tickets/done/2026-11-26-eficiencia-3-no-morir-en-segundo-plano.md
esfuerzo: high
cierre: cierra-sola
release: no
pruebas-ui: no
depende: Yala/eficiencia-1-volver-sin-recalcular
---

Lote del plan de eficiencia que salió del análisis de calentamiento, batería y scroll en el iPhone 14. Espera al lote 1 porque comparte `AppBootstrapper.swift`, `PanelView.swift` y la lógica de la vuelta.

## Qué se pide
1. Al pasar a `.background`, cancelar o pausar los recálculos y el reindexado en vuelo (ya hay `setBackground`; hoy no corta un `performCalculation` ya empezado).
2. Spotlight fuera del hilo principal (contexto propio) y por tramos (`SpotlightIndexService.desiredEntries` lee todos los movimientos con sus relaciones).
3. Tirar para actualizar: sin recálculo completo si nada cambió (firma).
4. Medir el arranque en frío tras un cierre: Panel listo en < 3 s con 16 k.
5. Revisar los `.ips` de TestFlight y los reportes de errores si hay `0x8BADF00D` en segundo plano en producción, y anotar lo que encuentres (sin tocar nada de producción).
- Pruebas nuevas en `YalaTests/EficienciaSegundoPlano/`.

## Mejora esperada y cómo se mide
Cero cierres del vigilante en 10 ciclos con salidas a los 2-5 s de volver. Medir con el guion de ciclos con fuera = 3 s y `devicectl … systemCrashLogs` sin `Yala-*.ips` ni `cpu_resource` nuevos.

## Qué NO hay que tocar
- Nada fuera de `toca:`; si necesitas otro archivo, anótalo en «Saltado o asumido sin preguntar» con el motivo.
- Lo de los otros lotes del plan (cada uno va en su sesión).

## Contexto común
- Informe de origen: `docs/qa/rendimiento-iphone14-2026-11-26/README.md` (sección «Lotes propuestos» y «Causas raíz, ordenadas por impacto medido»), con datos en `docs/qa/rendimiento-iphone14-2026-11-26/datos/` y los guiones de medición en `docs/qa/rendimiento-iphone14-2026-11-26/scripts/` (por ejemplo `scripts/pasada.sh`). Lo hizo la sesión «Análisis profundo de calentamiento, batería y scroll en iPhone 14» el 26-nov midiendo en el iPhone 14 de Jürgen con un almacén de 16.004 movimientos. Si al arrancar el informe todavía no está en `origin/2.3`, búscalo en la rama `encargo/2026-11-26-analisis-rendimiento-calentamiento-scroll-iphone14`.
- Pedido de Jürgen (26-nov, 10:44 Lima): «encola los 6 lotes de mejoras de eficiencia de la sesión del calor». Él siente que Yala calienta el teléfono al ir y volver de otra app y que el scroll al volver va lento.
- Las líneas citadas en el informe son de `origin/2.3` en `b5c6e98c5`; confírmalas en el código de hoy, porque otros lotes ya pueden haber cambiado esos archivos.

## Cómo medir
- **Antes y después en el iPhone 14 real** («iPhone de JURGEN», conectado por cable a la Max) con DeviceMCP, `devicectl` y `xcrun xctrace`, usando los mismos guiones y el mismo almacén de 16 k que el informe, para que las cifras sean comparables. Las cifras de rendimiento solo valen si salen del iPhone 14; el simulador sirve para desarrollar y para las pruebas, no como evidencia de rendimiento. En la Max puedes usar un segundo simulador además del de otra sesión; en la Mini, uno solo. Apaga y limpia los que enciendas.
- Al arrancar, comprueba con `xcrun devicectl device info lockState --device 00008110-001A35A6267A401E` que el iPhone no está bloqueado. Si está bloqueado o no responde: en semiautónomo, pídele a Jürgen que lo desbloquee (y que ponga Bloqueo automático en «Nunca» mientras dure la prueba) y espera con la sesión viva; en nocturno, termina lo que no necesite el teléfono, deja checkpoint y anota la medición pendiente como `BLOQUEANTE:` con el error exacto. Si el iPhone lo está usando otra sesión, espera en tramos cortos con aviso.
- Deja las mediciones de este lote en `docs/qa/rendimiento-iphone14-2026-11-26/despues-<slug-del-lote>/` (resumen numérico antes/después y extractos de trazas, nada pesado) y compáralas contra la «mejora esperada» del informe.

## Cómo trabajar
- Arranca sobre `origin/2.3`, en tu worktree. Cada cambio con su prueba en la carpeta de pruebas de este lote. Textos nuevos, si hiciera falta alguno, solo en una tabla de strings propia del lote en cada `.lproj`, nunca en `Localizable.strings`.
- Pipeline serial: limpiar, build `xcodebuild -jobs 2` sin simulador encendido, encender un simulador, pruebas, apagarlo; para medir, compilación de perfilado (Release con símbolos) instalada como Yala Dev en el iPhone 14. Corre solo las pruebas que toca el cambio; la suite completa, una sola vez al final. 2 timeouts = inestable, se anota y se sigue. Tope de 30 min en pruebas de interfaz. Ninguna espera de más de 3 min sin escribir avance.
- Antes de compilar en iOS mira la carga: si otra sesión compila en la misma máquina y la carga pasa los núcleos, espera en tramos cortos con aviso.
- Nada de cambios de esquema de SwiftData, CloudKit ni Supabase; si crees que hace falta uno, es pregunta vital para Jürgen. No cambies lo que la persona ve, salvo lo que diga el lote.
- Da siempre una descripción corta, en español y sobre el tema, a cada comando Bash.
- No borres datos del iPhone ni la base de desarrollo.

## Cierre
- Un solo PR a `2.3`, sin firma de IA, con auto-merge activado; cierra sin quedarte esperando: los conflictos los relanza el vigía.
- Entrega: artifact visual de Claude con antes/después medido en el iPhone 14 (cifras y gráficas), qué se cambió y qué quedó pendiente; enlázalo en el cierre. No Markdown, PDF ni documento de puro texto.
- Cierre con `/cerrar-total` cuando el trabajo esté completo y el modo lo permita. En semiautónomo, lo vital se le pregunta a Jürgen y se espera con la sesión viva. En nocturno, lo vital se preserva con checkpoint recuperable y card «Espera decisión» para Jürgen, sin mergear lo incompleto.
- El cierre lleva «Saltado o asumido sin preguntar» y «Decidido sin consultar», cada uno con motivo o «Nada». `BLOQUEANTE:` solo si algo de verdad no puede seguir sin Jürgen. Español neutro latinoamericano.

## Paso 0 — decisiones (resueltas en semiautónomo por Frank, 26-nov 16:30 Lima)

1. **Base: la rama del lote 1, no `2.3`.** El encargo declara `depende:` del lote 1, que sigue abierto en cola de
   auto-merge y toca los mismos ficheros. La rama nace de `origin/encargo/2026-11-26-eficiencia-1-volver-sin-recalcular`
   y se rebasa sobre `origin/2.3` antes del PR (si el lote 1 ya entró, sus commits caen solos).
2. **Cortar el cálculo del Panel en vuelo = etapas que ceden el hilo.** `performCalculation` era síncrono: el freno
   (`setBackground`) no podía correr hasta que terminaba. Se parte en sus cinco bloques naturales (tendencia,
   presupuestos + pagos, salud, gastos por cuenta, hero) con una pausa de 1 ms entre bloques; entre uno y otro se mira
   cancelación, freno, primer plano y almacén. Partir cada bloque por dentro es el lote 4 (no se toca).
3. **Spotlight «fuera del hilo principal»: solo lo que se puede.** Los `@Model` son del main actor
   (`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`): leerlos en otro hilo exige quitarles el aislamiento a los modelos, fuera
   de `toca:` y de este lote. Se hace: lectura por tramos de 1.000 en un contexto propio por tramo (las filas no se
   quedan vivas en el de la app), pausa entre tramos, y entradas + plan + estado guardado calculados fuera del hilo
   principal. Al pasar a segundo plano se corta lo que esté en vuelo y se olvida la firma.
4. **Tirar para actualizar** usa la misma firma que volver al Panel (`refreshIfStale`). Sigue sincronizando preferencias.
5. **Arranque en frío (< 3 s con 16 k):** se mide antes y después; si no llega, se anota para el lote 4 (los dos cálculos
   completos del arranque son suyos).
6. **`.ips` y Sentry:** solo lectura (`asc`, API de Sentry con el token del llavero); nada de producción se toca.
7. **Contador de depuración**: `debugCalculationRuns` sigue contando cálculos empezados (lo usan tests existentes); se
   añade `debugCalculationsCompleted` para los terminados.
