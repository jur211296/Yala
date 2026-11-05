# Lote T5 · Recetas del gate
toca: `.claude/commands/`

Rama base: 2.3. Un solo PR contra 2.3, un solo cierre. Máquina: cualquiera. No usa simulador.
Lote chico de deuda técnica (docs/planning/cola-2-3-propuesta.md §3 T5). No lo lances en paralelo con otra sesión que esté corriendo `/gate`.

Cards:
1. El gate local no corre el check de aislamiento de tests que el CI sí bloquea.
2. El gate no ve los warnings de los ficheros de test.
3. El gate puede filtrar tests por el nombre del fichero.
4. `/l10n-check` corre 13 de los 17 tests de paridad y no puede notarlo.

Hecha cuando: las cuatro quedan hechas o con ticket/done; el gate local se alinea con lo que el CI bloquea; tests o comprobaciones del cambio en verde. Sin desplegar nada.

Restricciones: no toques `mcp/`, gateway de IA, MigrationRunner, ni UI de la app. PREGUNTAR, NO SALTAR con `preguntar-bot`.
Mueve cards con `tablero`. Cierre con sección «Saltado o asumido sin preguntar». Cierra sola: /cerrar-total.

## Paso 0 — decisiones

> Resueltas en autónomo (bypass): las recomendaciones se dan por buenas. Se discuten en el PR.

**D1 · Rama base: el worktree nació de `2.2`, el encargo pide `2.3`** → la rama se rehace sobre `origin/2.3` antes del primer cambio (no tenía commits propios).
Por qué: el encargo lo dice y el PR va contra `2.3`. Alternativa descartada: rebasar al final, que arrastra 19 commits ajenos.

**D2 · Card 1, qué camino del ticket** → el camino 2: el paso 5 del gate corre TODOS los `run:` del job `coverage-index` de `qa.yml`, leídos del propio YAML por un script (`qa/scripts/gate-ci-checks.sh`), con su banco.
Por qué: el job ya pasó de 2 a 12 pasos y el gate replicaba 1; copiar la lista a mano vuelve a divergir. Medido: los 12 corren en ~95 s en local, todos verdes. Fail-closed: si el YAML trae un `run:` multilínea o el job no aparece, el script sale con error en vez de saltárselo. Alternativa descartada: añadir solo `check-test-isolation.sh` (camino 1), que deja fuera los otros diez bancos.

**D3 · ¿El banco del nuevo script lo corre el CI?** → sí, un paso más al final de `coverage-index` (y por tanto también el gate).
Por qué: un banco que no corre nadie es justo la clase de deuda de T6. Toca `.github/workflows/qa.yml` con dos líneas; se asume aunque el `toca:` diga `.claude/commands/`.

**D4 · Card 2, warnings de test e incremental** → `touch` de los `.swift` del alcance antes del build del paso 1 y antes de cada `xcodebuild test`, y `warning:` en el grep de los pasos 2 y 3, filtrado por los ficheros del alcance.
Por qué: es lo que pedía el ticket y no cuesta un `clean build` por scheme. Alternativa descartada: `clean build`, varios minutos por scheme.

**D5 · Card 3, cómo resuelve suites el gate** → un ayudante (`qa/scripts/suites-de-fichero.py`, con banco) que da los TIPOS declarados en un fichero de test; el paso 2 lo usa para cada fichero de test encontrado o tocado, y el criterio de conteo pasa a «M ≥ suites pedidas».
Por qué: `grep "@Suite"` tampoco basta: `LocalizationParityTests.swift` declara tres suites sin `@Suite`. Los ficheros de test tocados también entran (antes el mapeo los excluía).

**D6 · Card 4, `/l10n-check`** → pide las suites con el mismo ayudante sobre los dos ficheros, sin `-quiet`, verifica `Test run with` y la cabecera deja de dar un número fijo.
Por qué: un número escrito en la cabecera vuelve a envejecer (hoy son 12 casos en la primera suite, no 11).

**D7 · Paso 0 sin `grilling` interactivo** → el árbol se resolvió aquí directamente; nadie mira la sesión y ninguna decisión es irreversible.
