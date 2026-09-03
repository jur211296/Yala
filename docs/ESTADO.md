---
updated: 2026-09-03
tags: [now, punto-de-retomada]
---

# NOW — 2026-09-03 (Lima)

**Rama** `2.1` · TestFlight build **12** (CPV 12). **Subida Yala (TF/store) = solo Mini.**
Gateway de producción: **desplegado** (versión `6f033324`, 16:42 UTC del 3).

## QA: aplazado al final, en una tanda (decisión del owner, 2026-09-03)

**Nada de `tickets/qa/` se drena sobre la marcha.** Se acumula y se hace todo junto al final, cuando
haya masa suficiente para que una sola sesión de simulador y una sola pasada de device rindan. Son
**19 tickets** hoy, y varios comparten montaje: los dos de push necesitan los MISMOS dos teléfonos, y
los tres de Welcome (`welcome-fresh-start-alert-leaves-blank-screen`,
`welcome-start-fresh-wipes-before-ask`, `welcome-copy-blames-owner`) el mismo recorrido.

**Qué NO significa:** que un ticket en `qa/` esté terminado. Significa que su código está hecho y
verificado hasta donde el simulador alcanza, y que la comprobación en aparato real está pendiente y
agrupada. Al leer el board, `qa` es «esperando la tanda», no «cerrado».

**Y no cambia el gate:** cada commit sigue pasando build, unit y los XCUITest de su área. Lo que se
aplaza es el QA manual y de device, no la verificación automática.

## Te esperan a ti

1. **Verificar el push con dos teléfonos reales.** App Attest en `enforce` lo hace imposible desde
   simulador o build de Xcode. Lo medido es que el gateway compone y envía lo correcto; **que Apple
   entregue el banner, no**. Una sola pasada cubre `aviso-de-nuevo-miembro` y
   `groups-expense-notif-only-on-foreground`. Si no llega: `Ajustes → Yala → Notificaciones` en el
   receptor — el único ticket cerrado sobre esto era el permiso apagado, y APNs devuelve 200 igual.
   **Nada la bloquea**: `g8_03` está aplicado a producción (las dos RPC existen con su grant a
   `yala_push`, verificado contra la BD el 2026-09-03) y el Worker está desplegado. Un aviso anterior
   decía lo contrario por inferir «no está hecho» de «no consta en el repo» — el estado del servidor
   se comprueba contra el servidor.
2. **`hasCompletedOnboarding`: par escritor/lector partido.** Un escritor y cuatro lectores repartidos
   entre dos dominios. Es una decisión, no trabajo; las dos salidas están en
   `secondary-visitor-writes-owner-domain`.
3. **D4 · consent legacy (RGPD)**, decidido «custodiar y reponer» y sin implementar. Dos riesgos que el
   ticket no traía: `GroupsConsentState` escribe en `.standard` a pelo (el dominio por sesión **no** lo
   cubrió) y la reposición cae en la ventana donde un borrado mal dirigido arrasaría el `UserDefaults`
   entero de la dueña.

## Abiertos, por prioridad

- **`ci-verde-con-la-suite-en-rojo`** (in-progress) — pasos 1 y 2 hechos; 3 y 4 fuera de alcance por
  decisión. Promover a bloqueante exige refutar el `EXC_BREAKPOINT`, y una corrida verde no lo refuta.
- **Los otros 7 de `in-progress`** son la familia «móvil prestado / invitado», sin tocar desde el
  26-ago: **esperan decisión, no código.**
- Código pendiente, por valor: **`invite-refresh-forzado-es-noop-si-hay-otro-en-vuelo`** (**high**) ·
  **`undercount-dias-intervalos-cerrados`** (~7-10 sitios; helper único ya elegido) ·
  **`canarios-y-breadcrumbs-sin-emisor`** · **`fx-partial-rate-rows-silent-1to1`** (**high**) ·
  **`scheduled-payment-once-labeled-monthly`** (low, el más barato).
- Los **2 de `blocked`** no esperan decisión ni código: esperan **hardware** (dos aparatos con el mismo
  iCloud; dos iPhones con TestFlight).

## Release 2.1 (sin cambios)

2.0.5 no se lanza; release = 2.1. A7 y M5: **HOLD, no flip**. Prod: CLOUD_MODE 100 · GROUPS_BACKEND 100
· CLOUD_ONBOARDING_CHOICE 0 · SECONDARY_SESSION 0 (verificado el 3 contra `/config` vivo). Cola C: 9 ACs
owner/device, no corrida; D-R1 sigue sin `ok_`. **Cero `ok_` inventado.**

## Board

93 tickets · backlog 48 · in-progress 8 · qa 17 · blocked 2 · done 13 · discarded 5. Índice cuadrado
(93 filas = 93 ficheros, verificado por diff). Credenciales de test del gateway: `qa/cloud/README.md`.
