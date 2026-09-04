---
updated: 2026-09-04
tags: [now, punto-de-retomada]
---

# NOW — 2026-09-04 (Lima)

**Rama** `2.1` · HEAD `953bf25b` — merge del PR #62, la web. TestFlight build **12** (CPV 12).
**Subida Yala (TF/store) = solo Mini.** **`yala-app.pe` sirve la web nueva desde hoy.**

## El día, en dos líneas

Por la mañana, el CI: llevaba día y medio sin ejecutar un solo test; se arregló, y al quitar la venda
aparecieron 16 XCUITest en rojo —ninguno un bug de la app— más el que sí lo era: a quien se une a un
grupo por enlace, la app no le reconocía hasta reiniciarla. Por la tarde, la web: auditada, rediseñada
y **desplegada en producción**.

## Te espera a ti

1. **Publicar la app.** Sin cambios desde ayer: los dos avisos de Grupos están completos en servidor
   y en los dos entornos; falta el cliente iOS. Ahora además llevaría el fix de identidad.
2. **La tanda de QA: 20 tickets en 4 montajes.** Guion en **`qa/guion-tanda.md`**, sin tocar.
3. **Dos decisiones de la web** (informe `Web/REVISION-WEB-UX-A11Y-2026-09-03.md` §9): el **texto legal
   de Grupos** —la web dice «vía iCloud, no por servidores nuestros» y el backend propio está al 100 %
   en prod— que dijiste revisar al lanzar 2.1; y si Vercel debe desplegar solo al mergear (hoy su rama
   de producción es `1.0`, así que **no**: el despliegue de hoy fue por CLI).

## Abiertos, por prioridad

- **`panel-defaults-four-sections-four-widgets`** — **implementado y en `qa`**. El Panel de un
  usuario nuevo pasa de 7 secciones y 9 widgets a 4 y 4. Los predeterminados se resuelven también en
  LECTURA, así que el arranque es correcto desde el primer frame; «Restablecer» pasa a devolver el
  curado. Unitarios 6029/0 y verificado en pantalla. Falta tu mirada en la tanda.
- **`group-joiner-flag-consumers-still-narrow`** (high) — el recién llegado ya se ve
  reconocido, pero su gasto no llega a su cuenta personal hasta un arranque posterior, y aterriza en
  la cuenta «Grupos» en vez de la real. Trece consumidores del flag siguen estrechos. El ticket trae
  la vía fácil y por qué es peligrosa.
- **`ci-verde-con-la-suite-en-rojo`** — pasos 1 y 2 hechos y documentados; **3 y 4 siguen fuera de
  alcance por decisión**. Queda sin diagnosticar por qué `systemsetup` aplicaba la zona 3 de 9 veces.
- **`invite-link-five-causes-one-message`** — sin tocar hoy. Piezas 2, 3 y 4 son código.
- Los **2 de `blocked`** esperan **hardware**, no trabajo.

## Release 2.1 (sin cambios)

2.0.5 no se lanza; release = 2.1. A7 y M5: **HOLD, no flip**. Prod: CLOUD_MODE 100 · GROUPS_BACKEND
100 · CLOUD_ONBOARDING_CHOICE 0 · SECONDARY_SESSION 0. Cola C: 9 ACs owner/device, no corrida; D-R1
sigue sin `ok_`. **Cero `ok_` inventado.**

## La web, cerrada hoy

PR #62 mergeado y **`yala-app.pe` desplegado**: auditoría + rediseño de la home. Lo que hay que saber
sin abrir nada: el idioma del visitante **ya se respeta** (hasta hoy todos aterrizaban en español),
accesibilidad AA en los dos temas, capturas nuevas del simulador y fuentes propias (fuera Google).
Al medir la app para el copy aparecieron **dos afirmaciones falsas** que la web llevaba tiempo
diciendo, ya corregidas. Todo —hallazgos, método, cifras y lo que quedó fuera— en
**`Web/REVISION-WEB-UX-A11Y-2026-09-03.md`**.

## Board

100 tickets · backlog 50 · in-progress 7 · qa 20 · blocked 2 · done 16 · discarded 5.
`qa` significa «esperando la tanda», no «cerrado».

**Lo que cambió en la red, y conviene saberlo:** el gate corría los XCUITest «de las áreas tocadas»
y 30 de las 59 áreas no cubrían el código del que dependen — por eso dio verde sobre el rediseño del
Panel que rompió siete suites. Corregido. Y las suites de Grupos estaban en verde por estado
pegajoso: un alert que solo sale la primera vez y cuya preferencia sobrevive entre corridas. Habrían
caído en un CI limpio.
