# Implementar ticket paso 8: full-mode-activation-must-ask-where-personal-data-lives

## Contexto
Cola del rediseño. Pasos 0–7 en `2.1` (último #136). Este es el **paso 8** — **[adv]**. Necesita 2, 3 y 4 (kind, [I], validación iCloud).

Decisiones: sección **«Decisiones de Jürgen (2026-09-09, pasada de desbloqueo)»** del ticket + índice `docs/sessions/2026-09-09-desbloqueo-decisiones-rediseno-sesiones.md`. **Mandan.**
- Historial de grupos al Panel: **preguntar** (dos caminos; cuidado duplicados / bridge).
- Al restaurar iCloud: **gana lo restaurado** (descarta prefill de Grupos).
- Promoción a `complete` en servidor: **último paso** (si abandona a mitad, sigue solo-grupos).
- Copy nube: **la misma cuenta** (no una segunda), 7 idiomas.

MODO AUTÓNOMO HASTA TERMINAR: review adversarial (varias lentes + refutación), gate, commit, board, `docs/TICKETS.md`, merge, `/cerrar-total` sin preguntar. Bugs/decisiones nuevas → ticket `--solo-crear`. Ambigüedad NUEVA: elige lo más seguro alineado con Decisiones y regístralo. Device-QA CloudKit → `tickets/qa/` (no PASS desde sim).

Avisos a Frank: (1) bloqueo acceso; (2) PR; (3) `/cerrar-total` resumen producto; (4) idle — una vez.

## Que se pide
1. Leer Decisiones → ADR → matriz → ticket → runbook (este paso).
2. Implementar: al activar Yala completo, preguntar dónde viven los datos personales; criterios del ticket + Decisiones.
3. Un PR a `2.1`; marcar matriz/coverage; `/cerrar-total`.

## Que NO hay que tocar
marketing/. Pasos 9–13 salvo lo mínimo. Mitad 2 del paso 5 (blocked esperando verbo paso 9).

## Como se sabe que esta bien
Criterios del ticket + Decisiones; review adversarial hecha; PR mergeado; board/`TICKETS.md` al día; `/cerrar-total`.

## Paso 0 — el árbol de decisiones, resuelto contra el árbol (2026-09-10, `a847792d`)

Medido antes de escribir código. Lo que el ticket daba por hecho y NO era así va marcado **⚠️**.

- **D1 · Una sola puerta.** Los 5 emisores de `.presentFullModeActivation` (Panel, Grupos, detalle de
  grupo, Más, Perfil) abren la MISMA sheet, y su primera pantalla pasa a ser el chooser. ⚠️ De los 32
  `groups.nudge.*` solo 4 llevan a la activación (los `invited*`, `NudgeType.swift:85-97`); el criterio
  «ningún nudge sin chooser» se cumple por construcción y lo fija un scan de cableado.
- **D2 · El chooser es el del Welcome** (`WelcomeNewChooserView`), mismo gate `visibleNewOptions`, con
  una variante de texto: cabecera propia y la card de nube dice «la misma cuenta que usas para tus
  grupos» (decisión de Jürgen). Con una sola card visible, bypass como en el Welcome.
- **D3 · Privado = la puerta del paso 4** (`WelcomePrivateICloudGateView`: sonda directa a CloudKit ANTES
  de relanzar, tres salidas). ⚠️ **El borrado es SOLO de la zona de iCloud**: el store de una sesión
  solo-grupos nunca espejó, así que lo local es suyo, y `wipeAllUserData` además borra
  `hasCompletedOnboarding`, `onboardingMode` y `userName` (`DataWipeService.swift:580,673,681`) — le
  habría mandado al Welcome. Tampoco se limpian nombre y divisa: son su prefill.
- **D4 · El relanzamiento reusa el destino durable del Welcome** (casos nuevos en
  `WelcomeMirrorRelaunchLogic.Destination`), porque de él cuelga la salida al pasar a segundo plano del
  terminal. ⚠️ Un device solo-grupos es *returning user* (`hasCompletedOnboarding == true`) y el destino
  solo se consumía en `presentNextOnboardingScreen`: sin un consumidor en `runReturningUserPostChecks`, la
  app haría `exit(0)` en cada paso a segundo plano. Al consumirlo se escribe una marca de reanudación
  propia (kill-safe) que reabre la sheet. Antes de relanzar: se levanta el neutro solo-grupos y se marca
  `hasShownWelcomeChooser` (anti-bucle del neutro R4). Cancelar tras relanzar re-arma el neutro.
- **D5 · Restaurar = los mismos screens de «Ya tengo cuenta → iCloud»** dentro de la sheet. Su resumen
  (de iCloud) sustituye al prefill de Grupos: **gana lo restaurado**. ⚠️ `RestoreRouter.decide` devolvería
  `.groupsOnly` (el modo local es `.groupInvite`), así que la activación escribe `.completed` ella. Tras
  restaurar, los gastos de grupo se re-puentean por el camino remoto de siempre: el corpus restaurado y
  el de la etapa solo-grupos tienen filas del MISMO gasto, y es el re-puenteo quien las converge.
- **D6 · Nube = consentimiento → [P] → pregunta → promoción → commit.** La promoción es el alta de
  siempre (`BornCloudSignUpService.signUp`): `claim_account` promociona la fila ligera y contesta
  `created` (`g15_01:291-307`). `existing_stable` (cuenta ya completa, o revertida) **bloquea sin escribir
  nada**; `claiming_in_progress` bloquea «inténtalo más tarde». No se pregunta `kind` antes: el Worker aún
  no lo sirve y el claim es la respuesta autoritativa.
- **D7 · «La promoción es el ÚLTIMO paso»** se consigue con un gancho en `OnboardingView`: las respuestas
  de [P] se quedan en memoria hasta que la promoción contesta; abandonar antes no escribe nada.
- **D8 · La pregunta del historial.** ⚠️ **Las filas ya existen**: el bridge de solo-grupos las crea en la
  cuenta de sistema «Grupos» y hoy salen solas en Panel, Registros, Estadísticas y Presupuestos
  (`GroupTransactionBridge.swift:342-358`). Se pregunta tras [P] si hay alguna. **Sí** = se quedan (cero
  escrituras ⇒ cero duplicados). **No** = se apagan los tres toggles de grupos que ya existen (datos
  intactos, reversible en Ajustes de Grupos, sincronizado). Desviación registrada: el «No» también oculta
  los futuros. «Solo el pasado» exige un corte sincronizado entre dispositivos; sin él, el 2.º device
  re-puentea el historial y el saldo de «Grupos» se duplica — un error de dinero. Va a ticket.
- **D9 · Sesión secundaria (M1)**: conserva el camino de hoy (sin chooser). Su store nunca espeja y M1 se
  retira en el paso 12.
- **D10 · El aviso del espejo tardío salta los devices solo-grupos**: su reanudación de borrado pone
  `hasCompletedOnboarding = false`, que mandaría a un solo-grupos al Welcome.

## Tras la review adversarial (2026-09-11)

Cuatro lentes independientes y refutación por hallazgo. Lo que cambió del árbol de arriba:

- **D2 bis · El copy nuevo lleva voseo en es-AR y registro peninsular en es-ES**, en vez de heredar el de
  es-419.
- **D4 bis · El eje de sesión va ANTES que la reanudación.** Una marca de este dispositivo no abre nada si ya
  no es solo-grupos (otro dispositivo pudo completar, y el `.completed` llega por el iCloud-KV):
  `resolveAtBoot` la retira, consume el destino igual y no reabre. Armar el neutro solo-grupos (volver a
  entrar por «Vengo por un grupo») retira también la marca.
- **D5 bis · Cancelar Restaurar ya relanzado NO vuelve a solo-grupos**: el espejo está bajando el corpus y el
  bridge de solo-grupos borraría sus transacciones reales. La sheet se cierra y la activación queda a
  medias, con el bridge cerrado (`isDomainOpenForBridge` mira la activación en vuelo), hasta terminarla.
- **D5 ter · Las liquidaciones no se re-puentean**: `bridgeSettlement` borra también las patas REALES. Solo se
  quita la pata virtual repetida. La convergencia es durable —se marca antes del plan y la reintenta
  `AppBootstrapper.retryPendingBridges` tras sus dos gates—, y lo que el bridge no atiende pasa a
  `GroupsPendingBridgeIntent` con canal backend.
- **D8 bis · «No» llega también a los presupuestos** recién creados (`includeSharedExpenses`), que no tienen
  toggle global.
- **D11 · El arm del borrado de iCloud no sobrevive a la activación**: se retira antes de escribir
  `.completed`; si no, el arranque siguiente lo reanudaría a ciegas —borrado local incluido— sobre el corpus
  recién elegido. La reanudación se retira DESPUÉS del modo.
- **D12 · Las instalaciones solo-grupos anteriores al paso 5** (espejo ya puesto) ven un aviso de reinstalar en
  vez del chooser: sobre ese store ninguna rama es segura.
- **D13 · La capa final tapa también para VoiceOver y el dedo**, y con un plan en vuelo no hay forma de cerrar
  la sheet: el claim podía haber contestado `created`.
- **D14 · El onboarding no se monta hasta tener su prefill**, y la limpieza de la cuenta General residual no
  corre con el espejo puesto.
- Registrado sin arreglar, con ticket: `claim-promotion-lost-response-blocks-the-retry` y
  `completed-mode-escalates-a-second-groups-only-device`.
