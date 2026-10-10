---
id: qa-de-producto-toca-el-simulador-sin-cola
status: discarded
priority: medium
area: qa
created: 2026-09-12
updated: 2026-10-08
source: lente adversarial de la sesión de la cola del simulador (2026-09-12)
---

Why: Discarded 2026-10-08. Duplicado. El mismo hueco que prompts-de-traduccion-corren-xcodebuild-sin-cola (simulador compartido fuera de la cola de a4454b8e2), que se conserva con la fusión

# El `/qa` de producto instala en el simulador sin hacer cola, y nadie puede verlo

## El hecho

La cola del simulador (`qa/scripts/sim-lock.sh`, 2026-09-12) **exime al `/qa` de producto a
propósito**: es QA a mano, con un humano delante, y encolarlo detrás de un gate de 40 minutos no
ayuda a nadie. Esa decisión se mantiene. Lo que este ticket registra es su **otra cara**, que no se
midió al tomarla.

`/qa` usa XcodeBuildMCP (`build_run_sim`, `install_app_sim`) sobre el mismo iPhone 17 Pro
compartido, y eso **instala un `.app` sobre el mismo bundle id**. Si en ese momento hay una corrida
de XCUITest con su turno tomado, esa corrida pasa a tapear un binario que no es el suyo — el modo
de fallo que produjo el ticket `high` falso del 11-sep, con su línea de fallo y su mensaje de
aserto, indistinguible de una regresión.

## Y el centinela no lo ve, que es lo que lo hace caro

`sim-libre.sh` conoce exactamente **dos firmas**: un `xcodebuild` con `test` en su línea de comando,
y un proceso `*UITests-Runner`. Un `simctl install` + `launch`:

- dura **1-3 segundos** (de sobra para pisar el bundle),
- **no es** un `xcodebuild`,
- **no levanta** ningún runner.

O sea que es invisible a cualquier frecuencia de muestreo, incluida una de cero segundos. La víctima
recibe un rojo con el centinela **en verde**, que es la peor combinación posible: dice «este rojo es
tuyo» cuando no lo es.

## Opciones, para decidir

1. **Que `/qa` también pida turno.** Correcto y consistente, pero puede dejar a un humano esperando
   40 min delante de la pantalla. Mitigable con `--timeout` y un mensaje.
2. **Que `/qa` avise pero no espere**: `sim-lock.sh --estado` al empezar, y que el humano decida.
   Barato, no bloquea, y no garantiza nada.
3. **Enseñarle al centinela la tercera firma** (`simctl` sobre el device compartido) para que al
   menos la víctima sepa que su veredicto no vale. No previene, pero quita el falso «estuviste solo».

(2) y (3) se pueden hacer las dos y son baratas. (1) es la única que previene.

## Relacionados

- [[diez-worktrees-comparten-un-simulador]] — la cola, y la exención explícita de `/qa`
- [[prompts-de-traduccion-corren-xcodebuild-sin-cola]] — la otra familia que quedó fuera
- `.claude/rules/testing.md` — las dos firmas que el centinela conoce

Triage 2026-10-08: duplicado · medium → — · es el mismo hueco (trabajo en el simulador compartido fuera de la cola de `a4454b8e2`, invisible para `sim-libre.sh`); se conserva `prompts-de-traduccion-corren-xcodebuild-sin-cola`, donde queda fusionado.
