---
id: adopt-claim-stays-parked-with-no-ceiling
status: qa
priority: high
area: "modo-nube, migración, adopt"
created: 2026-09-22
updated: 2026-09-23
source: "review adversarial de `forward-migration-steps-have-no-ceiling-and-no-exit` (2026-09-22), lente de consumidores"
---

# Al entrar en tu cuenta de la nube, el paso del 22 % se puede quedar parado para siempre si la cuenta no está disponible

## El problema, en lenguaje de usuario

Cuando entras en una cuenta de la nube que ya existe —«Ya tengo una cuenta» en la bienvenida, o «Activar la nube en
este dispositivo» en Ajustes—, la app hace el mismo paso del 22 % que «Migrar a la nube». Si la red falla, esperar está
bien: en cuanto vuelve, la app reintenta sola y termina. Pero si el motivo es de los que esperar no arregla —la sesión se
borró, la cuenta la rechaza con un 403—, la barra se queda al 22 % sin salida, igual que antes del ticket
`forward-migration-steps-have-no-ceiling-and-no-exit`.

## Por qué quedó fuera de ese ticket (medido el 2026-09-22)

Ese ticket le puso techo y «Cancelar» al paso del claim, pero **solo con «Migrar a la nube»**
(`ForwardClaimIntent.migrateOnly`, término en `MigrationRunner.driveClaim` y en `ForwardCancelScope`). Con la
intención de adoptar, la salida del techo era un callejón:

- La salida (`failedRollback` → «Reintentar» → `notStarted`) deja la pantalla de Almacenamiento en `.idle`, que solo
  ofrece «Activar la nube en este dispositivo» con marcador de CloudKit (`StorageSettingsView`). Sin él, la tarjeta es
  «Migrar a la nube», y la puerta de identidad la bloquea porque la cuenta ya tiene datos.
- En una reinstalación que entra por el Welcome, el onboarding ya está marcado (`onAdoptStarted`) y no hay forma de
  volver a él.
- El texto de la tarjeta de fallo y el del diálogo de cancelar dicen «tus datos siguen en este dispositivo», que en un
  teléfono recién instalado es falso: los datos están en la nube.

El Welcome ya separa dos de esos motivos por su cuenta (`CloudWelcomeSignInFlow.phase`: 403 → `accountBlocked`, 401 →
error con reintento), pero solo mientras esa pantalla está delante; al salir de ella, el journal sigue en
`claimingMigration`.

## Qué habría que decidir

1. **A dónde sale un adopt que se rinde.** No puede ser «Migrar»: tiene que volver a un sitio desde el que la persona
   pueda entrar en su cuenta otra vez.
2. **Si se ofrece «Cancelar»** en ese paso, y con qué texto: la frase de hoy no sirve.
3. Si el 403 y la sesión borrada tienen que avisar ANTES del techo (hoy solo lo hace la pantalla del Welcome).

## Criterios de aceptación

- [x] El claim de un adopt tiene techo y una salida desde la que se puede volver a entrar en la cuenta.
- [x] Ningún texto le dice a la persona que sus datos siguen en un teléfono donde no los hay.
- [x] Test con el fallo persistente, midiendo que la fase cambia (`MigrationRunnerTests` §16).

## Relacionado

- `forward-migration-steps-have-no-ceiling-and-no-exit` — el techo de «Migrar», y el que dejó esto fuera.

## Paso 0 (2026-09-23, sesión autónoma)

El árbol entero, con lo medido, está en el encargo (`encargos/lanzados/2026-09-23-adopt-claim-stays-parked-with-no-ceiling.md`,
«## Paso 0 — decisiones»). Lo que manda:

1. **El mismo techo que «Migrar»**: 15 min acumulados con la sesión borrada o el 403, 72 h sin avanzar con cualquier causa.
2. **Salida a la tarjeta de fallo, con texto propio; «Reintentar» lleva a «Activar la nube en este dispositivo»**, aunque no
   haya marcador de CloudKit. El Welcome ya trata `.failed` con su propio «Reintentar», que resetea y vuelve a entrar.
3. **«Cancelar la activación» también en el claim del adopt**, con un cuerpo que habla de lo que hay en la nube.
4. **El 403 y la sesión borrada se avisan en la tarjeta del 22 %** en cuanto se miden, sin esperar el techo.

## Lo que se hizo

- `MigrationRunner.driveClaim`: los tres no-éxitos del claim pasan por el techo con las dos intenciones.
  `ForwardCancelScope.offersCancel(_:)` ofrece «Cancelar» en el claim sin mirar la intención.
- Marca nueva `MigrationState.adoptClaimExitRaw` y la cuenta a la que queda atada, `adoptClaimAccountHash` (schema 11): la
  cuenta se apunta al ENTRAR en el claim; la marca la escribe la salida del claim de un adopt —techo o «Cancelar»— en el
  mismo save. Las dos sobreviven a «Reintentar»; las borra el siguiente claim o volver a iCloud. `AdoptClaimScope` es el
  predicado único (runner y controller).
- Almacenamiento: la tarjeta de `.idle` ofrece «Activar la nube en este dispositivo» con la marca, sin sesión o con la de
  esa cuenta (`offersAdoptReentry`); tras firmar desde ella, otra cuenta no se adopta (`blocksReentry`, aviso
  `storage.errors.adoptOtherAccount`). La tarjeta de fallo, el diálogo de cancelar y el aviso del 22 % tienen texto de
  adopt; el aviso sale de lo que vio el último claim (`MigrationRunner.lastClaimDefinitiveCause`). Siete claves nuevas en
  los 16 idiomas.

## Review adversarial (2026-09-23, tres lentes independientes + refutación por hallazgo)

**Arreglado:**

1. **(consumidores, media) La marca abría la tarjeta de adopt a OTRA cuenta.** La tarjeta no pasa por la puerta de
   «Migrar»; con la sesión de Grupos de otra cuenta adoptaba esa y le subía lo local. Ahora la marca va atada a la cuenta
   del intento: con otra sesión la pantalla vuelve a lo de siempre, y tras firmar en el chooser otra cuenta se para sin
   claim.
2. **(consumidores, baja-media) La marca sobrevivía a volver a iCloud**, y ahí la tarjeta adoptaría una cuenta devuelta a
   iCloud, que es lo que «Migrar» para en su claim. Se borra al llegar a `icloudActive`.
3. **(estado + consumidores, media) El aviso del 22 % podía decir algo que ya no se observaba**: leía el reloj de causa,
   que al pausar conserva el motivo. Ahora lee lo que vio el último claim.
4. **(textos, media) «Lo que tienes en la nube sigue ahí, sin cambios»** afirmaba el estado del servidor, que otro
   dispositivo puede cambiar. Ahora dice lo que este dispositivo hizo: «Este dispositivo no cambió nada de lo que tienes en
   la nube». **El 403** usa la frase del Welcome («ahora mismo no podemos darte acceso a esta cuenta»), sin hablar de los
   datos. Y cinco bajos: el sujeto de «lleva días sin avanzar», el nombre del botón en inglés, el cuerpo del diálogo que
   nombraba «entrar» con un botón que dice «Activar», un alemán coloquial y un polaco redundante.
5. **(estado, baja) Tests que faltaban**: la marca con un intento que no llega al claim, el «sí» apuntado en el claim de
   un adopt, y la cuenta leída al entrar y no en cada observación.

**Aceptado, con su porqué:**

- **Tras días fuera, la primera observación puede rendirse al instante** (lente de estado): el reloj de avance cuenta el
  tiempo con Yala cerrada, como en «Migrar» (decisión de Jürgen del 2026-09-22). La salida ya lleva a volver a entrar.
- **Una fila sin intención (anterior a la v6) que venía de «Migrar»** se lee como adopt y le tocarían sus textos. Que se lea
  así ya pasaba; hace falta un claim aparcado desde antes del 16-sep.
- **La normalización de un journal con la fase ilegible conserva la marca**: la fila se leyó y la marca es la salida de
  `.idle`. Escrito en su docblock.
- **Tras la salida, el teléfono queda con el onboarding marcado y sin datos** (consumidores, preexistente): antes era una
  barra al 22 % para siempre; ahora es estable y su salida es la tarjeta de adopt. Con el kill-switch o sin App Attest no
  hay tarjeta, que es el diseño de siempre.

**Con ticket propio:**

- `adopt-follower-waits-for-the-leader-with-no-ceiling` — el seguidor, y un «Cancelar» confirmado con el claim en vuelo
  que contesta `claiming_in_progress` se pierde al pasar a `waitingForLeader`.
- `migrate-claim-does-not-announce-a-definitive-cause-before-its-ceiling` — el aviso temprano en «Migrar».
- `adopt-uploads-a-foreign-corpus-without-a-lineage-check` (anotado) — la tarjeta de adopt con marcador sigue sin la puerta.

## QA en dispositivo (lo que un teléfono SÍ puede comprobar)

Los techos (15 min de 403 o sesión borrada, 72 h sin red) no se montan a mano: los fijan `MigrationRunnerTests` §16 y
`ForwardStepCeilingLogicTests`. Lo que sí se ve en un iPhone es aparcar el claim del adopt sin red, cancelarlo y volver a
entrar.

**Montaje**
1. Build de **Yala Dev** (staging) en un iPhone que ya esté en modo nube con tu cuenta de staging (el «primer
   dispositivo»), y un **segundo iPhone** con Yala Dev en iCloud, con el mismo Apple ID de iCloud que el primero.
2. En el segundo iPhone, espera a que Ajustes → Almacenamiento enseñe **«Activar la nube en este dispositivo»** (llega con
   iCloud; si enseña «Migrar a la nube», espera unos minutos con Yala abierta).
3. La tarjeta tiene que decir «Usarás tu cuenta de Yala actual…». Si no lo dice, entra primero en la pestaña **Grupos**
   con tu cuenta de staging: sin sesión, firmar pide red y el paso 4 no se puede montar.

**Guion**
4. Toca «Activar en este dispositivo». Con el consentimiento en pantalla, activa el **modo avión**, y luego acéptalo.
   Esperado: la barra se queda al **22 %** con «Activando la nube…», «Retomar» y **«Cancelar la activación»** (antes de
   este cambio no salía ese botón). Si en vez de eso sale un error de inicio de sesión, el token necesitaba renovarse y
   sin red no puede: desactiva el modo avión, cierra y abre la sesión de Grupos, y repite el paso 4 enseguida (el token
   dura una hora). No es un fallo de este cambio.
5. Toca «Cancelar la activación». Esperado: el diálogo dice **«Este dispositivo no cambió nada de lo que tienes en la
   nube. Puedes volver a activar la nube en este dispositivo desde aquí cuando quieras.»** — no «Tus datos siguen en este
   dispositivo».
6. Toca «Seguir activando la nube». Esperado: nada cambia, sigue al 22 %.
7. Toca otra vez «Cancelar la activación» → «Sí, cancelar». Esperado: vuelve la tarjeta **«Activar la nube en este
   dispositivo»**, no «Migrar a la nube».
8. Cierra Yala del todo y ábrela. Esperado: en Almacenamiento sigue **«Activar la nube en este dispositivo»**.
9. Quita el modo avión y toca «Activar en este dispositivo». Esperado: la activación termina como siempre.

Qué NO mide este guion: en este montaje la tarjeta de adopt ya salía por el marcador de CloudKit. El caso que la marca
nueva arregla —un teléfono sin marcador, típicamente reinstalado y entrado por el Welcome— no se puede aparcar a mano
(la ventana entre firmar y el claim es de milisegundos), y lo fijan los tests.
