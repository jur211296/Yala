---
id: reinstall-without-network-has-no-cloud-door
status: done
priority: medium
area: "modo-nube, welcome, remote-config"
created: 2026-09-17
updated: 2026-09-23
source: "review adversarial de `previous-person-cloud-session-survives-fresh-start-and-reinstall` (lente de puertas), 2026-09-17"
qa-status: not-replicable
qa-date: 2026-09-23
qa-notes: barrido 2026-09-23 sin device-QA - solo cambia el texto de Restaurar sin red; WelcomeRestoreEmptyOutcomeTests
---

# Quien reinstala y arranca sin red no tiene puerta a su cuenta en la nube, y el mensaje que ve es falso

## El problema, en lenguaje de usuario

Tengo Yala con mi cuenta en la nube. Cambio de móvil, o borro la app y la reinstalo, y la abro en el
avión o con el wifi caído. El Welcome solo me ofrece «Restaurar desde iCloud», que me contesta **«No
encontramos tus datos»** — con mis datos intactos en el servidor. No hay ninguna forma de entrar con mi
cuenta hasta que la app hable con el servidor y vuelva a abrir el arranque.

## No es el kill-switch (ése es `reentry-killswitch-closes-both-doors`)

Medido el 2026-09-17, con el kill-switch APAGADO —`CLOUD_MODE_ROLLOUT_PERCENT = "100"` en el bloque de
producción de `gateway/wrangler.toml`—:

- `CloudRemoteFlags.absentDefault` es `false` en release: antes del primer fetch la nube está cerrada.
- El snapshot del flag remoto vive en `UserDefaults.standard`, key `cloudSync.remoteConfig.snapshot`
  (`CloudRemoteConfig.swift`). Vive en el contenedor de la app ⇒ **se va al reinstalar**.
- Sin snapshot y sin red, `WelcomeAccountChoiceLogic.visibleExistingOptions` devuelve solo
  `[.restoreICloud]`, y `bypass()` manda directo a Restaurar sin enseñar sub-chooser.
- El refresco que el Welcome dispara va **sin `force`** (`WelcomeFlowContainer`), y la propiedad que
  dibuja las cards no tiene live-update: su propio comentario lo dice.
- `WelcomeRestorePauseLogic.isCloudPaused` (hoy `WelcomeRestoreEmptyOutcome.resolve`) exige `beaconLinked`, que sale del iCloud-KV; en un móvil
  recién reinstalado y sin red ese KV tampoco ha sincronizado, así que el mensaje honesto —«la nube está
  en pausa»— tampoco sale. Queda el equivocado.

⇒ **es una ventana que existe SIEMPRE tras reinstalar, no solo bajo el kill.** El ticket hermano describe
el kill-switch encendido; éste, el hueco previo al primer fetch.

## Por qué sale ahora

`previous-person-cloud-session-survives-fresh-start-and-reinstall` retira la sesión anterior en el primer
arranque tras instalar, que es lo correcto y lo que Jürgen decidió. Antes de ese cambio la sesión
sobrevivía en el llavero: no abría ninguna puerta nueva —las cards estaban igual de cerradas— pero sí
significaba que las superficies que la reusaban en silencio seguían funcionando. Ahora el camino de vuelta
es la ÚNICA salida, y en esta ventana no existe.

## Lo que hay que decidir (Jürgen)

1. **Reintentar el fetch y repintar**: el Welcome pide el config con `force` y las cards se re-evalúan al
   llegar. No arregla el caso sin red.
2. **Un tercer estado en Restaurar**: cuando no se ha podido preguntar por la nube, decir «no hemos podido
   comprobar tu cuenta en la nube — conéctate y vuelve a intentarlo» en vez de «no encontramos tus datos».
3. **Persistir el snapshot fuera del contenedor** (iCloud-KV o App Group), para que sobreviva a reinstalar.
   Es el único que abre la puerta de verdad sin red, y a cambio el flag deja de ser revocable de golpe.

## Criterios de aceptación

- [x] Tras reinstalar y sin red, quien tiene cuenta en la nube NO lee «no encontramos tus datos».
- [x] Decidido y escrito si el camino a la cuenta existe sin red o si solo se corrige el mensaje.
      **Solo el mensaje** (opción 2). El camino sin red queda fuera: es la opción 3, que el propio
      ticket describe y que Jürgen aparcó.

## Relación con otros tickets

- `reentry-killswitch-closes-both-doors` — la misma pantalla con el kill-switch ENCENDIDO.
- `previous-person-cloud-session-survives-fresh-start-and-reinstall` — de donde sale.
- `beacon-routes-only-never-blocks` — el faro, que aquí tampoco puede encaminar.

## Decisión Jürgen (2026-09-17)

**Opción 2:** mensaje honesto en Restaurar cuando no se pudo comprobar la nube (no fingir «no encontramos tus datos» si solo falló la comprobación / no hay red).

No ahora: persistir snapshot fuera del contenedor (opción 3). Opción 1 sola no basta para el caso sin red.

## Lo implementado (2026-09-17)

**En lenguaje de usuario.** Reinstalo Yala —o estreno móvil— y la abro sin conexión. La pantalla de
Restaurar ya no me dice «No encontramos tus datos» con mi histórico intacto en el servidor: me dice
**«No pudimos comprobar tus datos»** y me ofrece reintentar. Si toco «Empezar desde cero» desde ahí,
la app me pregunta antes, porque nadie sabe todavía si tengo algo que perder.

### La review adversarial cambió la decisión, y el cambio importa

El primer intento mandaba a `.cloudUnverified` **todo** lo que llegara sin snapshot, faro incluido. Una
lente midió lo que eso costaba: a quien tiene faro puesto le retiraba «tus datos siguen a salvo en tu
cuenta de Yala» —la única frase que le dice la verdad— y lo cambiaba por «no pudimos comprobar». Y esa
población existe porque **las dos señales viajan por canales distintos**: el faro vive en el iCloud-KV
y el snapshot lo sirve nuestro gateway, así que una red que filtre su dominio, un 5xx o una caída de
Cloudflare dejan el faro puesto con el snapshot ausente.

⇒ **el faro decide primero.** `.cloudUnverified` es el desenlace de quien no tiene NINGUNA de las dos
señales, que es exactamente el móvil recién instalado del ticket.

Y el copy perdió el «Revisa tu conexión» por la misma medición: la comprobación que falla es la
NUESTRA, no la del wifi de la persona. Decirle que revise su router cuando el caído es nuestro Worker
la manda a arreglar algo que funciona. El icono dejó de ser un `wifi.exclamationmark` por lo mismo.

### La señal, y por qué esa

El desenlace lo decide `WelcomeRestoreEmptyOutcome.resolve` con tres términos, y el nuevo es
`cloudConfigKnown`: **¿ha llegado el servidor a contestarnos alguna vez en esta instalación?** Se
responde con la presencia del snapshot de remote-config, que vive en el contenedor de la app y se va
al reinstalar. Sin él no se puede afirmar ni que la nube esté en pausa —eso exige saber qué dice el
kill— ni que no haya datos.

Medido y descartado: usar el `settled` de `waitForImportQuiescence` (el timeout de la búsqueda de
CloudKit). Su propia nota lo dice — un store que nada importa, o sea un usuario realmente nuevo,
nunca dispara `.importEvent` y agota los 90 s igual que un teléfono sin red. Habría cambiado una
mentira por otra, y encima con minuto y medio de espera.

### Qué cambia de comportamiento, además del caso del ticket

Sin snapshot y con el faro puesto, hasta hoy salía `.cloudPaused` — «la nube de Yala está en pausa»,
afirmado sin que nadie hubiera preguntado. Ahora gana `.cloudUnverified`. **El kill-switch real no
cambia en nada**: con el kill puesto hay snapshot (percent 0), así que ese recorrido —el del ticket
hermano `reentry-killswitch-closes-both-doors`— sigue enseñando su aviso de pausa.

### Lo que queda fuera, a sabiendas

- **La puerta a la cuenta sin red sigue sin existir** (opción 3, aparcada). Este ticket corrige lo
  que se dice, no lo que se puede hacer.
- **La búsqueda de CloudKit no se toca.** Sin red falla por la misma causa que el config, así que la
  señal elegida ya cubre el recorrido; no hay oráculo limpio que distinga «CloudKit vacío» de
  «CloudKit inalcanzable».
- **Falso positivo aceptado:** con red buena y el gateway de Yala caído (5xx, DNS, una red que filtre
  su dominio), un teléfono SIN faro en su primera instalación lee «No pudimos comprobar» en vez de «no
  hay datos». Es cauteloso, no culpa a nadie y tiene salida; afirmar el vacío sería peor. Con faro, ese
  mismo teléfono lee el mensaje de la pausa, que le dice lo que importa.
- **Reinstalar CON red, con el iCloud-KV aún sin sincronizar**, sigue dando «no encontramos tus datos».
  Es el gemelo de este ticket y es anterior a él: ticket
  `restore-beacon-may-not-have-synced-yet-on-a-fresh-install`.
- **«Reintentar» cuesta hasta 90 s** porque relanza la búsqueda de CloudKit entera cuando lo único que
  falta es el fetch del config. Es idéntico al de `.cloudPaused`, ya ratificado; no se toca aquí.
- **`.cloudUnverified` es inalcanzable bajo unit y XCUITest** (el corte de host de test lo impide), así
  que su única red de comportamiento es el device-QA de abajo. Un seam que forzara el predicado dejaría
  ciego al test que lo usara. Mismo trato que el aviso del attest personal.

## Validación

- Build ×2 (`Yala` y `Yala Dev`), cero warnings nuevos en los ficheros tocados.
- Unit: 17 casos en 3 suites (`WelcomeRestoreEmptyOutcomeTests`, `RestoreStartFreshGateTests`,
  `RemoteFlagDecisionLogicTests`) + las 7 suites del Welcome y `LocalizationParityTests`.
- Unit: 74 casos en 8 suites tras la review.
- **7 mutantes compilados y corridos**, listados en la cabecera de `WelcomeAccountChoiceLogicTests`:
  la decisión de antes del ticket (6 fallos), la ausencia fallando cerrada (3), el estado nuevo
  descartando sin confirmar (4), el swap de estado que compila (3), la lectura del testigo guardada
  por encima del `await` (3), el adaptador cableado a una constante (3) y **el desconocimiento ganando
  al faro** (4) — este último es el bug que la review cazó, y ahora tiene red.
- **Review adversarial con tres lentes** (poblaciones · mecánica · reglas de área contra el diff).
  Tumbó cinco cosas mías: la precedencia del faro, el copy que culpaba a la conexión, `es-AR` sin
  voseo, un ancla de test que medía la etiqueta del argumento en vez de la lectura, y tres
  afirmaciones que declaré sin medir.

## QA en iPhone (lo que el simulador no prueba)

El simulador no tiene CloudKit ni cuenta en la nube, así que el recorrido entero es device-QA.

1. Con Yala instalada y sesión en la nube viva, comprueba que sincroniza (Ajustes → dónde viven tus datos).
2. **Borra la app** del iPhone (borrar la app, no «Empezar desde cero»: hay que llevarse el contenedor).
3. **Modo avión ON**, y wifi apagado. Sin conexión de ningún tipo.
4. Instala Yala de nuevo desde TestFlight y ábrela **sin salir del modo avión**.
5. «Ya tengo una cuenta» → «Restaurar desde iCloud». Espera a que termine la búsqueda.
   **PASS:** sale «No pudimos comprobar tus datos». **FAIL:** sale «No encontramos tus datos».
6. Toca «Empezar desde cero» desde esa pantalla. **PASS:** pregunta antes de nada.
   Cancela — no confirmes, que borra.
7. **Modo avión OFF.** Toca «Reintentar búsqueda». **PASS:** el mensaje deja de salir (pasa a
   encontrar los datos, o a «no encontramos» si de verdad no hay nada en iCloud).
8. Camino feliz, control: con red desde el principio, «Restaurar desde iCloud» sobre una cuenta con
   datos se comporta como siempre. **FAIL si aparece el mensaje nuevo con conexión buena.**
9. En Console.app, filtrando por `RestoreFlow`, el paso 5 deja `CLOUD-UNVERIFIED` y el paso 7 no.

## Residuales que abrieron ticket propio (de la review)

- `restore-says-no-data-when-the-icloud-import-never-settled` (**high**): el canal gemelo, y con más
  población. Si el import de CloudKit no asienta en 90 s, la pantalla dice «no hay datos» y ofrece
  «Empezar desde cero» **sin confirmar**. Puede perder datos.
- `restore-beacon-may-not-have-synced-yet-on-a-fresh-install` (medium): reinstalar con red mientras el
  faro aún no ha llegado.
- `restore-unverified-message-depends-on-a-single-gateway-host` (low): la guarda fail-abierto mide
  Supabase y el fetch va al Worker de Cloudflare.

## Barrido de `qa` · 2026-09-23 · cerrado sin device-QA

Sale de la cola de device-QA por el barrido que pidió Jürgen el 2026-09-23 (encargo `2026-09-23-barrido-qa-in-qa-pre-device`). Solo cambia el texto que ve quien abre Restaurar sin red. Lo cubren `WelcomeRestoreEmptyOutcomeTests` y `RestoreStartFreshGateTests`.
