---
id: cloud-sign-out-with-an-expired-session-and-personal-changes-has-no-exit
status: qa
priority: medium
area: "modo-nube, sesión, settings"
created: 2026-09-28
updated: 2026-09-28
source: "residual de `groups-outbox-rows-without-a-live-session-have-no-exit` (2026-09-28)"
---

# En la nube, con la sesión caducada y movimientos sin subir, no puedo cerrar sesión si no puedo volver a entrar

## El problema, en lenguaje de usuario

Tengo mi cuenta en la nube, apunté movimientos sin conexión y mi sesión caducó. Toco «Cerrar sesión» y Yala me dice que
vuelva a entrar desde «Dónde viven tus datos». Si no puedo —borré la cuenta desde otro sitio, perdí el acceso al correo—, no
hay forma de cerrar sesión en este teléfono.

## Lo medido (leído, sin ejecutar, 2026-09-28)

- Desde `groups-outbox-rows-without-a-live-session-have-no-exit` los cambios de **grupos** tienen esa salida: el aviso
  cuenta cuántos se perderían y ofrece «Cerrar sesión y perderlos» (`CloudSignOutFlowLogic.lossCause`, paso 2 del cierre en
  la nube).
- Los cambios **personales** no: el paso 1 de `CloudSessionSignOut.performCloudSecureSignOut` solo abre su salida con el
  teléfono sin App Attest (`.personalAttestUnavailable`, `exitDiscardingUnsyncedPersonalChanges`). Con la sesión caducada
  bloquea con `.cloudSessionExpired` y sin salida.
- El molde está hecho: el aviso de los cambios personales ya ofrece **exportar los movimientos** antes de perderlos.

## Lo que falta decidir (Jürgen)

¿Se ofrece la misma salida (exportar + perderlos) a quien tiene la sesión caducada y cambios personales sin subir? El dato es
más caro que el de grupos: son sus movimientos, y la nube es su única copia.

## 2026-09-28 · Resuelto (pendiente de ver en un iPhone)

**Decisión** (encargo del 2026-09-28, opción robusta): sí, la misma salida que el teléfono sin App Attest. El camino por
defecto sigue siendo volver a entrar para subirlos.

**Qué cambia para quien usa la app.** Con la sesión de la nube caducada y movimientos sin subir, «Cerrar sesión» enseña un
aviso que cuenta cuántos cambios se perderían y dice cómo subirlos: abrir «Dónde viven tus datos», aquí en Perfil, y tocar
«Iniciar sesión». Ofrece, en este orden, «Exportar mis movimientos», «Cerrar sesión y perderlos» y «Ahora no». Exportar no
toca nada y vuelve al aviso. «Ahora no» no borra nada. Si la persona vuelve a entrar, sus cambios suben y el cierre sigue como
siempre. Otra cuenta no sube los cambios de la anterior, tampoco tras aceptar perderlos.

**Qué no hace, a propósito.** Si el servidor rechaza el token pero la sesión sigue guardada y se puede renovar (un deploy roto,
el reloj desfasado), no ofrece perderlos: enseña el aviso de siempre, que no pierde nada. Solo con la sesión borrada de verdad,
o con otra cuenta abierta, sale la salida.

**Tests.** `CloudExpiredSessionPersonalLossLogicTests` (la decisión del paso 1 por causa, la prueba de la sesión, los
textos), `CloudPersonalAttestSignOutWiringTests` (el cableado), y en `CloudSyncRuntimeTests` el push-all real con la sesión
caducada (bloquea sin subir y ofrece; al volver a entrar sube y drena) y con otra cuenta (no sube nada, tampoco tras
aceptar). Mutantes y review adversarial en el PR.

**Residuales con ticket.** `cloud-sign-out-with-another-account-points-to-a-missing-sign-in-door` (low),
`a-previous-owners-claim-seal-passes-the-cloud-identity-gate` (medium, inferido) y dos notas añadidas a
`personal-drain-that-always-aborts-blocks-cloud-sign-out-with-a-wait-a-moment-copy` y
`cloud-sign-out-final-recount-misses-edits-left-only-in-history`.

## QA en iPhone

**Por qué en iPhone:** hace falta una cuenta en la nube de verdad y caducar la sesión en el servidor; el simulador no crea
esa cuenta sin el secreto de attest (`.claude/rules/gateway-attest.md`).

**Montaje:** un iPhone de pruebas con `Yala Dev` desde Xcode contra staging, con una cuenta en la nube («Dónde viven tus
datos» dice nube). Apunta el id de la cuenta en el SQL Editor de Supabase (staging):
`select id from auth.users where email = '<correo>';`

1. **Pon el iPhone en modo avión** y apunta **dos gastos**. Quita el modo avión **solo después** del paso 2.
2. **Caduca la sesión desde el servidor:** `delete from auth.sessions where user_id = '<id>';` (revoca la renovación; el SDK
   borra la sesión al intentar renovar). Quita el modo avión y espera un minuto con Yala abierta.
3. **Perfil → «Cerrar sesión» → confirma.** Tiene que salir el aviso «No pudimos cerrar tu sesión» con **«Cambios que no
   llegaron a tu cuenta en la nube: 2»**, y los botones «Exportar mis movimientos», «Cerrar sesión y perderlos» y «Ahora no».
   Captura.
4. **«Exportar mis movimientos».** Sale la hoja de compartir con el archivo; ciérrala. El aviso **vuelve** con la misma cifra.
5. **«Ahora no».** El aviso se cierra y los dos gastos siguen en Registros.
6. **El camino por defecto:** Perfil → «Dónde viven tus datos» → «Iniciar sesión» con la **misma** cuenta. Vuelve a
   «Cerrar sesión»: ya no sale el aviso de la pérdida, los cambios suben y la sesión se cierra. Comprueba en otro dispositivo
   (o en staging) que los dos gastos llegaron.
7. **La salida:** repite 1-3 y toca **«Cerrar sesión y perderlos»**. La sesión se cierra y Yala vuelve al inicio.

### Criterios de aceptación de QA

- [ ] Con la sesión caducada, el aviso cuenta los cambios y ofrece exportar, perderlos o dejarlo.
- [ ] Exportar genera el archivo y vuelve al aviso sin perder nada.
- [ ] «Ahora no» no borra nada.
- [ ] Volviendo a entrar con la misma cuenta, los cambios suben y el cierre sigue sin aviso de pérdida.
- [ ] «Cerrar sesión y perderlos» cierra la sesión.
