---
id: prompts-de-traduccion-corren-xcodebuild-sin-cola
status: backlog
priority: low
area: qa, l10n
created: 2026-09-12
updated: 2026-10-08
source: lente adversarial de la sesión de la cola del simulador (2026-09-12)
---

# Seis recetas del repo siguen lanzando `xcodebuild test` sin hacer cola

## El hecho

Desde el 2026-09-12 el simulador se pide por turno (`qa/scripts/sim-lock.sh`, decisión de Jürgen,
ticket `diez-worktrees-comparten-un-simulador`). Se envolvieron los pasos 2 y 3 del `/gate` y la
batería de `/l10n-check`, que es lo que pedía el encargo. **Estas seis se quedaron fuera**, medidas
el mismo día:

| Dónde | Qué manda |
|---|---|
| `qa/prompts/README.md:58` y `:98` | sección «**xcodebuild test obligatorio antes de reportar**», a pelo |
| `qa/prompts/translate-ja.md:228` | igual — y además `xcrun simctl install booted` en `:240-247` |
| `qa/prompts/translate-zh-Hans.md:256` | igual |
| `qa/prompts/translate-pl.md:201` | igual |
| `qa/prompts/translate-nl.md:183` | igual |
| `qa/scripts/add-l10n-key.sh:173` | imprime el comando como «siguiente paso», sin cola **y** con el scheme `Yala` (el `/l10n-check` nuevo usa `Yala Dev`: dos recetas para la misma batería) |
| `qa/cloud/README.md:79` | `TEST_RUNNER_… xcodebuild test -scheme Yala …` |

## Por qué importa, y no es simetría

Quien corre una de estas recetas **se pisa con la corrida de otra sesión y la pisa a ella**. Las dos
salen en rojo, y el rojo de la que sí hizo cola trae su línea de fallo y su mensaje de aserto, o sea
que parece un bug del producto: es exactamente lo que costó el ticket `high` falso del 11-sep.

El `translate-ja.md` es el peor de los seis porque hace `simctl install booted`: instalar sobre el
mismo bundle id **es** el modo de fallo, y encima no lo ve ninguna de las dos firmas que vigila
`sim-libre.sh` (no es un `xcodebuild` y no levanta un `*UITests-Runner`), así que la víctima recibe
un rojo con un centinela en verde.

## Qué hacer

Anteponer `bash qa/scripts/sim-lock.sh -- ` a cada uno de esos `xcodebuild`, y decidir qué hacer con
`simctl install` (que el lock no cubre: ver `qa-de-producto-toca-el-simulador-sin-cola`).

No se hizo en la sesión que montó la cola porque son de otro flujo —traducciones y nube— y ampliar
ahí era salirse del encargo.

## Relacionados

- [[diez-worktrees-comparten-un-simulador]] — la cola, y por qué existe
- [[qa-de-producto-toca-el-simulador-sin-cola]] — la otra mitad: lo que el lock no puede ver
- [[l10n-check-corre-13-de-17-tests]] — el otro defecto de la misma familia, en el mismo comando

## Fusionado de qa-de-producto-toca-el-simulador-sin-cola (triage 2026-10-08)

Es el mismo hueco: trabajo que toca el iPhone 17 Pro compartido fuera de la cola de `a4454b8e2`. La otra mitad es el `/qa` de producto, eximido a propósito (`qa/scripts/sim-lock.sh:63-66`). Instala con XcodeBuildMCP (`build_run_sim`, `install_app_sim`, `.claude/commands/qa.md:17` y `:30`) sobre el mismo bundle id. `sim-libre.sh` solo ve `xcodebuild … test` y `*UITests-Runner` (`:63`, `:87-88`), así que un `simctl install` de 1-3 s es invisible y la víctima recibe un rojo con el centinela en verde. Lo mismo pasa con el `simctl install booted` de `translate-ja.md:246` y de `translate-zh-Hans.md:274`. Opciones de aquel ticket: (1) que `/qa` pida turno, que es lo único que previene; (2) `sim-lock.sh --estado` al empezar el `/qa`, que avisa sin esperar; (3) enseñarle al centinela la firma `simctl` sobre el device compartido. (2) y (3) son baratas y compatibles.

## Medido en 2.1 (triage 2026-10-08)

Ninguna de las recetas lleva `sim-lock.sh` todavía: `qa/prompts/README.md:58` y `:98`, `translate-ja.md:228`, `translate-zh-Hans.md:256`, `translate-pl.md:201`, `translate-nl.md:183`, `add-l10n-key.sh:173` (scheme `Yala`) y `qa/cloud/README.md:84`. Desde el 12-sep no hay commits en `sim-lock.sh` ni en `sim-libre.sh`.

Triage 2026-10-08: abierto · medium → low · ninguna de las ocho recetas pasa por `sim-lock.sh` y el centinela sigue sin ver `simctl`; se fusiona aquí `qa-de-producto-toca-el-simulador-sin-cola`.
