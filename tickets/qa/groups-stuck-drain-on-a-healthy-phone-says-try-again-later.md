---
id: groups-stuck-drain-on-a-healthy-phone-says-try-again-later
status: qa
priority: low
area: "grupos, sync, copy"
created: 2026-10-05
updated: 2026-10-05
source: "review adversarial de `groups-drain-that-always-aborts-takes-the-loss-exit-away` (2026-10-05, lente 3)"
---

# Con el drain de Grupos atascado en un teléfono sano, cerrar sesión dice «inténtalo en un rato» y esperar no lo cura

## El problema, en lenguaje de usuario

Muy raro. Si este teléfono no consigue preparar para subir un cambio de tus grupos —siempre, no una vez— y todo lo demás va
bien (tiene App Attest, tu sesión vale y el cambio es tuyo), cerrar sesión, desasociar o «Empezar de cero» te dicen «Los
últimos cambios de tus grupos no llegaron al servidor… inténtalo de nuevo en un rato». No se pierde nada y no hay salida que
lo pierda (decisión A de Jürgen), pero el texto promete que esperar ayuda, y no ayuda.

## Por qué pasa (medido el 2026-10-05)

- `CloudSignOutFlowLogic.stuckCaptureVerdict` devuelve `.uploadRetryLater` cuando la captura está atascada, el ciclo fue
  bien y algo de lo que queda fuera es de esta sesión. Es el texto de una subida que falló, no el de un cambio que este
  teléfono no consigue preparar.
- El gemelo personal tiene su motivo y su texto (`.personalCaptureUnfinished`, `settings.signOutCaptureUnfinished`: «no se
  pudieron preparar; no se pierden; cierra y abre Yala o actualízala»). Grupos no.
- Pariente: en el desasociar, con el drain atascado y la sesión caducada, el aviso dice «tu sesión caducó» (verdad, pero volver
  a entrar no cura el drain; tras entrar saldría este mismo texto).

## Propuestas (decide Jürgen)

- **A (recomendada).** Motivo propio `.groupsCaptureUnfinished` con el texto del personal dicho de tus grupos: «Algunos de
  los últimos cambios de tus grupos no se pudieron preparar para subirlos. Siguen guardados en este teléfono y no se pierden.
  Cierra y vuelve a abrir Yala; si sigue pasando, actualízala.» 16 locales, sin salida. Es lo honesto y es el molde ya decidido.
- **B.** Reusar el texto personal (`settings.signOutCaptureUnfinished`) tal cual en Grupos. Cero copy nuevo, pero habla de «tus
  cambios» sin decir que son de grupos.
- **C.** Dejarlo como está. Es tan raro que no compensa; el texto no promete segundos, solo «un rato».

## Criterios de aceptación

- [x] Con el drain de Grupos atascado en un teléfono sano, ningún aviso promete que esperar lo cura.
- [x] Sin salida que pierda nada (decisión A).

## 2026-10-05 · Entregado (opción A de Jürgen)

**Qué cambia para la persona.** Si este teléfono no consigue preparar para subir algún cambio de tus grupos —siempre, no una
vez— y todo lo demás va bien, cerrar sesión, «Desasociar» y «Empezar de cero» ya no dicen «inténtalo de nuevo en un rato».
Dicen: «Algunos de los últimos cambios de tus grupos no se pudieron preparar para subirlos. Siguen guardados en este
teléfono y no se pierden. Cierra y vuelve a abrir Yala; si sigue pasando, actualízala.» En las 16 locales. Ninguna salida
pierde esos cambios. La puerta de Grupos del Welcome dice lo mismo (sin su rama propia habría dicho «vuelve a entrar con esa
cuenta»).

**Cómo.** Motivo nuevo `CloudSignOutFlowLogic.BlockReason.groupsCaptureUnfinished` (al final del `enum`), que
`stuckCaptureVerdict` devuelve en la rama que antes daba `.uploadRetryLater`. Se enseña al momento
(`GroupsSignOutRetryDecision`), viaja tal cual en el cierre en la nube, no abre ninguna salida de pérdida (`lossCause`,
`freshStartOffersGroupsLossExit`) y tiene texto propio, `groups.errors.captureUnfinished`. El `.uploadRetryLater` de la subida
que sí falló, y el de la captura que no probó el atasco, no cambian.

**Fuera, con ticket:** el pariente del desasociar con el drain atascado y la sesión caducada (o sin App Attest), que nombra
solo la primera de las dos causas: `detach-with-a-stuck-groups-drain-names-only-the-first-of-two-causes`, con propuestas A/B/C.

## Guion de device-QA

El aviso nuevo solo sale con un drain de Grupos atascado, y eso no se puede provocar en un iPhone de verdad sin un build con
un fallo inyectado (un store que no deja guardar). Lo fijan los tests unitarios: `GroupsStuckDrainHealthyPhoneCopyTests`,
`GroupsStuckCaptureLogicTests.stuckCaptureVerdict_table`, `GroupsStuckDrainPushAllTests` (por «Empezar de cero») y
`GroupsDetachBlockedPhaseTests` (por el desasociar). Lo que sí se mira en un iPhone, con el build de TestFlight y una cuenta
con grupos, es que lo de alrededor no cambió:

1. **Cierre normal con un gasto de grupo recién apuntado.** Abre un grupo, apunta un gasto y, sin esperar, ve a Perfil →
   «Cerrar sesión». Esperado: cierra como siempre, sin aviso.
2. **Subida que falla de verdad** (la que sigue diciendo «en un rato»): pon el iPhone en modo avión, apunta un gasto en un
   grupo, quita el modo avión pero deja el wifi apagado y sin datos, y ve a Perfil → «Cerrar sesión». Esperado: «No pudimos
   cerrar tu sesión» con «Los últimos cambios de tus grupos no llegaron al servidor… inténtalo de nuevo en un rato». Vuelve a
   conectar y reintenta: cierra.
3. **Desasociar sin conexión** (Perfil → «Dónde viven tus datos» → tu cuenta de grupos → «Desasociar»), con un gasto de grupo
   pendiente y sin red. Esperado: «No pudimos soltar la cuenta» con el mismo texto de «en un rato». Con red, desasocia.
4. **Idioma.** Cambia Yala a inglés (Perfil → Idioma) y repite el paso 2: el aviso sale en inglés, sin claves crudas.

Sin capturas: el aviso nuevo solo se ve con el fallo inyectado, y forzarlo pediría un atajo de depuración en el coordinador
del cierre que nadie pidió.
