# Tarjeta con varias divisas, entrega 1: el enlace entre cuentas en el modelo y en la sincronización, sin pantallas

Base y PR: **2.2**. `lanzar-sesion` te deja sobre origin/2.1: antes del primer commit haz `git fetch origin && git switch -C encargo-tmp origin/2.2` (o rebasa tu rama sobre origin/2.2) y comprueba que `git log origin/2.2..HEAD` sale vacío. PR contra 2.2.

## Contexto
Jürgen aprobó el 16-oct (22:38) la cola de cards de 2.2, y la tarjeta multidivisa va primero, en cuatro entregas en orden 1→2→3→4 (obligatoria en 2.2, decisión del 13-oct). Esta es la entrega 1: no cambia nada visible, prepara el enlace «línea en otra divisa» entre cuentas en el modelo, en iCloud y en Modo Nube.
- Card: `tablero-tarjeta-con-varias-divisas-entrega-1-el-mxt7` (muévela a in progress al empezar y a done al cerrar, `--agente frank`).
- Ticket con el alcance completo: `tickets/backlog/multi-currency-accounts-1-model-and-sync.md` (en origin/2.2). Decisiones de Jürgen: `tickets/backlog/multi-currency-accounts.md` y `docs/multi-currency-accounts-impact-2026-10.md`, secciones 4-6 (PR #444).
- El bloqueo que dice el ticket ya está resuelto: el chequeo del esquema de iCloud de Production se hizo (card o2li en done) y el 16-oct Lola exportó los cuatro `.ckdb`; quedaron byte a byte iguales a los de 2.1 (card 1hfp en done). O sea, Production ya tiene los 14 campos; solo falta `CD_parentAccountID`.

## Qué se pide
Los puntos 1 a 7 del alcance del ticket: `parentAccountID` en `Account`, la lógica pura de líneas con su suite, el límite Free dentro de `isBillableUserAccount`, la reconstrucción tras identidad colapsada, la deduplicación por (tarjeta, divisa), Modo Nube (DDL en `qa/cloud/`, `supabase-staging.ddl`, manifest, emisión y apply) e iCloud (`CD_parentAccountID` en los snapshots `.ckdb` y el test de paridad en verde).

## Qué NO hay que tocar
- Ninguna pantalla (entregas 2, 3 y 4).
- **Despliegues irreversibles a producción: no los hagas tú.** Ni «Deploy Schema Changes» de CloudKit a Production, ni el DDL en la base de producción de Supabase (el token de Supabase le toca a Jürgen). Deja todo listo: el DDL de producción escrito, y una guía corta para la consola de CloudKit con el molde de `docs/cloudkit-schema-diff-2.1.md` (solo altas, `CD_parentAccountID` en `yala` y `yala_dev`). Crea dos cards en Yala 2.2: «Desplegar CD_parentAccountID a Production en CloudKit» asignada a `lola` (ella conoce ese proceso), y «Aplicar en producción el DDL de parentAccountID de Modo Nube» asignada a `jurgen`. Las dos son requisito antes de publicar 2.2, no antes de mergear.
- Staging sí, si la Mini tiene acceso según `docs/RUNBOOK-staging-ddl.md`. Si no lo tiene, déjalo anotado en la misma card de Jürgen.
- Respeta el orden de despliegue del ticket: ningún build debe escribir el campo antes de que el backend lo conozca. Si hace falta, gátalo por la capacidad del manifest, y dilo en el PR.

## AUTONOMÍA (fin de semana)
Jürgen no está en el escritorio. Si sale una duda reversible, elige la opción recomendada, impleméntala y anótala en la card y en el PR («Decidido por la sesión: …, porque…»). Lo irreversible (esquema de producción, borrar datos, cobros) queda para Jürgen como arriba, sin parar la sesión.

## Reglas
- Sin esperar el CI de nadie; `git fetch && git rebase origin/2.2` justo antes de abrir tu PR.
- Pipeline serial en la Mini: limpiar, build con `xcodebuild -jobs 2` sin simulador encendido, encender 1 simulador, tests, apagarlo. Mira `df -h /` antes de compilar. Usa los simuladores iOS 27.0.
- Al lanzar y al cerrar borra sin preguntar el DerivedData de esta sesión y las cachés de XcodeBuildMCP de worktrees que ya no existen; no toques las de un worktree vivo.
- En `~/Yala` (árbol principal) no toques los `.ckdb` sin commitear, `Yala.xcscheme` ni `encargos/pendientes/`. No toques tmux `salud--*`, `sat-lab--*`, `clinicas-dentales-bi--*`, ni `Yala--qa-guiado-2-1-tf17`.
- Sin texto nuevo de usuario en esta entrega; si sale alguno, en los 16 idiomas y sin nombrar a «OpenAI».
- Todo ticket nuevo lleva su card.
- Prueba según /barrido-qa lo que aplique (sin pantallas: tests unitarios, paridad de esquema y sync).
- Cierra con /cerrar-total.

## Cómo se sabe que está bien
Los siete puntos del alcance hechos y probados, `PersonalCloudKitSchemaParityTests` en verde con el campo nuevo, la suite de `YalaTests` en verde, el PR contra 2.2 explicando en lenguaje de usuario qué queda listo y qué falta desplegar, y las dos cards de despliegue creadas.

## Paso 0

Decidido por la sesión el 2026-10-18 (Jürgen fuera, encargo autónomo). Lo medido va con su coordenada; lo inferido, dicho.

1. **El enlace es el UUID crudo de la principal** (`Account.parentAccountID: UUID?`, `nil` por defecto, sin parámetro nuevo en el `init`). No es una relación: así sobrevive a que la principal todavía no haya llegado y no necesita `SyncDanglingRef` (el UUID no se pierde al aplicar).
2. **Una sola regla pura decide qué es cada cuenta** (`AccountLineLogic.resolve`): principal, línea o suelta. Una línea inválida se lee como cuenta suelta, visible: padre ausente o borrado, padre archivado, padre que a su vez es línea, autoenlace, misma divisa que el padre, cuenta de sistema en cualquiera de los dos lados. Con dos líneas de la misma tarjeta y la misma divisa (no archivadas) gana el menor `shortcutID`; el nombre no desempata porque se edita y dos teléfonos elegirían distinto (regla del 17-oct en `swiftdata-cloudkit.md`).
3. **Deduplicar es leer, no escribir** (corregido tras la review). Con dos líneas de la misma (tarjeta, divisa), `resolve` da la ranura al menor `shortcutID` y lee la otra suelta, igual en todos los teléfonos. La primera versión desvinculaba la perdedora tras cada pull; la review encontró dos carreras (un archivado en vuelo, un `shortcutID` reparado en un solo teléfono) en que cada teléfono desvinculaba una distinta y la tarjeta se quedaba sin línea. Fundir quedó descartado desde el principio: movería movimientos y borraría una cuenta que alguien creó.
4. **Límite Free**: `isBillableUserAccount` da `false` a toda cuenta con `parentAccountID`; la lista `billableUserAccounts` vuelve a contar las que no resuelven como línea (huérfanas, inválidas, duplicadas). Falla cerrado: lo que se ve como cuenta suelta, cuenta.
5. **UUID colapsado**: si la principal cambia de `shortcutID`, sus líneas se reenlazan al nuevo solo cuando exactamente una de las cuentas que compartían el valor viejo puede ser su principal. Si hay dos candidatas, la línea se queda huérfana (suelta y visible) en vez de adivinar. En los dos sitios que regeneran: `repairCollapsedIdentityUUIDs` y el one-shot de `AppBootstrapper`.
6. **Modo Nube, gate por capacidad del manifest.** Medido: el Worker trata `X-Yala-Capability-Set: v1` (lo que manda todo 2.1, `SyncPullClient.swift:122`) como el set completo, y el Merkle serializa un NULL como `key:null` (`gateway/src/sync/canon.ts:24`). Desplegar la columna tal cual dejaría el Merkle de todas las cuentas divergente en cada teléfono 2.1 en la nube. Por eso: el manifest pasa a `manifest_version: 2` y la columna lleva `since: 2`; el Worker proyecta `v1` sin las columnas posteriores y anuncia su `manifest_version` en pull y Merkle; el cliente declara el menor entre lo suyo y lo anunciado, y solo con `v2` emite y hashea la columna. Al pasar a `v2` (corregido tras la review): se encolan solo los enlaces que este teléfono cambió hablando `v1` (quien filtró la columna los apunta) y el cursor vuelve a 0 para re-bajar todo con la columna. Así ningún build escribe el campo antes de que el backend lo conozca, sin depender del orden de publicación. Y `/config` publica la versión para un guard de `predeploy` que no deja desplegar un Worker con el manifest más viejo que el desplegado.
7. **iCloud**: este build nunca escribe un valor (no hay pantalla), y un opcional a `nil` no crea el campo en CloudKit. Los cuatro `.ckdb` llevan `CD_parentAccountID STRING`; el despliegue a Production es de Lola (card), antes de publicar 2.2.
8. **Despliegues**: staging (DDL + Worker) los hago yo: el token de gestión responde 200 en staging (medido hoy). `gateway/RUNBOOK.md` dice que el Worker lo despliega Jürgen; el encargo autoriza staging y es reversible, así que lo despliego y lo anoto (lleva también el cambio del 15-oct que esperaba despliegue). Producción (DDL + Worker) es de Jürgen; CloudKit Production, de Lola. Las dos cards en Yala 2.2.
9. **Review adversarial**: sí, es sync. Lentes: modelo y lógica pura, sync/Merkle/capacidad, despliegue y clientes viejos.
