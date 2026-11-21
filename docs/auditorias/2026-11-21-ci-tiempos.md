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
