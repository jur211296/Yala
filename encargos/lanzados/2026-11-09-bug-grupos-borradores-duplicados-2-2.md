---
esfuerzo: high
toca: Yala/App/Logic/,Yala/App/ViewModels/,Yala/App/Views/Groups/,Yala/App/Views/Inbox/,YalaTests/,YalaUITests/
release: no
---

# Arreglar en 2.2 los gastos de grupo con cuenta que dejan borradores en la Bandeja y duplican el «Préstamo a grupos»

## Contexto
Bug grave reportado por Jürgen el 9-nov-2026, en sus palabras: «Anteayer metí gastos en grupos. Como los pagué yo, al registrarlos en grupos les puse cuenta y subcategoría. Hoy me encuentro con 3 borradores en la Bandeja de esos gastos de grupos, que ya no deberían tener borrador; además uno ni respeta la moneda; y en mis registros tengo registros de grupos duplicados para todos esos gastos.»

Capturas de Jürgen (su iPhone, datos reales; míralas, no las publiques):
- Mini: `/Users/jur/Claude/entregas/bug-grupos-duplicados-20261109/` · Max: `/Users/max-jur/Claude/entregas/bug-grupos-duplicados-20261109/`
- `01-detalle-gasto-grupo-google-one.png`: detalle del gasto de grupo «Google One», $10.84 USD, 7 nov 2026, pagado por Tú, reparto igual con Pia ($5.42 cada uno), categoría Suscripciones de utilidad (Personal) y «En tus finanzas» $10.84 · Sapphire · USD. O sea: el vínculo con sus finanzas, con cuenta, SÍ estaba puesto.
- `02-bandeja-borradores-grupo.png`: Bandeja de Entrada con 4 pendientes; 3 son borradores de grupo «Gasto compartido» con «Falta: Cuenta»: Google One S/ -10.84 (moneda equivocada: debería ser USD), Gasolina S/ -259.83 (7 nov) y Notaria Cruzado S/ -45.00 (6 nov). No deberían existir porque esos gastos ya tienen cuenta.
- `03-registros-duplicados-7nov.png`: Registros del 7 nov con duplicados: «Google One · Préstamo a grupos · Jurpi ❤️ $5.42» DOS veces, «Gasolina · Préstamo a grupos · Jurpi ❤️ S/129.91» DOS veces, además del personal «Google One $-10.84 Suscripciones de utilidad» con chip de grupo y «Gasolina S/-259.83 Combustible · Sapphire» con chip de grupo.

Lección fija del proyecto (memoria de Frank `regresion-se-mide-contra-lo-publicado`): un fallo grave se mide contra la versión publicada en App Store antes de pedir decisiones. «¿Regresión de 2.2 o ya venía?» decide si bloquea la subida de 2.2.

Rama base: `origin/2.2` en jur211296/Yala; el arreglo tiene que llegar a 2.2. Lee `CLAUDE.md` y solo los ADR vigentes del puente de Grupos (`GroupTransactionBridge`) y de la Bandeja antes de editar.

## Qué se pide
1. Reproducir en simulador con datos ficticios el caso de las capturas: gasto de grupo pagado por mí, con cuenta y subcategoría en «En tus finanzas», en USD y en PEN, reparto igual con otro miembro; luego abrir/reabrir/sincronizar como pasa al día siguiente.
2. Medir lo mismo contra la versión publicada en App Store (identifica su rama o tag; compílala aparte con `git archive` en tu scratchpad) y decir si es regresión de 2.2 o ya está en producción.
3. Encontrar la causa raíz de las tres cosas: (a) por qué se crean borradores de grupo en la Bandeja para gastos que ya tienen vínculo con cuenta; (b) por qué el «Préstamo a grupos» se duplica; (c) por qué el borrador toma la moneda equivocada (S/ en vez de USD).
4. Arreglarlo en 2.2 con tests que fallen antes y pasen después para cada causa (incluido idempotencia ante reapertura, sincronización y reintento).
5. Reparación de los datos ya afectados de Jürgen (borradores sobrantes y préstamos duplicados): PROPÓN una reparación segura (qué detecta, qué haría, cómo se revierte) y, si es código, déjala detrás de una confirmación explícita. NO borres ni fusiones datos del usuario por tu cuenta: la limpieza destructiva es una decisión vital de Jürgen.
6. Decir en el PR si 2.3 necesita llevar el arreglo hacia adelante (merge forward de 2.2 a 2.3) y qué archivos chocarían. Ojo: otra sesión de 2.3 («Pasar un gasto personal a un grupo desde Editar en Registros») toca el mismo puente.
7. Dependencias: arrancas sobre `origin/2.2` sin esperar CI ni el PR anterior; justo antes de abrir el PR, `git fetch` y un solo rebase sobre `origin/2.2`, y build y simulador una vez después.
8. Simuladores: en la Mini, máximo 1; en la Max puedes usar un segundo simulador (tope 2) aunque otra sesión de otro proyecto use uno, o el iPhone 14 conectado por DeviceMCP. Pipeline serial: limpiar solo lo propio o huérfano cerrado, build `xcodebuild -jobs 2` sin simulador encendido, luego bootear, probar, y apagar y borrar solo lo que encendiste.
9. Da siempre una descripción corta, en español y sobre el tema, a cada comando Bash.

## Qué NO hay que tocar
- Los datos reales de Jürgen y sus dispositivos: nada de borrar, fusionar ni "limpiar" sin su OK explícito.
- Producción (Supabase, gateway), auth, marketing/, colas ni trabajo de otras sesiones.
- Funciones nuevas: solo el arreglo y su reparación propuesta.
- Commits y PR sin firma de IA (nada de «Generated with Claude Code», «Co-Authored-By» ni enlaces de sesión).

## Cómo se sabe que está bien
- Un gasto de grupo con cuenta ya no genera borrador en la Bandeja, no duplica el «Préstamo a grupos» y cualquier borrador legítimo respeta la moneda del gasto; probado en simulador y con tests nuevos en verde junto al gate.
- Queda dicho, con evidencia, si el fallo está en la versión publicada o solo en 2.2.
- Un PR a `2.2` con causa raíz, arreglo, tests, la reparación propuesta para los datos afectados (sin ejecutarla) y la nota sobre llevarlo a 2.3. La limpieza de los datos de Jürgen queda como decisión suya, marcada `BLOQUEANTE:` si impide cerrar.

## Paso 0 — decisiones

> Sesión **semi** con Jürgen en el chat: lo menor lo decide Frank (recomendación por nodo); lo vital (tocar sus datos) se le pregunta. Se discuten en el PR.

**Hechos cerrados antes de decidir (medidos):**
- Versión publicada = tag `v2.1.0` (la rama `1.0` solo suma commits de web encima).
- Jürgen usa **un solo teléfono** y su cuenta está **en la nube (Google)**, sin iCloud privado (chat, 9-nov 08:2x).
- El borrador de la captura dice «Jür registró este gasto en Jurpi ❤️. Elige cuenta…»: es `createDraftCaseA(reason: .remoteCreate, actorName: pagador)`, la rama `isRemoteSync` del Caso A **sin registro real visible** (`GroupTransactionBridge.bridgeExpense`).
- La fila de la Bandeja pinta la divisa con `draft.account?.currencyCode ?? divisa por defecto`; el borrador de grupo nace con `account: nil` → sale en S/ (PEN, la de Jürgen) aunque el gasto sea USD. La hoja de finalizar sí enseña `$`.
- La limpieza que existe para este caso (`GroupBridgeRaceCleaner`) solo corre tras un import de **iCloud** (`.transactionsImportedFromSync`): en modo nube no corre nunca.
- El aviso de `lanzar-sesion` sobre `encargo/2026-11-05-registrar-decisiones-2026-11-05` es un resto: no hay rama remota ni sesión viva. Sí hay un PR abierto («Tu IA registra en Yala») que toca `InboxDraftRowView.swift` e `InboxDraft.swift`.

**D1 · Cómo se reproduce sin la cuenta en la nube en el simulador** → con el puente REAL en tests on-disk (alta local con cuenta + pasada remota en los órdenes que da producción) y, para lo visible, el simulador con datos ficticios sembrados en el estado que deja el bug.
Por qué: el modo nube en el simulador exige `YALA_DEV_SHARED_SECRET`, que no está en la Max (medido: ni `~/Secrets` ni Llavero). Alternativa descartada: pedir el secreto — bloquea por algo que no cambia el diagnóstico (el puente no habla con la red).

**D2 · Contra qué se mide «¿ya estaba en producción?»** → el mismo test exploratorio compilado sobre `git archive v2.1.0` en el scratchpad.
Por qué: es lo que pide el encargo y la lección `regresion-se-mide-contra-lo-publicado`.

**D3 · Divisa del borrador** → la fila de la Bandeja toma la divisa del gasto de grupo (`splitExpenseID`) cuando el borrador no tiene cuenta, resuelta en `InboxView` (quien construye la fila), sin campo nuevo en `InboxDraft`.
Por qué: arregla también los borradores que Jürgen YA tiene, sin migración ni campo nuevo de CloudKit, y no choca con el PR abierto que toca `InboxDraft.swift`/`InboxDraftRowView.swift`. Alternativa descartada: guardar la divisa en el borrador (campo nuevo = schema de CloudKit + no cura los existentes).

**D4 · Reparación de los datos ya afectados** → se PROPONE en el PR y, si se escribe en código, va detrás de una confirmación explícita y no se ejecuta. Nada se borra ni se funde en el teléfono de Jürgen sin su OK.
Por qué: es una decisión vital de Jürgen (encargo, «Qué NO hay que tocar»).

**D5 · Alcance del arreglo de causa** → se decide con la medición del test exploratorio y se anota aquí como D5-bis antes de tocar producción.
Por qué: todavía no está medido qué deja ciega a la pasada remota; arreglar a ciegas sería adivinar.

**D6 · Review adversarial** → sí, el cambio toca el puente SplitExpense ↔ TransactionItem (regla de Frank y del `CLAUDE.md`).

**D5-bis · Alcance del arreglo, tras medir** → convergencia, no prevención del disparador. Tras cada sincronización de la nube **y** de iCloud se quita el borrador «Elige cuenta» de un gasto cuyo registro real con cuenta ya está y se deja un solo «Préstamo a grupos» por gasto (`GroupBridgeLeftoverLogic`, `GroupBridgeRaceCleaner.convergeAfterSync`). La divisa de la fila sale del gasto (D3).
Por qué: medido con el puente real, local→remota y remota→local convergen; el bug exige una pasada remota que no vea las patas, y la búsqueda en el código dio dos caminos posibles en la nube (el eco del pull personal que re-aplica la cuenta y resucita una fila borrada, y un re-puente sobre un almacén personal sin sus filas), ninguno aislable sin el teléfono. Lo que sí está medido es que, una vez pasa, nada lo arreglaba en la nube y el préstamo doble no lo quitaba nadie en ningún almacén. Alternativa descartada: cambiar el delete+recreate del préstamo en cada re-puente por preserve+update (reduciría las resurrecciones) — cambio grande en la partición del puente sin el disparador medido; queda en «Encontrado».

**D7 · Los datos que Jürgen YA tiene** (Jürgen, chat 9-nov) → «solo lo nuevo + botón»: la limpieza automática solo actúa sobre lo nacido desde el primer arranque con el arreglo (sello `groupBridge.leftoverAutoSince`, por teléfono); lo anterior, desde un **aviso en la Bandeja** (elegido por Jürgen frente a Panel o Ajustes) que abre una hoja con la lista y pide confirmar. Nada se borra sin su «sí».

**Medición contra lo publicado (v2.1.0, `git archive` + la misma prueba):** la pasada ciega deja en 2.1 el mismo borrador y el mismo préstamo repetido; la limpieza de 2.1 (solo iCloud) quita el borrador y deja el préstamo. **No es regresión de 2.2: está en producción.**

**Ficheros (más de 3, aprobado en el chat al elegir el arreglo):** `GroupBridgeRaceCleaner`, `AppBootstrapper`, `InboxView`, `InboxViewModel`, `MetricsService` (canario `groupBridgeLeftoversRemoved`), `L10n` + 16 `Localizable.strings`, nuevos `GroupBridgeLeftoverLogic`, `InboxDraftDisplayCurrencyLogic`, `GroupBridgeLeftoversNotice`, seed `grupos-repetidos`, tests unit + XCUITest, `qa/coverage-index.json`.
