---
id: device-qa-cloud-killswitch-groups-door
status: done
priority: high
area: "modo-nube, settings, groups"
created: 2026-09-11
source: "`cloud-killswitch-hides-the-only-door-to-detach-groups`"
updated: 2026-09-16
qa-status: passed
qa-date: 2026-09-16
---

# Device-QA · con el kill de la nube bajado, la puerta para soltar la cuenta de grupos sigue ahí

**SÍ es simulable en el simulador**, y esto es lo primero que hay que saber: no hace falta tocar el
gateway ni bajar el percent de producción. El panel DEBUG de un build **Yala Dev** trae el toggle.

**Lo que NO se puede medir en XCUITest** (por eso esto es QA a mano): bajo `-uitest`,
`CloudRemoteFlags.decide()` corta en su primera línea y devuelve `absentDefault`, que con el scheme del
gate (`Yala Dev`, `DEV_BUILD`) es `true`. Con el scheme `Yala` sí baja —medido el 2026-09-11— pero un
test cuyo veredicto cambie de signo según el scheme rompería el CI.

## El montaje, paso a paso

1. Build e instalación del scheme **Yala Dev** en el simulador iPhone 17 Pro.
2. Completa el onboarding en **privado** (iCloud), NO en la nube.
3. Asocia una cuenta de grupos: Ajustes → «¿Dónde viven tus datos?» → Grupos → «Asociar una cuenta».
   (Necesita el backend de grupos vivo; si no lo está, sirve una sesión ya asociada de una corrida
   anterior — la asociación persiste.)
4. **Baja el kill-switch:** Ajustes → **iCloud** → panel «Modo Nube · Auth» → toggle **«Simular remote
   OFF (kill-switch)»**. Esa fila del panel es alcanzable desde `iCloudSyncSettingsView`, o sea SIN pasar
   por la pantalla de almacenamiento — importa, porque es la que vamos a mirar.
5. Sal de Ajustes y vuelve a entrar (el gate se evalúa al pintar la lista).

## Los cuatro recorridos

**R1 · La fila sigue ahí, y suelta la cuenta.** Con el kill bajado y la cuenta asociada, la fila
«¿Dónde viven tus datos?» tiene que **verse**. Entra, y dentro tiene que estar la sección «Grupos» con
«Desasociar». Suéltala y comprueba que completa (la sección pasa a ofrecer «Asociar una cuenta»).

**R2 · Y «Migrar a la nube» NO está.** En el mismo R1, antes de soltar nada: dentro de la pantalla tiene
que estar la tarjeta de estado y la sección de Grupos, y **no** la tarjeta «Migrar a la nube». Es lo que
el incidente cierra.

⚠️ **El panel DEBUG sigue debajo, y ofrece «iniciar migración REAL».** Eso es DEV-only y a propósito
(es la puerta de servicio de QA). No lo confundas con un fallo del gate: lo que se mide en R2 es la
tarjeta de producto, no el panel.

**R3 · Sin cuenta que soltar, el kill sigue ocultando la fila.** Desasocia (R1), sal de Ajustes, vuelve a
entrar: la fila **ya no tiene que estar**. Es el comportamiento que el ticket NO quería cambiar. Si
sigue ahí, el término no es un término: es un `true`.

**R4 · Con el kill arriba, todo vuelve a la normalidad.** Quita el toggle del panel, vuelve a Ajustes: la
fila está, y dentro vuelve a estar «Migrar a la nube».

## El recorrido que este device-QA NO cubre

La carrera del hallazgo B: tapear «Migrar a la nube» y que el flag caiga **mientras el consent está
arriba**. El guard nuevo (`abortIfCloudEntryClosed`) sale con el aviso genérico, pero reproducirlo a mano
pide bajar el toggle desde otro sitio en esa ventana exacta. Se fija por source-scan del cableado, no
aquí.

## QA Visual · 2026-09-16 — PASS

Se verificó en simulador con seams, junto a `cloud-killswitch-hides-the-only-door-to-detach-groups`.

Simulador iPhone 17 Pro (iOS 26.5), sobre `2.1` @ `bebd57a57`. Para tener el kill-switch **abajo** se usó el build `Debug` sin `DEV_BUILD`: bajo
`-uitest`, los flags remotos valen su default de producción, OFF. Para tenerlo **arriba**, `Yala Dev`.

| Recorrido | Montaje | Qué se vio |
|---|---|---|
| R1/R2 · kill abajo, con Grupos | `-uitest-fake-cloud-session -uitest-fake-attest-support` | La fila «Dónde viven tus datos» sigue ahí, con **Grupos · Desasociar** y **sin** «Migrar a la nube» |
| R3 · kill abajo, sin cuenta | sin sesión | Sin fila |
| R4 · kill arriba | `Yala Dev` + `-uitest-fake-attest-support` | Vuelve «Migrar a la nube» / «Activar la nube» |

Capturas: [R1/R2](../../qa/evidencia-barrido-20260916/03-killswitch-R1R2-desasociar-sin-migrar.jpg) · [R3](../../qa/evidencia-barrido-20260916/04-killswitch-R3-sin-cuenta-sin-fila.jpg) · [R4](../../qa/evidencia-barrido-20260916/05-killswitch-R4-nube-activa-vuelve-migrar.jpg).

**No se vio** que desasociar llegue al final: pide una asociación real con el servidor. Ese recorrido
vive en `device-qa-groups-account-association`, que sigue en la cola de device.
