---
id: reverse-verify-network-bucket-hides-a-definitive-server-no
status: qa
priority: medium
area: "modo-nube, migración"
created: 2026-09-21
updated: 2026-09-22
source: "review adversarial de `reverse-pre-mount-ceiling-has-no-alert-and-leaves-network-verify-out` (2026-09-21), lente de la máquina — confirmado midiendo la cadena entera"
---

# Un «no» definitivo del servidor que llega por el Merkle se lee como falta de cobertura, y ahora espera 72 horas

## El problema, en lenguaje de usuario

Estoy volviendo a iCloud y mi cuenta en la nube deja de estar disponible justo en el paso de comprobación. La app no me
dice nada: la barra se queda parada en «Comprobando que todo llegó…» y ahí sigue **tres días**, como si fuera mi
conexión. No es mi conexión, y esperar no lo arregla.

Lo mismo si lo que falla es la base de datos local del teléfono al leer la cola de subida: la app lo lee como «no hay
red» y espera igual.

## Por qué pasa (medido el 2026-09-21)

La cadena, leída entera:

1. `SyncMerkleClient.fetchMerkle` sí distingue: `401 → .sessionExpired`, `403 → .accountUnavailable`, resto `.transient`.
2. **`SyncMerkle` lo aplana**: `guard case .snapshot(let remote) = outcome else { return .skipped(reason: "fetch-failed") }`.
   Los tres desenlaces mueren ahí y salen con la misma palabra.
3. `VerifyProbeMapping.map` manda `"fetch-failed"` —y también `"outbox-fetch-failed"`, `"quarantine-fetch-failed"` y el
   `default` de cualquier `reason` que este build no conozca— a **`.networkTimeout`**.
4. Desde el 2026-09-21 `driveReverseVerify` manda `.networkTimeout` al techo de la etapa con `blocker: nil`, o sea al
   presupuesto **LARGO: 259 200 s (72 h)**.

Así que `.networkTimeout` no es «no hay red»: es un cajón que incluye un `403` definitivo, un `401`, dos `fetch` de
SwiftData que lanzaron y cualquier motivo futuro. Para la mitad que **no es red**, el techo largo es generoso: no se va
a resolver sola.

**El alcance está acotado, y conviene decirlo.** En `verify()` el push y el pull corren ANTES del Merkle y los dos
tipan su 401 y su 403 (`.sessionExpired` / `.blocked(.accountUnavailable)`). La ventana es la del `403` (o `401`) que
empieza **entre el pull y el Merkle**, más los fallos locales de SwiftData, más un `reason` futuro. Con el outbox vacío
—el caso normal de la vuelta, que no sube— el push se salta entero, así que el único filtro previo es el pull.

**Qué se perdió y qué se ganó.** Antes de ese ticket esta mitad gastaba los 8 reintentos de red y degradaba a
`reverseFailedRollback` en minutos: un terminal feo, pero **visible**, con su tarjeta y su «Reintentar». Ahora espera
en silencio. El canario `cloudReversePreMountWaiting` se emite en cada observación, así que a nivel de flota sigue
siendo visible; a nivel de dispositivo, no.

No se arregló en el ticket que lo destapó porque el arreglo está **aguas arriba**, en `SyncMerkle`, que comparten la
ida y el motor de sincronización: es alcance propio con su propia QA.

## Qué habría que decidir antes de hacerlo

1. **Dónde se tipa.** Lo natural es que `SyncMerkle` deje de aplanar y propague `.sessionExpired` /
   `.accountUnavailable` como hacen el push y el pull. Eso toca a los tres consumidores, no solo a la vuelta.
2. **Qué hace la IDA con lo tipado.** Hoy la ida agrupa red, sesión y `blocked` en su rama de red a propósito
   (`forward-verify-reads-an-expired-session-as-network`). Si el Merkle empieza a tipar, la ida hereda la pregunta.
3. **Los fallos LOCALES** (`outbox-fetch-failed`, `quarantine-fetch-failed`) no son del servidor ni de la red: ¿techo
   corto, terminal propio, o se quedan donde están?
4. **El `default` de un `reason` futuro.** Hoy cae en «conservador». Con el techo largo detrás, «conservador» significa
   72 h; puede que ya no sea la lectura conservadora.

## Paso 0 — decisiones (2026-09-22, noche Frank)

Las cuatro preguntas de arriba, contestadas antes de tocar código. La cadena se midió entera primero
(`SyncMerkleClient.fetchMerkle` → `SyncMerkle.verifyIntegrity` → `VerifyProbeMapping.map` →
`MigrationWorkExecutor.verify()` → `driveReverseVerify` / `driveVerify`).

1. **Dónde se tipa: en `SyncMerkle`.** `MerkleVerdict` gana dos casos TIPADOS —`.sessionExpired` y
   `.accountUnavailable`— y `verifyIntegrity` deja de aplanar el outcome del fetch. Es lo que ya hacen el push y
   el pull, y el compilador obliga a cada consumidor a contestar (`switch` exhaustivo), que es justo lo que un
   `reason` string no puede exigir.
2. **La IDA no cambia.** `driveVerify` ya agrupa `.networkTimeout, .sessionExpired, .blocked` en su rama de red,
   así que el tipado nuevo llega y no mueve nada. Se fija con tests, y el ticket hermano
   `forward-verify-reads-an-expired-session-as-network` sigue aparte.
3. **Los fallos LOCALES** (`outbox-fetch-failed`, `quarantine-fetch-failed`) → `.blocked(.localFailure)`: techo
   CORTO (900 s) y salida con `preMountStalled` — sin correo de soporte, porque reintentar SÍ puede funcionar.
   No hay terminal nuevo: se reusan los dos `ReverseAbortReason` que ya existen.
4. **El `default` de un `reason` desconocido** → `.blocked(.unknownVerdict)`: techo CORTO y salida con
   `preMountRefused`. Es el molde que el repo ya eligió para el claim (`claimRefused` acoge «un motivo que este
   build no conoce» a propósito): un motivo que nadie sabe leer no se presume pasajero. El canario
   `migrationVerifyUnknownReason` sigue emitiéndose igual, por `isUnknownSkip`.
5. **El 401 y el 403** salen por los casos tipados, así que encienden respectivamente el aviso de «vuelve a
   entrar» (`noteReverseSessionExpiry(.verify)`) y el techo corto del `blocked`. El runner NO cambia: sus dos
   ramas ya existían y estaban vacías de este camino.
6. **Grupos NO se toca.** `GroupsSyncClient.verifyGroupIntegrity` sigue aplanando su fetch, y su único caller
   agrega `.diverged`: añadir casos al enum es aditivo y no cambia su comportamiento. Alcance propio si algún día
   se quiere.
7. **`CloudSyncRuntime.runMerkleVerification` tampoco cambia**: solo mira `if case .diverged`, así que un 401 o un
   403 del Merkle periódico se comporta exactamente igual que antes (no remedia). La sesión la gestiona el runtime
   por su cuenta, aguas arriba.

## Criterios de aceptación

- [x] Decidido 1-4 antes de tocar código (`## Paso 0`).
- [x] Un `403` que solo ve el Merkle elige el techo CORTO (900 s) en la vuelta.
- [x] Un `401` que solo ve el Merkle enciende el aviso de «vuelve a entrar» de la vuelta — y **solo el que de
      verdad es una sesión**: el `yala_attest_required` y el token que no llega sin red salen pasajeros.
- [x] La IDA no cambia, con test que lo fija (`forwardVerify_typedMerkleOutcomes_stillSpendTheNetworkBudget`).

## Relacionado

- `reverse-pre-mount-ceiling-has-no-alert-and-leaves-network-verify-out` — el que metió la red en el techo y destapó esto.
- `reverse-before-mount-has-no-way-to-abandon-the-return` — el techo de la etapa.
- `forward-verify-reads-an-expired-session-as-network` — la misma pregunta por el lado de la ida.

## Cómo quedó (2026-09-22)

**Lo que cambia para quien vuelve a iCloud.** Si la cuenta en la nube deja de estar disponible justo en el paso de
comprobación, la app ya no se queda tres días en «Comprobando que todo llegó…»: a los 15 minutos vuelve al sitio de
donde salió y deja dicho por qué. Si lo que caducó es la sesión, sale la tarjeta de «vuelve a entrar» en vez del
silencio. Y si el fallo es de la base de datos del propio teléfono, tampoco espera tres días por algo que no es la
conexión.

**Lo que NO cambia, a propósito.** El 401 conserva el techo largo: a la sesión la renueva la persona, y ahora la ve
pedida mucho antes de que venzan las 72 h. Lo que se le quitó fue el silencio, no la espera. La IDA tampoco cambia.

**Lo que la review cazó, y era mío.** Tres lentes independientes, siete defectos:

1. **El Merkle era el único cliente del canal sin `canRenewSession` ni la rama de `yala_attest_required`.** Daba igual
   mientras su desenlace se aplanaba en «red»; en cuanto empezó a encender el aviso de «vuelve a entrar», pedía firmar
   otra vez a quien solo estaba sin cobertura y a quien no puede acuñar App Attest. Los dos términos, cableados en las
   dos construcciones de producción y custodiados por `AttestWiringTests`.
2. **`.unknownVerdict` salía con `preMountRefused`**, cuyo copy dice «tu cuenta en la nube no lo permitió» y da el
   correo de soporte. Ese motivo lo escribe una función LOCAL, no el servidor: la persona leía una causa inventada y
   soporte recibía correos por un desajuste de contrato del cliente. Pasa a `preMountStalled`, con el techo corto
   intacto.
3. **El canario decía `server_<motivo>`** para dos motivos que no son del servidor: quien lee el dashboard contaría
   averías del teléfono como incidentes del backend. Renombrado a `stop_`; la serie cambia de valores con este build.
4. **El literal del `reason` era una junta medida contra sí misma**: el test del mapping construía el veredicto con el
   mismo literal que consumía, así que un renombrado a un solo lado cambiaba el desenlace en producción sin un rojo.
   Cerrado por construcción con `MerkleSkipReason`.
5. **Tres tests míos no podían fallar** (un `Set` de rawValues que garantiza el compilador, un recorrido de `blocked`
   subsumido por los tres casos de arriba, y una tanda de `!=` implicados por sus `==`) y **uno prometía más de lo que
   medía** (los guards antes del fetch se afirmaban con el veredicto, que no cambia; ahora se cuentan las peticiones).
6. **Un test duplicaba una fila que ya existía** sin añadir un mutante.
7. **Cinco premisas de las reglas de área y dos comentarios del runner** quedaban falsos con el cambio.

**16 mutantes verificados**, 352 casos en 8 suites. Dos residuales salen con ticket propio:
`reverse-pre-mount-ceiling-charges-a-stall-to-whoever-stops-it-last` (el reloj del techo es de la FASE y la causa de
la ÚLTIMA observación, así que un fallo local aislado tras horas de espera por red saca en el acto) y
`verify-reads-a-failed-local-fetch-as-an-empty-outbox` (el mismo `fetch` leído con signos opuestos a veinte líneas de
distancia).

## Guion de QA (device, iPhone)

Hace falta una cuenta en la nube con la migración terminada y el teléfono en modo nube. **El 403 no se puede montar
desde el teléfono**: se provoca en staging.

1. En Ajustes → «¿Dónde viven tus datos?», toca **«Volver a iCloud»** y acepta. La barra debe pasar del claim al
   drenaje.
2. **Caso del 403.** Con la vuelta en «Comprobando que todo llegó…», suspende la cuenta en staging (el gateway debe
   responder 403 a `/sync/merkle`). Vuelve a abrir Yala.
   - **Espera:** la vuelta sigue ahí unos minutos y, pasados **15**, la tarjeta desaparece y queda la nota «no pudimos
     terminar de volver a iCloud: tu cuenta en la nube no lo permitió», con el correo de soporte. **No** debe tardar
     tres días.
3. **Caso del 401.** Restaura la cuenta, relanza la vuelta y, con la barra en la comprobación, invalida la sesión en
   Supabase.
   - **Espera:** sale el aviso de **«vuelve a entrar»** con su botón. Al firmar, la vuelta sigue **desde donde
     estaba**, no desde el principio.
4. **Control de la red.** Relanza la vuelta y pon el teléfono en modo avión durante la comprobación.
   - **Espera:** NO sale «vuelve a entrar» (es red, no sesión) y la vuelta **sigue esperando** — a los 15 minutos no
     se ha ido a ninguna parte.
5. **Control del attest.** En un teléfono sin App Attest (o con el token forzado a fallar), repite el paso 4.
   - **Espera:** tampoco sale «vuelve a entrar». Pedir firmar ahí no arregla nada.
