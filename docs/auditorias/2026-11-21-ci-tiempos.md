# Tiempos del CI de Yala (21-nov-2026)

**Artifact con los gráficos, la tabla de jobs y las propuestas:**
https://claude.ai/artifact/7WNMaTYGyeDUkAbUXve2oM

Solo medición: esta auditoría no cambió workflows, runners, hooks ni tests.

## Alcance y método

- API de Actions de `jur211296/Yala`, workflow `QA` (`qa.yml`): los últimos **150 runs de PR**
  (16 al 21-nov; 149 contra 2.3, uno contra 1.0, ninguno contra 2.2), **60 runs del push a 2.3**
  y las **12 nocturnas** de la semana. Tiempos por job y por paso.
- Tiempos por caso de test: log completo del job `tests` del run 44890016796 (push a 2.3 del 21-nov).
- «Resultado del PR»: desde que nace el run hasta que terminan los tres checks que exige el ruleset
  de 2.3 (`tests`, `coverage-index`, `gateway`). Sin runs cancelados.
- La web de Astro no tiene workflow en GitHub (la construye Vercel): no entra.

## Lo medido

| Qué | p50 | p95 |
|---|---:|---:|
| PR que compila la app (116 de 150) | 66 min | 101 min |
| PR solo de docs (34 de 150) | 3,5 min | 4,3 min |
| Push a 2.3 tras el merge | 64 min | 125 min |
| Job `tests`: espera en cola | 0,1 | 45,6 |
| Job `tests`: preparación (checkout, simulador) | 2,5 | 3,1 |
| Job `tests`: build desde cero | 27,1 | 33,7 |
| Job `tests`: unit pure-logic (15 466 casos) | 30,2 | 36,8 |
| Job `tests`: unit context-based (97 casos en 6,6 s) | 3,9 | 6,0 |

- **Espera de las sesiones:** 103 PR mergeados en la ventana, todos de sesiones lanzadas con
  auto-merge. Del último push al merge: p50 62 min, p95 116 min, **96 h en total en 4,7 días**.
- **La cola es la nocturna:** los 15 jobs `tests` de PR o push con más de 30 min de cola esperaron
  mientras corría la nocturna. GitHub sirve el cron con 4 a 9 h de retraso y cae en la jornada de
  Lima; la cuenta admite 5 jobs macOS a la vez.
- **Consumo de macOS:** ~4 300 min al día (PR 1 310, push 1 020, nocturna 1 960).
- **Sin caché:** cada run compila desde cero. El CI en sombra de la Mini, con DerivedData caliente,
  compilaba en 10 s a 3 min (30-sep).
- **Tests de más de 20 s:** 7 casos, el mayor de 86 s.

## Propuestas, por impacto (detalle en el artifact)

1. Reusar la compilación entre runs (caché de compilación de Xcode + paquetes + DerivedData): −17 a −21 min p50, 0 USD.
2. Lanzar la nocturna a hora fija de madrugada en vez del cron de GitHub: −45 min de cola en el p95, 0 USD.
3. Arrancar el simulador durante el build y correr context-based en paralelo: −4 a −6 min, 0 USD.
4. Repartir pure-logic en 3 tandas por tiempos, con un job final `tests`: −15 min p50; ocupa 3 de los 5 macOS, va después de la 2.
5. Correr en paralelo los dos bancos lentos de `coverage-index`: PR de docs de 3,5 a ~1,8 min.
6. Una card por cada test de más de 20 s: −1 a −3 min.
7. Tope de 10 min en `changes` y `coverage-index` (hoy heredan 360).

Proyección estimada con 1 a 4: **~27 min p50 y ~40 min p95** para un PR que compila. La meta de
1 min no es alcanzable con la suite iOS completa; los PR de docs pueden quedar en ~1,8 min.

Ya está o no compensa: la cancelación del run viejo del PR (desde el 30-sep), clonar con
`--filter=blob:none` (el checkout tarda 0,5 min), un hook pre-push (el `/gate` ya lo cubre) y la
selección por diff sin merge queue (no baja la espera de la sesión, que espera el merge).

## Lo que necesita cuenta, permiso o gasto

- **Factura de Actions:** no se pudo leer (a `gh` le falta el permiso `user`). La documentación de
  GitHub dice que los runners estándar son gratis en repos públicos; `.claude/rules/ci-qa.md` dice
  que `xcode-27` se paga por minuto. Con ~129 000 min al mes a 0,062 USD serían ~8 000 USD, así
  que lo probable es que hoy sea gratis. Es una inferencia: se confirma en Settings → Billing.
- **Merge queue:** solo existe en repos públicos de organizaciones; habría que mover el repo.
- **Más de 5 macOS simultáneos:** ticket a soporte de GitHub.
- **Runners de pago con macOS M4:** Cirrus Runners ~450 USD/mes (3 runners, tarifa plana);
  WarpBuild o Blacksmith ~3 400 USD/mes; runner grande de GitHub ~4 300 USD/mes (solo PR y push).
  Precios de comparativas de 2026, sin verificar en cada proveedor. No se contrató nada.
- **Runner propio en la Mini o la Max:** no se recomienda mientras el repo sea público.

## Resultados: lo implementado y lo medido (21-nov, PR 1105)

Jürgen aprobó las 7 propuestas el 21-nov (08:36). Todo a 0 USD: mismos runners de GitHub, sin
runner propio, sin cambiar la visibilidad del repo. Los checks del ruleset siguen llamándose `tests`,
`coverage-index` y `gateway`. Regla durable: `.claude/rules/ci-qa.md`.

### Runs reales del PR

| Run | Caché | Build (job) | Tandas de unit | Resultado del PR |
|---|---|---:|---:|---:|
| 44916216313 | fría (no había) | 36,9 min (compilar 32,2) | 17-24 min | 62 min |
| 44922082084 | caliente, sin cambios de Swift | 5,2 min (restaurar 1,8 + compilar 2,5) | 14-19 min | 25,3 min |
| 44924790889 | falló al restaurar (ver abajo); con un cambio de Swift de 2.3 | 9,9 min (restaurar 2,5 + compilar 4,2 + guardar 1,7) | 12,6-22,9 min, dos con 12,7 y 28,4 min de cola | 62 min (~34 sin la cola) |
| 44930924053 | caliente, con el arreglo de la carrera | 7,3 min (restaurar 2,5 + compilar 3,3) | 21,6-23,5 min, una con 6,2 min de cola | 37,6 min (~31 sin la cola) |

«Resultado del PR» = desde que nace el run hasta que acaba el último job (todos en verde). El de la
auditoría era 66 min en el p50 y 101 en el p95.

**En resumen:** con caché caliente, un PR que compila tarda **25 a 38 min** (25 a 31 sin la cola de
hoy), frente a 66 min en el p50 de antes. Lo que más varía ahora es el propio runner: el mismo paso de
pure-logic va de 10 a 18 min entre runs.

**La cola del run 3 es la nocturna del cron viejo**: nació a las 11:07 de Lima y ocupaba los macOS. Es
justo lo que corrige el paso 2, que entra con este PR.

**El run 3 destapó una carrera.** El simulador en segundo plano validaba su destino con
`xcodebuild -showdestinations -derivedDataPath .ddp`, que resuelve paquetes en `.ddp/SourcePackages`
mientras el restore extraía ahí la caché. `tar` salió con 2 (`Cannot utime` en
`.ddp/SourcePackages/checkouts/*/.swiftpm`) y la acción dio la caché por no encontrada: compiló sobre lo
ya extraído y la volvió a guardar. El run 2 tuvo suerte con el orden. Arreglado: esa validación usa su
propio DerivedData.

### Antes y después, por paso

| # | Paso | Antes | Después |
|---|---|---|---|
| 1 | Caché de compilación | build desde cero: 27,1 min p50 | 2,5-3,3 min de compilar (+1,8-2,5 de restaurar); el job `build`, de 5,2 a 7,3 min |
| 2 | Nocturna a hora fija | nacía entre las 09:00 y las 13:47 de Lima y duraba 7,5-9 h | la lanza el vigilante a las 21:17 de Lima (cron cada hora + push); el cron viejo queda de respaldo |
| 3 | Simulador durante el build y context-based en paralelo | simulador ~2 min en primer plano; context-based ~4 min después de todo pure-logic | simulador en segundo plano mientras baja el build; context-based en la tanda 1, a la vez que las otras |
| 4 | Pure-logic en 3 tandas | un paso de 23 min (15 466 casos) | tres tandas de 10-18 min de paso (el runner varía casi el doble de un run a otro), repartidas por tiempos; `tests` junta y falla cerrado |
| 5 | `coverage-index` en paralelo | ~3,7 min | 2,1-2,3 min (los dos bancos lentos en segundo plano) |
| 6 | Card por test de más de 20 s | 7 casos según la auditoría | 8 cards: los que pasan de 20 s en el push del 21-nov o en el primer run del PR |
| 7 | Topes de `changes` y `coverage-index` | 360 min (el de GitHub) | 10 min |

### Lo que se midió antes de elegir la caché (Max, Xcode 27.2)

| Caso | Segundos |
|---|---:|
| Build en frío | 214 |
| DerivedData restaurado en la misma ruta, checkout nuevo, sin cambios | 23 |
| … con un cambio dentro de una vista | 47 |
| … con un cambio solo en un test | 65 |
| … con un cambio de interfaz en un fichero central (`CurrencyUtils.swift`) | 192 |
| Solo la caché de compilación de Xcode, sin el resto del DerivedData | 218 |
| DerivedData restaurado en OTRA ruta | 241 |

Lo que esto significa para un PR: el ahorro depende de lo que toque. Un PR que cambia vistas o tests
compila en minutos; uno que cambia la interfaz de un fichero del que dependen muchos se acerca al frío.

### Lo que quedó fuera o pendiente

- **La hora exacta de la nocturna.** El vigilante despierta cada hora con el retraso de los cron de
  GitHub, así que la lanza en algún momento de la primera hora u hora y media tras las 21:17. Al minuto
  exacto solo lo daría algo fuera del repo: un launchd en la Mini con
  `gh workflow run qa.yml --ref 2.3` a las 21:17. Propuesto, no hecho.
- **Arrancar el simulador sigue siendo el tramo fijo más caro de cada tanda**: 2 a 6 min en el runner
  (356 s en la tanda 1 del run 4). En segundo plano solo se solapa con la descarga del build (~1 min).
  Es el siguiente sitio donde mirar si hace falta bajar más.
- **El primer push a 2.3 tras el merge compila en frío** (las cachés de un PR no se ven desde 2.3) y
  guarda la de 2.3; desde ahí la usan los PR.
- **Los PR de solo docs** bajan a ~2,1-2,3 min, no a 1,8: los bancos nuevos de este cambio suman ~20 s
  a `coverage-index`.
