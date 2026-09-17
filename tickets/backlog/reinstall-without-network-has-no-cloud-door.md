---
id: reinstall-without-network-has-no-cloud-door
status: backlog
priority: medium
area: "modo-nube, welcome, remote-config"
created: 2026-09-17
source: "review adversarial de `previous-person-cloud-session-survives-fresh-start-and-reinstall` (lente de puertas), 2026-09-17"
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
- `WelcomeRestorePauseLogic.isCloudPaused` exige `beaconLinked`, que sale del iCloud-KV; en un móvil
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

- [ ] Tras reinstalar y sin red, quien tiene cuenta en la nube NO lee «no encontramos tus datos».
- [ ] Decidido y escrito si el camino a la cuenta existe sin red o si solo se corrige el mensaje.

## Relación con otros tickets

- `reentry-killswitch-closes-both-doors` — la misma pantalla con el kill-switch ENCENDIDO.
- `previous-person-cloud-session-survives-fresh-start-and-reinstall` — de donde sale.
- `beacon-routes-only-never-blocks` — el faro, que aquí tampoco puede encaminar.

## Decisión Jürgen (2026-09-17)

**Opción 2:** mensaje honesto en Restaurar cuando no se pudo comprobar la nube (no fingir «no encontramos tus datos» si solo falló la comprobación / no hay red).

No ahora: persistir snapshot fuera del contenedor (opción 3). Opción 1 sola no basta para el caso sin red.
