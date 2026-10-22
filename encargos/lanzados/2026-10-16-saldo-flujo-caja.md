# Saldo y flujo de caja: la gráfica de Saldo que contradice su cifra, y los ajustes de un mes del flujo de caja que no sincronizan con iCloud

## Contexto
Sesión agrupada de 2.1 con dos cards del área de saldo y flujo de caja. Lee los dos tickets enteros en origin/2.1 antes de empezar.

(a) Card tablero-la-grafica-del-saldo-contradice-su-propi-502e (2.1, prioridad media), «La gráfica del Saldo contradice su propia cifra». Ticket: tickets/backlog/panel-balance-chart-contradicts-its-own-figure.md. Salió en el PR #474.
- Qué pasa: en el Panel, con «Este mes», el widget Saldo dice «+179,062» y «Aumento +2%», pero la curva cae de ~218K a ~201K con el eje entre 180K y 220K. Con «Todo el tiempo» la curva llega a ~200K y la cifra sigue en 179,062.
- Cómo se reproduce (Yala Dev, iPhone 17 Pro Max, iOS 27): lanzar con `-uitest -uitest-reset -uitest-skip-onboarding -uitest-pro -uitest-seed ficha-mx-vida -AppleLanguages "(es-MX)" -AppleLocale es_MX -defaultCurrencyCode MXN -userTheme 1`, ir al Panel, periodo «Este mes», widget Saldo.
- Sin verificar si falla la cifra, la curva o la semilla. Sospecha: la cuenta en USD convierte con tipos distintos (el histórico de la fila frente al tipo vivo 18.30), y la curva podría usar otro tipo de cambio que la cifra «al tipo de cambio actual». Mídelo también con la semilla `realista` antes de culpar a `ficha-mx-vida`.
- Hecha cuando: la cifra y la curva cuentan lo mismo para cualquier periodo, con un test que lo fije y capturas de antes y después.

(b) Card tablero-los-ajustes-de-un-mes-del-flujo-de-caja-ly22 (2.1, prioridad ALTA), «Los ajustes de un mes del flujo de caja pueden no sincronizar con iCloud». Ticket: tickets/backlog/personal-cloudkit-cashflow-override-line-declared-as-reference.md. Relacionados: PR #442 y docs/cloudkit-schema-diff-2.1.md.
- Confirmado el 2026-10-12 con el export posterior al despliegue: en Production de iCloud.com.jurgenschmidt.yala, `CD_CashFlowOverride.CD_line` es REFERENCE y la app escribe STRING, así que los ajustes de un mes del flujo de caja no sincronizan. En el contenedor .dev es STRING.
- Un tipo no se puede cambiar en Production. El arreglo es de código: la relación `CashFlowOverride.line` pasa a otra propiedad con otro nombre, y por tanto a un campo nuevo de CloudKit.
- `PersonalCloudKitSchemaParityTests` hoy lo tolera en `knownTypeMismatches`.

Reglas para (b), puestas por Jürgen:
- Todo cambio es ADITIVO y no pierde datos. No se borra ni se renombra en el esquema ningún campo existente. El campo viejo se queda y la app deja de escribirlo.
- Los ajustes que ya existen se migran solos a la propiedad nueva en cada dispositivo, de forma idempotente y sin duplicar. Una versión vieja de la app en otro dispositivo no debe romperse ni borrar nada.
- Si exige un cambio de esquema de CloudKit: desarróllalo y pruébalo en Development. Documenta el paso exacto para desplegar el esquema a Production (CloudKit Console o `cktool`, qué record type y qué campo, cómo verificarlo con un export) en un runbook del repo. Puede ser un docs/RUNBOOK-cloudkit-schema.md nuevo o una sección en docs/cloudkit-schema-diff-2.1.md, enlazado desde el ticket.
- NO despliegues el esquema a Production tú. Deja ese despliegue como pendiente de Jürgen en la card ly22 (siguiente paso, con el enlace al runbook) y en el ticket. El orden también va en el runbook: el esquema se despliega a Production antes de que la build con el cambio llegue a TestFlight o App Store.
- Hecha cuando:
  - un ajuste de un mes hecho en un dispositivo llega al otro en Development (con test o prueba de sync medible);
  - `knownTypeMismatches` queda vacío o con la entrada justificada;
  - la migración tiene tests (con datos viejos, idempotente, sin duplicados);
  - el runbook y el pendiente de Jürgen están escritos.

## Qué se pide
1. Medir y reproducir cada caso con tests antes de arreglarlo.
2. Arreglar (a) y (b) con tests que fallen antes y pasen después. Si lo ves conveniente, haz una review adversarial de la migración de (b).
3. Mover los tickets a su estado y actualizar docs/TICKETS.md.
4. Uno o varios PR a 2.1, con capturas de antes y después en _capturas/ cuando haya cambio visible (widget Saldo).

## Cómo trabajar
- Pipeline serial con 1 simulador, como manda la norma de la Mini (16 GB):
  1. Limpiar sims muertos, DerivedData de sesiones cerradas y cachés de XcodeBuildMCP de worktrees que ya no existen.
  2. Build con `xcodebuild -jobs 2` sin ningún simulador encendido.
  3. Encender 1 simulador.
  4. Correr los tests.
  5. Apagar ese simulador y borrarle los datos.
  No compiles con un simulador encendido ni corras tests mientras compila. Si creas un simulador propio, bórralo al cerrar: solo deben quedar «iPhone 17 Pro» y «iPad Pro 11-inch (M5)», apagados.
- Al lanzar y al cerrar, borra sin preguntar el DerivedData de esta sesión y las cachés de XcodeBuildMCP de worktrees retirados. No toques los de otra sesión viva.
- Gate después del CI del PR anterior: la sesión arranca ya, sobre origin/2.1. El PR #522 (Grupos e iCloud) puede seguir en auto-merge. Justo antes del gate, mira si sigue en CI: si sigue, espera a que entre y rebasa una sola vez con el simulador apagado. Si 2.1 no se movió, sigue de frente. Si ese CI falla, no esperes: rebasa con lo que haya y sigue. El build y el simulador van después de ese rebase, una sola vez.
- Pruébala tú misma todo lo que se pueda, con simulador, tests y capturas, según /barrido-qa. Solo lo que de verdad necesite un iPhone real (por ejemplo, la sync del ajuste entre dos dispositivos reales con iCloud) pasa a «in qa» para jurgen, con un guion corto de 3 a 5 pasos en el siguiente paso de la card. Lo demás va a «done» con evidencia (PR, tests, capturas). Si ly22 queda esperando el despliegue del esquema a Production, déjala asignada a jurgen con ese paso y su guion de verificación.
- Cada ticket nuevo que añadas a docs/TICKETS.md lleva su card en el tablero: créala con `tablero crear --proyecto yala ... --agente frank`, o enlaza una que ya exista. Versión 2.1 si es de borrados, sync o datos del usuario; 2.2 si no es importante para el lanzamiento.
- Antes de cada PR: `git fetch origin && git rebase origin/2.1`. No esperes al CI para seguir.

## Qué NO hay que tocar
- En el árbol principal ~/Yala hay cambios sin commitear en «Cloudkit Schemas/yala_dev-development.ckdb», «Cloudkit Schemas/yala_dev-production.ckdb» y Yala.xcodeproj/xcshareddata/xcschemes/Yala.xcscheme. No los toques, no los commitees y no los descartes. Si tu cambio necesita actualizar los snapshots `.ckdb` dentro de tu worktree, hazlo ahí y avísalo en el PR, porque chocará con esos cambios locales de Jürgen.
- Nada de desplegar a Production: ni el esquema de CloudKit, ni backend, ni gateway.
- No toques sesiones tmux salud--* ni sat-lab--*.

## Cómo se sabe que está bien
- (a): la cifra y la curva del widget Saldo coinciden en «Este mes» y «Todo el tiempo» con `ficha-mx-vida` y con `realista`, con test y capturas.
- (b): ajuste del flujo de caja sincronizado en Development por un campo nuevo, migración aditiva probada, runbook del despliegue a Production escrito y despliegue pendiente de Jürgen en la card.
- PR a 2.1 rebasado sobre origin/2.1, con los tests en verde en local. Tickets y cards al día.
- Al terminar, ciérrate sola con /cerrar-total: simulador apagado y borrado, DerivedData de la sesión borrado y worktree retirado si el PR ya entró. Solo para si hace falta una validación URGENTE de Jürgen.

## Paso 0 — decisiones

> Resueltas en autónomo (bypass): las recomendaciones se dan por buenas. Se discuten en el PR.

**Hechos medidos antes de decidir.** El `CashFlowWipeService` de 1.2.7 documenta que con `CD_line` en REFERENCE
el export de iCloud se ATASCA entero (no solo los ajustes): un registro rechazado bloquea el lote. La 2.0.4 no
borra ajustes huérfanos (único borrado de `CashFlowOverride`: el wipe de 1.2.7, ya consumido). No hay token de
`cktool` en la Mini (medido: `No management token found`), así que no puedo importar el esquema a Development
ni exportar Production. El encargo afirma REFERENCE en Production confirmado el 12-oct; el snapshot del repo
`yala-production.ckdb` lo dice igual.

**D1 · ¿Renombrar `line` (originalName) o propiedad nueva al lado?** → Propiedad nueva `cashFlowLine`
(campo `CD_cashFlowLine STRING`) con su to-many nuevo en `CashFlowLine` (`monthOverrides`); `line` y `overrides`
se quedan en el modelo como LEGADO, solo para leer datos viejos.
Por qué: es aditivo también en el store local (columna nueva, nada se renombra) y la migración es un paso de
código explícito y testeable. Alternativa descartada: `@Relationship(originalName:)`, que renombra la columna
local y no deja una escritura en el historial, así que los ajustes ya sincronizados en `.dev` no reexportarían
el campo nuevo y un import posterior lo pondría a `nil`.

**D2 · ¿La migración deja `line` puesto o lo vacía?** → Lo vacía en el mismo guardado en que rellena
`cashFlowLine`.
Por qué: un registro que nunca entró en Production se exporta entero; con `line` puesto saldría `CD_line` STRING
y Production lo volvería a rechazar. Alternativa descartada: dejarlo puesto «para versiones viejas»: en
Production ninguna versión vieja recibió nunca ese registro (todos fueron rechazados).
Precio aceptado (solo contenedor `.dev`, donde `CD_line` es STRING y sí sincronizó): una build vieja de Yala Dev
en otro dispositivo pierde el enlace del ajuste que migra otro; ningún dato se borra.

**D3 · ¿Cuándo corre la migración?** → En cada arranque (`AppBootstrapper`, junto al wipe de 1.2.7),
idempotente por predicado (solo ajustes con `line` puesto), sin flag.
Por qué: así también se migra lo que llegue tarde de un dispositivo con build vieja (en `.dev`). Sin flag no hay
estado que pueda quedarse a medias. Alternativa descartada: one-shot con flag en `UserDefaults`.

**D4 · ¿Y `knownTypeMismatches`?** → Se queda la entrada de `CD_line` en los dos snapshots de producción,
justificada: la propiedad legado sigue en el modelo y la app ya no la escribe nunca; un test fija que tras
migrar y tras crear un ajuste `line == nil`.
Por qué: el campo existe en el modelo y el test lo espera STRING; vaciarla exigiría quitar la propiedad legado,
que es la que permite leer los datos viejos.

**D5 · Sync medible en Development sin token ni iCloud en el simulador.** → Lo medible en el Mac: el
`NSManagedObjectModel` lleva el campo nuevo como STRING (paridad de esquema) y los cuatro `.ckdb` lo declaran;
la sync real entre dos dispositivos pasa a QA de Jürgen tras el despliegue del esquema (runbook).
Alternativa descartada: inventar una prueba de sync en simulador, que no tiene iCloud.

**D6 · Runbook.** → Sección nueva en `docs/cloudkit-schema-diff-2.1.md` (ya es la guía de deploy del
contenedor personal), con el orden: Development → Production → verificar con export → y solo entonces la build.

**D7 · (a) ¿Qué número manda y cómo se valora la curva?** → **Contestada por Jürgen (2026-10-16, 06:58):
«cada día a su tipo de cambio».** La cifra (saldo vivo al tipo de hoy) no cambia. Cada punto de la curva vale el
saldo NATIVO de ese día por el tipo de cambio de ESA fecha (la regla contable para dinero en cuenta); el punto
de hoy, al tipo actual, así que la curva acaba en la cifra por construcción. Un periodo cerrado («Mes pasado»)
vale su saldo al cierre con el tipo del cierre.
Medido antes: la brecha era solo de divisa (con `ficha-mx-vida`, 15.279 USD a 18,30 = 279.606 MXN frente a
282.662 sumando cada fila a su tipo; igual con `realista`). Alternativas que se le pusieron: «todo al tipo de
hoy» (vista a tipo constante, más simple) y «solo los periodos que incluyen hoy». Coste aceptado: leer las tasas
de cada día del periodo, en bloque y con un test que compare la lectura en bloque con la conversión día a día.

**D8 · Alcance de (a).** → Toda curva de saldo que pinte junto a esa cifra (Panel y la de Estadísticas que usa el
mismo procesador), no solo el widget; se cuentan las instancias antes de cerrar.

**D9 · PR.** → Un PR con un commit por card: (b) esquema + migración + runbook, y (a) saldo con sus capturas.
Por qué: una sola rama, un solo cierre, y cada card se revierte por su commit. Alternativa descartada: dos PR
desde el mismo worktree, que obliga a cambiar de rama con el simulador y el gate de por medio.
