---
id: uitest-seed-reseeds-the-corpus-without-reset
status: backlog
priority: low
area: "testing, seed"
created: 2026-09-09
updated: 2026-10-08
source: hallazgo de camino en el device-QA de chat-rows-sealed-before-the-fix-have-no-repair-path (2026-09-09)
---

# Relanzar un UI-test sin `-uitest-reset` duplica el corpus entero

## Qué pasa

`-uitest-seed <perfil>` **siempre siembra**. `DevSeedService.seed(in:profile:)` escribe
`devSeedDataExecuted = true` al terminar (`DevSeedService.swift:222`) pero **nunca lo lee para
abortar**: su único guard es `!isSeeding` (`:95`), que sólo protege de la reentrancia dentro del
mismo proceso.

Medido en simulador el 2026-09-09 (iPhone 17 Pro, iOS 26.5, `Yala Dev`), dos arranques con
`-uitest-seed realista` y `-uitest-reset` sólo en el primero:

| | registros | ingresos (todo el tiempo) | gastos |
|---|---|---|---|
| arranque 1 | 2.326 | S/ 276.549,60 | S/ 206.575,00 |
| arranque 2 | **4.651** | **S/ 553.099,20** | **S/ 412.550,00** |

«Bolt · S/ 18,00 · Taxis y apps» aparecía **dos veces seguidas** en Registros.

## Por qué no lo había visto nadie

Porque `-uitest-reset` lo tapa: borra los datos antes de sembrar, así que el corpus vuelve a quedar
en uno. **Todas** las recetas de QA existentes lo llevan, y el `-uitest-reset` es además lo que
recomienda el propio flujo. El caso aparece en cuanto un veredicto necesita **dos arranques sobre
el mismo store**, que es justo lo que pide
[[chat-rows-sealed-before-the-fix-have-no-repair-path]]: sembrar una fila envenenada en un arranque
y dejar que el barrido de arranque la cure en el siguiente.

## El rodeo que existe hoy, y por qué no basta

En el arranque 2 se puede **omitir `-uitest-seed`**: los datos ya están en disco y los fixtures
aditivos (`-uitest-seed-foreign-account`, `-uitest-seed-chat-sealed-rate`,
`-uitest-seed-group-bridge-fx`) son idempotentes, así que el corpus no crece. Funciona, y es la
receta que quedó escrita en los tickets.

Pero es una trampa que hay que **saber**: el arg que parece inocuo («vuelvo a pedir el mismo
perfil») es el que rompe el escenario, y el síntoma —totales al doble— se parece mucho a un bug de
producto en los cálculos. Un QA que no lo sepa reporta un falso positivo.

## Criterio de hecho (AC)

- [ ] Con el corpus ya sembrado, un segundo `-uitest-seed <mismo perfil>` no vuelve a sembrar; o
      bien lo dice en un `print` inequívoco si se decide que la re-siembra es deliberada.
- [ ] Si se decide que sea idempotente: el guard mira el **store**, no sólo el flag —un
      `devSeedDataExecuted` en `true` sobre un store vaciado a mano dejaría al QA sin corpus y sin
      forma de recuperarlo—, con el mismo criterio de presencia que ya usa
      `TransactionUpdateService.repairLegacyOneToOneRatesIfNeeded` (`:202-209`).
- [ ] Cambiar de perfil entre arranques sigue funcionando, o queda escrito que exige
      `-uitest-reset`.
- [ ] Un test que falle si dos siembras seguidas duplican el corpus.

## No confundir con

Los dos fixtures aditivos nacidos el 2026-09-09 (`DevSeedChatSealedRate`,
`DevSeedGroupBridgeFXLegs`) sí llevan guard de presencia y **no** están afectados.

**`DevSeedForeignCurrencyAccount` sí lo está, y esto está medido**: cero ocurrencias de un guard de
presencia en el fichero, así que un segundo arranque con `-uitest-seed-foreign-account` sin
`-uitest-reset` planta una **segunda** cuenta «QA FX» con sus tres transacciones. El síntoma es
silencioso —los importes del fixture se duplican y el peso contra el umbral del 5 % cambia— y sirve
el mismo arreglo de una línea que llevan sus hermanos.

## Relacionados

- [[chat-rows-sealed-before-the-fix-have-no-repair-path]] — el veredicto que destapó esto.
- [[fx-repair-sweep-is-the-only-boot-sweep-without-a-uitest-gate]] — el otro roce entre los barridos
  de arranque y el montaje de QA.

## Medido en 2.1 (triage 2026-10-08)

- `DevSeedService.seed(in:profile:)` solo comprueba `!isSeeding` (`DevSeedService.swift:101`). `devSeedDataExecuted` se escribe en `:240` y solo alimenta `hasSeeded` (`:96`), que pinta el botón de Perfil (`ProfileView.swift:1524`). No aborta ninguna siembra.
- `DevSeedForeignCurrencyAccount.create` sigue sin buscar si ya existe «QA FX»: no hay ningún `fetch` en el fichero.
- Por qué low: es una trampa de QA que lleva a falsos positivos. No afecta a producción.

Triage 2026-10-08: abierto · medium → low · DevSeedService.seed sigue protegido solo contra la reentrada (!isSeeding), y DevSeedForeignCurrencyAccount sigue sin guard de presencia
