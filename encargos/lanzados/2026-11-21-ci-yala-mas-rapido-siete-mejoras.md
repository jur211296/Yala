Yala
# CI de Yala más rápido: caché de compilación, nocturna de madrugada, tests en tandas y topes (las 7 mejoras de la auditoría)
---
toca: .github/workflows/qa.yml,.github/workflows/nocturna-vigilante.yml,scripts/ci/,.claude/rules/ci-qa.md,docs/auditorias/2026-11-21-ci-tiempos.md,tickets/backlog/2026-11-21-ci-yala-mas-rapido.md,tickets/done/2026-11-21-ci-yala-mas-rapido.md
esfuerzo: high
cierre: cierra-sola
---

Jürgen aprobó el 21-nov (08:36 Lima) implementar las 7 propuestas de la auditoría `docs/auditorias/2026-11-21-ci-tiempos.md` (artifact https://claude.ai/artifact/7WNMaTYGyeDUkAbUXve2oM). Hoy un PR que compila tarda unos 66 min en el p50 y 101 en el p95; la meta proyectada con 1 a 4 es de unos 27 en el p50 y 40 en el p95.

## Qué hacer, en este orden (mide después de cada paso)
1. Reusar la compilación entre runs: caché de compilación de Xcode, paquetes SPM y DerivedData con `actions/cache` y una clave correcta (Xcode, Package.resolved, hash del proyecto). Un fallo de caché nunca rompe el run; solo compila desde cero.
2. Nocturna a hora fija de madrugada (Lima) en vez de depender del retraso del cron de GitHub, para que no ocupe los 5 macOS en horario de trabajo. Elige el mecanismo con 0 USD y sin runner propio (el repo es público), por ejemplo un `workflow_dispatch` disparado a hora fija desde algo que ya exista. Si necesita algo fuera del repo, déjalo propuesto y no lo inventes.
3. Arrancar el simulador mientras compila y correr context-based en paralelo.
4. Repartir pure-logic en 3 tandas balanceadas por tiempo, con un job final que se siga llamando exactamente `tests`.
5. Correr en paralelo los dos bancos lentos de `coverage-index` (PR de docs de ~3,5 a ~1,8 min).
6. Una card en el tablero (`tablero crear --proyecto Yala … --asignado frank --version v2.3 --prioridad baja --cierre cierra-sola --estado backlog`) por cada test de más de 20 s, con su tiempo medido.
7. Tope de 10 min (`timeout-minutes`) en `changes` y `coverage-index`.

## Restricciones
- Los checks obligatorios del ruleset de 2.3 siguen llamándose exactamente `tests`, `coverage-index` y `gateway`, y no pueden quedar en verde sin correr de verdad. No toques el ruleset.
- 0 USD: nada de runners de pago, sin cambiar la visibilidad del repo ni contratar nada.
- No bajes cobertura ni saltes tests para ganar tiempo.
- Mide con al menos 3 runs reales del PR (y uno con caché caliente) y actualiza la sección de resultados de `docs/auditorias/2026-11-21-ci-tiempos.md` con el antes y el después.
- Entrega final como artifact visual de Claude con el antes y el después por paso.

Índices compartidos: `docs/TICKETS.md` y `qa/coverage-index.json` no van en `toca:`; edítalos solo al final, justo antes del PR, tras `git rebase origin/2.3`, resolviendo por fila o área sin pisar lo de otra sesión.

Termina con /cerrar-total cuando el PR esté dentro de 2.3.

## Cómo trabajar
- iPhone 14 (Jürgen, 19-nov): queda conectado a la Mini para cualquier sesión de cualquier máquina vía DeviceMCP. Antes de recurrir al simulador, verifica de verdad si está libre (que responda y que ninguna otra sesión lo esté usando en ese momento); no lo des por ocupado sin comprobarlo. Si lo usas, suéltalo al terminar.
- Textos nuevos en su propia tabla, nunca en Localizable.strings. Nunca un botón debajo de otro.
- En la Max puedes usar un segundo simulador además del de otra sesión, o el iPhone 14 por DeviceMCP; en la Mini, uno solo. No uses `-derivedDataPath /tmp/claude-*`.
- Nada en producción (ni CloudKit ni Supabase).
- Commit y PR sin firma de IA, contra 2.3. Deja el auto merge activado y no cierres hasta ver el PR dentro de 2.3. Si hay conflicto o el CI falla por tu PR, arréglalo tú. Si tras unos 45 minutos el CI sigue rojo por algo ajeno, cierra y anota el motivo.
- Lo menor y reversible se decide con la opción recomendada y se anota. Lo vital, según el modo fijado al arrancar: en semi (05:30–20:00) preguntas y esperas con la sesión viva; en nocturno (20:00–05:30) dejas un checkpoint recuperable y una card «Espera decisión» para Jürgen, sin cerrar como completo, sin mergear ni desplegar lo incompleto.
- Entregable del cierre: artifact visual de Claude (capturas antes y después y mediciones), nunca Markdown ni PDF.
- Cierre: `/cerrar-total`, con «Saltado o asumido sin preguntar» y «Decidido sin consultar», cada uno con motivo o «Nada», y el link del artifact.

## Paso 0 — decisiones

> Modo semi, resueltas por la sesión con su recomendación (menores y reversibles). Se discuten en el PR.

**D1 · ¿Qué se guarda entre runs?** → DerivedData de CI (`.ddp`) con `actions/cache`, sin `Index.noindex` ni `Logs`, y la caché de compilación de Xcode encendida si la medición local lo justifica. Clave: Xcode + `Package.resolved` + commit; `restore-keys` por prefijo. Guarda el push a 2.3/1.0 y la nocturna; un PR solo guarda si no encontró nada.
Por qué: un PR casi siempre llega de 2.3 y puede restaurar su caché; si los PR guardaran, llenarían los 10 GB del repo y echarían la de 2.3. Alternativa descartada: guardar en cada PR (desaloja la buena).

**D2 · ¿Un fallo de caché puede romper el run?** → No. Restaurar y guardar son pasos que no fallan el job; sin caché compila desde cero, como hoy.

**D3 · Nocturna a hora fija sin nada fuera del repo** → La lanza `nocturna-vigilante.yml`, que pasa a despertar cada hora y en cada push a 2.3; dispara la nocturna en cuanto ve que pasó la hora fijada y aún no nació hoy. El cron de `qa.yml` se queda como red: si al llegar (con su retraso de 6-10 h) ya hay nocturna del día, no corre nada.
Por qué: GitHub sirve cada cron con 3-10 h de retraso (medido); con un despertador por hora alguno cae cerca de la hora fijada. 0 USD, sin runner propio. La hora exacta solo la da algo fuera del repo (un launchd en la Mini): queda propuesto, no hecho.

**D4 · ¿A qué hora?** → 21:17 Lima. La nocturna dura 7,5-9 h (medido 16-20 nov): empezando a las 21:17 acaba hacia las 05:00-06:30, antes de la jornada. «De madrugada» literal (00:00-03:00) la haría terminar entre las 08:00 y las 12:00, dentro del horario de trabajo, que es lo que se quería evitar.

**D5 · Contexto en paralelo** → El simulador arranca en segundo plano mientras se baja el build; context-based ya no espera a todo pure-logic: corre en la tanda 1, en paralelo con las otras dos, y el reparto le resta su peso a esa tanda. No dos simuladores en el mismo runner (3 núcleos y 7 GB).

**D6 · Tandas** → Job `build` (compila una vez y sube los productos), matriz `unit` de 3 tandas por tiempos (tabla `qa/ci-unit-tiempos.json` sacada del `.xcresult` de cada tanda) y un job final en Ubuntu que se llama exactamente `tests`, expone las mismas salidas que hoy al aviso y falla si cualquier tanda o el build no salieron en verde. La última tanda corre «todo menos lo de las otras», así que una suite nueva nunca se queda fuera.

**D7 · `coverage-index` en paralelo** → Los dos bancos lentos (`interfaz-de-lo-tocado`, ~100 s, y `sim-lock`, ~82 s) se lanzan en segundo plano en su sitio del job y un paso final los espera. Se queda un solo job: el check requerido sigue siendo uno y el gate local lo replica igual.

**D8 · Scripts nuevos en `qa/scripts/`, no en `scripts/ci/`** → Ahí viven todos los del CI y sus bancos, y el gate los lee de ahí. Se tocan también bancos existentes de `qa/scripts/` (fuera del `toca:`) porque vigilan la forma de `qa.yml`.

**D9 · Cards por test lento** → Se re-miden con los runs de este PR y se crea una por cada caso de más de 20 s.
