---
id: associate-cta-ignores-the-groups-kill-switch
status: done
priority: medium
area: "groups, settings, modo-nube"
created: 2026-09-11
updated: 2026-10-04
source: "review adversarial de `cloud-killswitch-hides-the-only-door-to-detach-groups`, lente del incidente"
qa-status: not-replicable
qa-date: 2026-10-04
qa-notes: barrido 2026-10-04 sin device-QA - pide bajar el rollout de grupos en el gateway de staging; cubierto por GroupsAssociationKillSwitchTests (4 mutantes) y la captura de simulador
---

# «Asociar una cuenta para grupos» abre un sign-in contra un canal apagado

## El problema, en lenguaje de usuario

Con el canal de Grupos matado remotamente, el botón «Asociar una cuenta» de Ajustes → «¿Dónde viven tus
datos?» sigue llevándome a crear o entrar en una cuenta de Yala. Entro, firmo, y del otro lado no hay
canal: el sign-in es real contra un backend que está en pausa.

## Lo medido (2026-09-11)

- `ProfileView.swift:699` hace `RouterEntryGate.shared.submit(.presentGroupsSignIn(pendingJoin: ""))`
  **sin condición**.
- El drenado lo presenta sin gate: `ContentView.swift:912-914` (`showGroupsSignIn = true`).
- Y eso deja en falso **dos afirmaciones escritas en el propio código**: el comentario del drenado
  («DARK: con `groupsBackendEnabled` OFF los intents jamás se submitean», `ContentView.swift:906`) y el
  docblock de `GroupsSignInView.swift:36-37`.

No lo introdujo el ticket del kill-switch de la nube, pero ese ticket multiplica la población que llega
al botón: ahora la fila también se abre con el kill de la nube bajado.

## Lo que se espera

O el CTA respeta `CloudRemoteFlags.groupsBackendEnabled` (y la sección dice por qué no está disponible),
o los dos comentarios se corrigen para que no prometan un gate que no existe. **Lo segundo solo si se
decide que el sign-in con el canal apagado es aceptable**, y entonces conviene decir por qué.

## Arreglo (2026-10-02)

**Gate real en la sección, no en el drenado.** Medido en el árbol de este día: de los productores de
`.presentGroupsSignIn`, el CTA de Ajustes era el único que no miraba el kill. Los demás ya deciden antes de
emitir (crear grupo y su form, empty states y educativo del tab, invitaciones, re-unirse a un grupo migrado).

- Con el canal de Grupos matado, la sección **no enseña** «Asociar una cuenta para grupos» ni «Entrar»: en su
  sitio dice «Ahora mismo los grupos están en pausa por algo de nuestro lado. Cuando vuelvan, podrás seguir
  desde aquí.» (`storage.groups.channelPausedNote`, 16 locales). «Desasociar» se queda: es teardown.
- Al tocar el botón, la app **re-pregunta** al servidor (`refreshIfDue(force: true)`) antes de decidir. Si el
  canal salió apagado, no abre nada y avisa con el texto que ya usa el tab («Ahora mismo no podemos abrirte
  grupos»); la sección pasa a la nota.
- Al montar en pausa, un refresco forzado: un kill ya levantado no deja la nota hasta 6 h.
- El drenado de `ContentView` **no** se gatea, a propósito: un descarte ahí sería mudo y dejaría sin salida
  los flujos ya abiertos que re-emiten el intent. Los comentarios que prometían ese gate (`ContentView` ×2,
  `GroupsSignInView`, `GroupsBackendInviteModifier`) dicen ahora la verdad y nombran a los productores.

Tests: `YalaTests/GroupsAssociationKillSwitchTests` — tabla `signInEntry` ON/OFF y source-scan del cableado
(refresco antes de leer el flag, los dos botones por el gate, flag compuesto, sin botón en pausa); 4 mutantes
muertos. El OFF no se puede montar en XCUITest (con `Yala Dev` el flag nace ON bajo test).

## Guion de QA (device, `Yala Dev`)

El canal de Grupos solo se mata desde el gateway. **Bajar el percent de staging es decisión tuya**; si no
quieres tocarlo, este ticket se puede cerrar con la captura del simulador:
`qa/evidencia-associate-cta-killswitch-20261002/` (estado apagado, build local con el flag forzado).

1. En staging, `GROUPS_BACKEND_ROLLOUT_PERCENT = 0` (deja `CLOUD_*` como están).
2. En el iPhone, con una sesión privada **sin** cuenta de grupos, cierra Yala del todo y ábrela.
3. Ajustes → «¿Dónde viven tus datos?». **Esperado:** la sección «Grupos» no tiene botón de asociar y dice
   que los grupos están en pausa.
4. Vuelve a poner el percent en 100. Sal de la pantalla y vuelve a entrar. **Esperado:** reaparece
   «Asociar una cuenta para grupos»; tócalo y se abre el inicio de sesión como siempre.
5. Con la pantalla abierta y el botón visible, baja otra vez el percent a 0 y toca el botón. **Esperado:**
   aviso «Ahora mismo no podemos abrirte grupos» y la sección pasa a la nota. No se abre ningún inicio de
   sesión.
6. Deja el percent en 100 al terminar.

## Barrido de `qa` · 2026-10-04 · cerrado sin device-QA

Sale de la cola de device-QA por el barrido antes del QA del lunes (encargo `2026-10-04-barrido-qa-antes-del-qa-del-lunes`), con el criterio de #224 y #291. El guion pide bajar `GROUPS_BACKEND_ROLLOUT_PERCENT` del gateway de staging y volver a subirlo con la pantalla abierta: no es un camino que un usuario recorra, y tocar el gateway es una decisión aparte. Lo fijan `GroupsAssociationKillSwitchTests` (tabla ON/OFF y cableado, 4 mutantes muertos) y la captura del estado apagado en `qa/evidencia-associate-cta-killswitch-20261002/`, que el propio ticket daba como cierre válido.
