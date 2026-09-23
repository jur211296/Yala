---
id: reverse-cutover-cerrado-para-cuentas-born-cloud
status: qa
priority: high
area: "modo-nube, gateway, onboarding"
created: 2026-09-10
updated: 2026-09-23
source: "review adversarial de `backend-account-kind-complete-or-groups-only` (2026-09-10) — hallazgo B4"
---

# «Volver a iCloud» no está disponible para quien nació en la nube, y tras el fresh start eso es todo el mundo

## El problema, en lenguaje de usuario

Creo mi cuenta de Yala con Google y uso la app durante meses. Un día decido que prefiero que mis datos
vivan solo en mi iCloud privado. Voy a Ajustes a «Volver a iCloud»… y no hay salida: el backend
rechaza la operación. La única forma de dejar de tener mis finanzas en la nube es borrar la cuenta y
empezar de cero.

## Lo medido (2026-09-10, contra staging y producción)

- `migration_progress`, rama `reverse_claim`, tiene un guard duro al principio: si `migrated_at is
  null` devuelve `{ok:false, reason:'not_migrated'}`. Es deliberado y está comentado: «Only a migrated
  account can reverse (born-cloud v1 excluded)».
- `migrated_at` **solo lo estampa el `cutover`**, es decir, la migración de una sesión privada
  existente hacia la nube. Una cuenta que nace en la nube nunca pasa por ahí.
- Las dos cuentas de producción de antes del fresh start **no tenían `migrated_at`**: lo dice la
  propia sección de decisiones del ticket 2 («lo personal nació en la nube y no tiene copia en
  CloudKit»). Tras el fresh start del 2026-09-10, **toda cuenta nueva es born-cloud**.
- El golden 11 de `gateway/test/account.goldens.test.ts` pinnea justamente ese rechazo, así que el
  comportamiento está fijado por un test: cambiarlo es una decisión, no un descuido.

## Por qué importa ahora, y no antes

El ADR del 2026-09-09 apoya en la reversa una pieza del modelo nuevo: es la **única degradación**
`complete → groups_only` permitida (fila E de `docs/sessions/2026-09-09-matriz-escenarios-sesiones.md`).
El ticket `backend-account-kind-complete-or-groups-only` implementó esa mitad —`reverse_complete` ya
escribe `kind='groups_only'` y el cliente lo refresca—, pero **la puerta que lleva hasta ahí está
cerrada para la población real**: nadie puede llegar a ejecutar esa degradación.

O sea: la fila E de la matriz promete algo que hoy no se puede recorrer, y la única vía por la que una
cuenta pasa a `groups_only` desde `complete` es inalcanzable.

## Lo que hay que decidir (es de Jürgen, no técnico)

1. **¿«Volver a iCloud» debe existir para cuentas nacidas en la nube?** El modelo del ADR dice que sí
   («la sesión privada no es obligatoria», y el eje privado × nube es libre), pero abrirlo no es
   gratis: para una cuenta migrada, «volver» significa restaurar un CloudKit que YA tiene el corpus;
   para una born-cloud significa **exportar por primera vez** todo a iCloud, que es otra operación.
2. Si la respuesta es que no, entonces la fila E de la matriz y el §11 del ADR deben decir que la
   degradación es v-futura, y este ticket se cierra como decisión registrada.

## Alcance si se abre

- Quitar o condicionar el guard `not_migrated` de `reverse_claim`, con el camino de export a CloudKit
  que hoy no existe para una cuenta que nunca tuvo mirror.
- Revisar el golden 11, que pinnea el rechazo.
- Revisar `ReverseEligibility` en el cliente (hoy oculta o rechaza la opción por el mismo motivo).

## Criterios de aceptación

- [x] **Decidido por Jürgen (2026-09-10): se ABRE.** Las siete decisiones que esa respuesta dejaba
      abiertas están resueltas y medidas en §Paso 0.
- [x] **La mitad del backend, verificada contra staging.** `g15_02` aplicada en staging **y** en
      producción con el md5 de llegada idéntico en los dos (`41a4bfe0…`), y los cinco escenarios
      ejercitados contra la función viva: born-cloud entra, la ya-revertida queda fuera, y el control
      positivo (migrada) y el takeover del golden 12 siguen igual. Los goldens del gateway contra
      staging real: **33 pasan** — el 11 pinnea que born-cloud SÍ entra y el 16-bis que la revertida NO.
      El único rojo de la batería es el golden 20, que no es de este cambio (ver abajo).
- [x] **La mitad del cliente.** El gate deja de excluir a born-cloud y **el migrado sin mapa sigue
      excluido**: `ReverseEligibility.decide` gana `isBornCloud`, una marca POSITIVA del alta que hace que
      el gate falle CERRADO. Build en verde, **67 tests** de `MigrationWorkExecutorTests` pasan, y hay
      **tres mutantes verificados** a exit 65 —uno por aserción nueva, cada uno cayendo solo en su test.
- [ ] **Falta el device-QA de CloudKit real** — el guion está más abajo. Que el mirror exporte por
      primera vez un corpus born-cloud **NO es simulable** y el propio repo lo tiene anotado como no
      medido. Es de Jürgen.
- [ ] Falta el copy: `revert-card-copy-says-datos-regresan-a-quien-nunca-estuvo` (decisión D6).

### La review adversarial cazó SIETE cosas, y dos eran mías y graves

Cuatro lentes independientes (gate del cliente · SQL y backend · tests y goldens · las rules del repo
leídas contra el diff). Lo que cambió el resultado:

1. **[grave, mío] El gate del cliente fallaba ABIERTO** — ver D4. La señal pasó de negativa (ausencia de
   marcador) a positiva (marca del alta). Sin esto, un migrado sin marcador entraba en la reversa sin mapa,
   que es la resurrección de borrados de la que el guardarraíl protege.
2. **[grave, mío] El guard del RPC rompía multi-device** — ver D1. Sin la mitad `reverted_at`, el 2.º
   dispositivo de una cuenta ya revertida quedaba colgado para siempre. Corregido y re-aplicado a los dos
   entornos (`g15_02b`), con los 5 escenarios verificados contra la función viva.
3. **La ventana durable de los goldens.** El 16-bis dejaba a sub B `groups_only` si la corrida moría entre
   el 16 y su repromote, y eso pone 4 goldens en rojo en la corrida siguiente **por andamio**. Cerrado con
   un `beforeAll` idempotente (`ensureCompleteKind`) que auto-cura la corrida N+1.
4. **El golden 11 podía latchear `rip=true` en sub A** si un `expect` fallaba antes del abort. Reordenado:
   se desarma primero y se afirma después.
5. **Dos aserciones eran decorado.** «El terminal gana al guard del mapa» pasaba con los guards
   reordenados, y el cableado de la señal no tenía NINGÚN test (la tabla de verdad puede estar verde con el
   `Bool` mal calculado en producción). Hay tres tests nuevos y **tres mutantes verificados a exit 65, cada
   uno cayendo solo en su test**.
6. **Un `try?` que silenciaba**, contra `CLAUDE.md`, con su gemelo bien hecho a 20 líneas
   (`probeICloudChannel` usa `do/catch` + log). Desaparece con la señal positiva: es un `UserDefaults.bool`.
7. **La migración solo verificaba TEXTO.** Un guard dentro de un comentario habría pasado sus cuatro
   `position()` en verde. El fichero trae ahora un §3 de **comportamiento ejecutable** (5 escenarios, filas
   sintéticas que se borran, re-lanza el error tras limpiar) y corre también en su rama no-op, así que es
   una sonda re-ejecutable. Más `pronargs = 2` en los tres `SELECT` de `prosrc`.

### Residuales medidos que NO se tocan, con su motivo

- **El limbo de `reverseUpload`** (sin tope, backend congelado, sin salida en producción) y **el rechazo
  del claim sin desatascador**: son de otro objeto y ahora `high` porque este cambio los pasa de un caso
  raro a la población entera → `reverse-upload-has-no-ceiling-and-no-exit` y
  `reverse-claim-rejection-has-no-way-out-in-the-client`.
- **El takeover de una migración abandonada ANTES del cutover** (`migrated_at` nulo, `kind='complete'`) es
  un camino que antes se rechazaba y ahora se acepta. El resultado es sano —lo local está completo y es lo
  que sube a iCloud— pero **no tiene golden**. Anotado aquí y en `qa/cloud/README.md`.
- **`kind='complete'` no significa «tiene finanzas en la nube»**: significa «la fórmula del backfill de
  `g15_01` dijo eso». Una fila ligera de grupos anterior a `g3_02` quedó clasificada `complete` y ahora
  pasaría el guard. Población cero tras el fresh start, y el gate del cliente (`storageMode == .cloud`) lo
  tapa.
- **La vuelta a `complete` es self-service**: `PATCH personal_claimed_at=null` + `claim_account` la
  re-promueve, que es la ruta real de la fila F y también el bypass del guard. El daño es auto-inflingido
  (te congelas tu propio push), así que no se cierra.
- **El reset de `reverted_at`/`reverse_frozen_at` en el claim fresco queda inalcanzable en producción** (una
  cuenta con `reverted_at` es `groups_only`, y su claim entra ahora por la otra mitad del guard). No se
  borra: revive el día que exista el re-cutover, que sigue siendo diseño futuro. El golden 17 lo fija
  armando el estado por PATCH, y su comentario lo dice.

### Lo que NO se hizo, y por qué (dos rojos y una mitad, todos con dueño)

- **El golden 20 de `account.goldens.test.ts` sigue rojo, y no es de este cambio.** Medí que tarda
  **9,3 s** contra un timeout de 5 s, y que **pasa en verde** con más tiempo. Eso **refuta la
  hipótesis central** de su ticket (`account-goldens-freeze-read-test-times-out`), que daba por hecho
  que se colgaba y por eso descartaba subir el timeout; la medición está añadida allí.
- **La otra mitad del círculo `degradedNoMap` sigue abierta**: un usuario que SÍ migró y perdió el
  mapa de coordenadas queda inelegible de forma permanente. Ya estaba identificada como brecha `N2`
  en `docs/modo-nube/MODO-NUBE-AUDITORIA-ESCENARIOS.md`, y **ahora es la única población que ve
  `storage.revert.ineligible`**. No se toca aquí: es otro objeto y otro riesgo (resurrección de
  borrados).
- **El canario `cloudReverseDegradedNoMap` que el docblock prometía no lo emite nadie** y no es ni un
  caso del enum. Añadido a `canarios-y-breadcrumbs-sin-emisor` como una clase que su barrido no podía
  ver.

## Fuera de alcance

El `kind` en sí, que ya está implementado y verificado por su lado.

---

## Paso 0 — decisiones resueltas antes de escribir (2026-09-10)

**Jürgen decidió abrir la reversa a born-cloud** (no aplazar, no v-futura). Lo que sigue es el árbol de
decisiones que esa respuesta deja abierto, resuelto contra mediciones y no contra el enunciado.

### D1 · ¿Qué sustituye al guard `migrated_at`? → **el tipo de cuenta, O el haber revertido ya**

`if v_migrated is null → not_migrated` pasa a
`if v_kind is distinct from 'complete' and v_reverted is null → not_complete`.

Por qué `kind` y no «quitar el guard sin más»: el ADR del 2026-09-09 §11 puso `kind` como la columna que
contesta «¿esta cuenta lleva finanzas personales?», y la reversa es exactamente la pregunta «¿tengo algo
personal que devolver a iCloud?». Y porque **el guard viejo dejaba una puerta abierta que nadie había
visto**: una cuenta que YA revirtió conserva `migrated_at` (§h.4 lo deja a propósito) y por tanto podía
reclamar la reversa **otra vez**, sobre una cuenta que ya es `groups_only` y no tiene nada personal en la
nube. Medido en sandbox contra la función viva de staging el 2026-09-10 (escenario 2: `ok:true`).

### D2 · ¿Rompe el guard nuevo algún camino vivo? → **no, medido**

La promoción `groups_only → complete` de `claim_account` escribe `kind='complete'` **al principio**, en el
mismo UPDATE que arma `migration_in_progress` (línea 80 del cuerpo vivo). Por tanto una migración
abandonada por un líder crasheado —el modo de fallo real del 2026-07-10 que el golden 12 protege— llega al
takeover con `kind='complete'` y **sigue pasando el guard**. Verificado en sandbox (escenario 4).

### D3 · ¿Hay que construir un camino de export a CloudKit? → **NO. La premisa del ticket es falsa**

El ticket decía que para born-cloud «volver» significa *exportar por primera vez, que es otra operación*.
Medido: **no lo es.** La reversa no descarga ni sube nada a mano — monta el mirror (`.mountMirrorAndRelaunch`
solo desarma un flag) y `NSPersistentCloudKitContainer` hace el sync solo al relanzar; el paso
`reverseUpload` **sondea** el progreso del mirror (`reverseUploadStatus`) y no sube nada él. Ese sondeo ya
cuenta las filas sin metadata como pendientes, que es exactamente el estado de un corpus que nunca estuvo
en CloudKit: para born-cloud arranca en `pending(todas)` y baja hasta `drained`. Y el propio docblock del
método ya contempla el caso («una futura 2ª reversa ya es variante migrado con mapa poblado»).

⇒ El alcance real es **retirar dos gates**, no construir un camino.

### D4 · El gate del cliente: por qué NO basta con borrar `hasCKMap`

`ReverseEligibility.decide` excluye a born-cloud por `guard hasCKMap else { return .degradedNoMap }`. Pero
ese guardarraíl no se puso por born-cloud: se puso por el **migrado sin mapa**, y su riesgo es la
**resurrección de borrados** — al remontar el mirror, los records que siguen en la zona CloudKit re-importan
filas que se borraron durante la época nube (`MODO-NUBE-DIFERIDOS.md:153`, «verificado inseguro →
resurrección de borrados»). Una cuenta nacida en la nube **no tiene esa zona**: nunca hubo copia, así que no
hay nada que resucitar. `hasCKMap` mete las dos poblaciones en el mismo saco.

⇒ Se distingue, no se borra: el gate exige mapa **salvo que se pueda AFIRMAR que la cuenta nació en la nube
en este dispositivo**. El migrado-sin-mapa sigue excluido, intacto.

**La señal es POSITIVA, y ahí está toda la decisión.** La primera versión la derivaba de la AUSENCIA del
`CloudMigrationMarker` («no hay marcador ⇒ no migró»), y la review adversarial demostró que eso **falla
ABIERTO**, con dos poblaciones reales: un 2.º dispositivo *adoptado* de una cuenta **migrada** puede no
tener marcador —su propio belt lo dice, «ausente = no bloquea (solo diagnóstico)», y si el mirror no lo
importó en el adopt ya no lo importará nunca— y un botón del panel DEBUG lo borra a propósito para limpiar
marcadores stale. En los dos casos un migrado habría pasado por born-cloud y se habría llevado el
guardarraíl por delante, o sea el fallo exacto que este gate existe para evitar. La versión final es
`StorageModePersistence.isBornCloud`, que escribe **solo** el alta born-cloud
(`BornCloudSignUpService.activateBornCloudStorage`, no `writeCloudArmed`: a ése lo llama también el adopt).
Si la marca no está, se comporta como antes.

**El precio, aceptado y con ticket:** un born-cloud que entra en un SEGUNDO dispositivo no tiene la marca y
no verá el botón → `reverse-hidden-on-a-born-cloud-second-device`. Entre un falso negativo (no ves un botón
que podrías usar) y un falso positivo (puedes resucitar datos borrados), se elige el primero.

### D5 · ¿Qué pasa con el resto del motor de la reversa en born-cloud? → **funciona tal cual, medido**

- `reverseSeqCut()` sin marcador cae a 0 con breadcrumb, y el propio código lo declara correcto («since-0 es
  correcto, solo más caro»). Para born-cloud es además lo exacto: toda su vida es «época nube».
- `sweepZombies(sinceSeq: 0)` enumera los tombstones del backend y borra las filas vivas que los porten.
  Idempotente; en born-cloud aplica igual.
- `verifyRebinds()` cuenta identidades con `lastReboundAt != nil` → 0 en born-cloud. Inocuo.
- `healDuplicates()` es una auto-cura por contenido, independiente de haber migrado.
- Ninguno de los cuatro lee `ckRecordName`: verificado enumerando **todos** sus usos en `Yala/`. El docblock
  que decía «el mapa que la reversa NECESITA para borrar los records» describe una dependencia que no existe
  (la reversa no borra records de CloudKit: no hay una sola `CKModifyRecordsOperation` en el repo).

### D6 · El copy de la card **no se toca**, y va a ticket

«Tus datos regresan a tu dispositivo y a tu iCloud» le dice «regresan» a quien nunca estuvo ahí. Es cierto y
merece arreglo, pero `.claude/rules/l10n.md` dice «no reescribas copy que ya funciona» y son 16 locales: es
una decisión de voz, de Jürgen, no una corrección técnica que deba colarse aquí.
→ `revert-card-copy-says-datos-regresan-a-quien-nunca-estuvo`.

### D7 · Orden de despliegue: **la base antes que el cliente**

La migración es compatible hacia atrás en las tres poblaciones (un cliente viejo con el RPC nuevo: born-cloud
sigue con el botón oculto y no llama; el migrado se comporta igual; la ya-revertida deja de poder
re-reclamar, que es la corrección). Al revés no: un cliente nuevo contra el RPC viejo enseñaría el botón y el
servidor lo rechazaría. ⇒ el SQL entra en los dos entornos antes de que el build llegue a nadie.

---


## Device-QA · una cuenta nacida en la nube vuelve a iCloud y su histórico sube por primera vez

### Qué hay que comprobar, en una frase

Que una cuenta que nunca ha tocado iCloud puede volver al modo privado **y que sus datos llegan de
verdad a iCloud** — no solo que la app dice que sí.

### Por qué NO es simulable, y esto es la parte que importa

El motor de la reversa no sube nada a mano: **monta el mirror y deja que
`NSPersistentCloudKitContainer` exporte solo**. El efecto `.mountMirrorAndRelaunch` únicamente desarma
un flag (`MigrationWorkExecutor.swift:568-570`); tras el relanzamiento el store personal se monta con
`cloudKitDatabase: .private(...)` (`SwiftDataConfiguration.swift:1197-1202`) y el framework hace el
resto. La fase `reverseUpload` **sondea** ese progreso (`reverseUploadStatus`), no lo provoca.

Para un usuario migrado eso ya se verificó en device el 2026-07-11 (corrida verde del guion I11). Para
un born-cloud es **otro caso**: su corpus se escribió entero con el mirror desconectado, así que el
mirror tiene que exportar **todo**, no un delta. Y ese comportamiento exacto está anotado en el propio
repo como **no medido**: `Yala/App/Logic/WelcomeMirrorRelaunchLogic.swift` dice que un mirror adjuntado
en un arranque posterior exporte lo escrito en la ventana sin mirror es «plausible pero NO está
medido». Un simulador sin cuenta de iCloud real no puede contestar esa pregunta.

### Guion

Necesita **un iPhone con sesión de iCloud real** y una cuenta de Yala born-cloud con datos.

1. **Prepara la cuenta.** Alta nueva desde el Welcome por «Primera vez → nube» (Apple o Google), y
   crea corpus a mano: al menos 15-20 transacciones en 2-3 cuentas, algunas categorías propias, un
   presupuesto y un pago recurrente. Cuanto más variado, mejor: lo que se prueba es que sube TODO.
   - Comprueba en el panel DEBUG (`Ajustes → CloudSync Debug`) que dice
     **`eligible ✅ · born-cloud (sin marcador)`**. Si dijera `migrado`, la cuenta no es born-cloud y
     el caso es otro.
2. **Borra algo antes de empezar.** Elimina 2-3 transacciones y una cuenta entera. Esto arma el caso
   del barrido de zombies: esos borrados están en el backend como tombstones y **no deben reaparecer**
   al final. Apunta cuáles.
3. **Ajustes → «¿Dónde viven tus datos?» → «Volver a iCloud».** Pasa las **dos** confirmaciones.
4. **Sigue la barra hasta el final**, y cuando pida cerrar y reabrir la app, hazlo. Apunta cuánto
   tarda la fase «Volviendo a iCloud…» — para un corpus born-cloud puede ser **mucho** más que para un
   migrado, y ese número es el dato que este ticket busca.
5. **El testigo aritmético**, que es la prueba de verdad y no la pantalla: en el panel DEBUG mira el
   contador de testigos con `ckRecordName`. Al empezar tiene que ser **0** (born-cloud no tiene mapa) y
   al terminar tiene que haber **subido** hasta cubrir las filas vivas. Si se queda en 0 y la reversa
   dice que acabó, el mirror no exportó y el «sí» de la pantalla es falso.
6. **La comprobación externa**: en CloudKit Console, base **privada** del container personal, mira que
   los record types del corpus tienen registros. Antes de empezar deberían estar vacíos.
7. **Al final**: la app está en modo privado, el histórico completo está visible, y **lo que borraste
   en el paso 2 sigue borrado**.
8. **Segundo dispositivo (opcional pero es la prueba reina):** instala Yala en otro iPhone con el
   MISMO Apple ID y restaura desde iCloud. Tiene que aparecer el corpus entero.

### Criterios de aceptación

- [ ] El botón «Volver a iCloud» **aparece** en una cuenta born-cloud (antes estaba oculto).
- [ ] La reversa llega a `icloudActive` y la app queda en modo privado.
- [ ] El contador de testigos con `ckRecordName` pasa de 0 a ≥ el número de filas vivas.
- [ ] CloudKit Console muestra el corpus en la base privada.
- [ ] Lo borrado en el paso 2 **no** resucita.
- [ ] Queda anotado **cuánto tardó** la fase de subida y con cuántas filas.

### El fallo que hay que saber reconocer, y qué hacer

Si el mirror **no** exporta, la reversa **no** miente: se queda clavada en `reverseUpload` esperando
que el sondeo drene. Eso es fail-safe para los datos —nada se pierde, todo sigue en local y el backend
queda congelado— pero deja al usuario en un limbo con «Volviendo a iCloud…» puesto, y con el backend
**congelado** (`reverse_frozen_at` set ⇒ `/sync/push` responde 409 `yala_account_reverting`), o sea sin
poder escribir a la nube tampoco.

⇒ **Si eso pasa, no lo dejes ahí:** el panel DEBUG tiene la salida (`reverse_abort` / escape hatch), y
el caso merece ticket propio con el número de filas y el tiempo esperado. Sería el hallazgo más
valioso de esta corrida.

## Barrido de `qa` · 2026-09-23 · se queda para el iPhone

Está en la lista corta de device-QA del 2026-09-23 (`qa/guion-tanda.md`). Se prueba con **Yala Dev compilado desde `2.1`**: el TestFlight 13 es del 9-sep y no lleva los arreglos posteriores. Para cerrarlo basta con el guion entero del ticket (bloque E).
