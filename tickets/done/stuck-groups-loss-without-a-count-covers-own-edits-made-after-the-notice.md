---
id: stuck-groups-loss-without-a-count-covers-own-edits-made-after-the-notice
status: done
priority: low
area: "grupos, sync, datos"
created: 2026-10-05
updated: 2026-10-05
source: "review adversarial de `stuck-groups-drain-hides-held-rows-of-another-account` (2026-10-05, lente de datos)"
---

# Con el drain de Grupos atascado y el History ilegible, aceptar perder «sin cifra» se lleva también lo que apuntes después

## El problema, en lenguaje de usuario

Rarísimo: el teléfono no consigue preparar algunos cambios de grupos, **y además** no puede leer cuáles son justo cuando
enseña el aviso. Entonces el aviso de «Cerrar sesión y perderlos» (sin App Attest o con la sesión caducada) sale sin cifra. Si
la persona acepta, y antes de que el cierre termine apunta otro gasto de grupo que tampoco se prepara, ese gasto se va con el
cierre sin que ningún aviso lo haya contado.

## Por qué pasa (medido leyendo el código el 2026-10-05)

- La captura atascada (`GroupsExitCapture.stuck`) exige que el History se leyera en todos los intentos, pero la oferta lo
  vuelve a leer (`CloudSessionSignOut.groupsLossUncaptured`) y esa lectura puede dar `nil`.
- Con `nil`, lo aceptado guarda `uncaptured: nil`, y `CloudSignOutFlowLogic.lossHalfCovers(accepted: nil, now:)` cubre
  cualquier cosa: la continuación (`groupsLossAcceptanceContinues`) y el recuento pegado al borrado
  (`groupsResidualUncapturedAllowsSignOut`) dejan pasar cambios nuevos.
- En el caso de otra cuenta se cerró en `stuck-groups-drain-hides-held-rows-of-another-account`: un History ilegible ya no
  abre la salida. Los motivos del ciclo (attest, sesión) siguen abriéndola sin mirar si el History se lee.

## Propuestas (decide Jürgen)

- **A.** Con la captura atascada y el History ilegible, no ofrecer la salida: el aviso del atasco, sin salida, hasta que se
  pueda contar. Coherente con «la persona no puede aceptar perder lo que el aviso no le enseñó».
- **B.** Ofrecerla igual, pero que lo aceptado sin cifra en la mitad del History caduque al primer cambio nuevo (exigir una
  lectura buena antes del borrado).
- **C.** Dejarlo: hacen falta dos fallos de lectura seguidos tras cinco buenos.

## Decisión

**Opción A**, decidida por Jürgen el 2026-10-05 (tarjeta `tablero-decidir-con-el-drain-de-grupos-atascado-mc0q`): con la
captura atascada y el History ilegible, no se ofrece la salida; sale el aviso del atasco, sin salida, hasta poder contar.

## Hecho (2026-10-05)

**Para el usuario.** Si el teléfono no consigue preparar algún cambio de grupos y además no puede leer cuáles son justo al
enseñar el aviso, ya no se le ofrece «Cerrar sesión y perderlos» (ni «Empezar de cero y perderlos») sin cifra. Ve el aviso
de siempre del atasco: «Algunos de los últimos cambios de tus grupos no se pudieron preparar… Siguen guardados en este
teléfono y no se pierden. Cierra y vuelve a abrir Yala». Al volver a intentarlo con el History legible, la salida vuelve con
la cifra exacta, y lo que acepta cubre exactamente eso: un gasto apuntado después del aviso vuelve a avisar.

**Medido antes del fix (en `df8468f55`).** El hueco no era solo de los motivos del ciclo: las cuatro ofertas releen el History
y ninguna miraba si esa relectura daba `nil`. Celda privada C (sin sesión), paso 2 del cierre en la nube (attest, sesión, otra
cuenta), `pushGroupsForSignOut` (hoja del Apple ID, puerta del Welcome, celdas D/F) y «Empezar de cero» (también
`.permanent`). El #366 había cerrado el `nil` de la lectura del VEREDICTO; éste es el de la OFERTA, para todas las causas. El
desasociar no aplica: no ofrece salida.

**Cómo.**
- `CloudSignOutFlowLogic.groupsLossShownReason`: motivo que abre la salida + mitad del History en `nil` ⇒
  `.groupsCaptureUnfinished`, sin oferta anotada ni canario de oferta. Cableada en las cuatro ofertas.
- Cinturón: `groupsHistoryHalfCovers` en `CausedLossAcceptance.coversUncaptured` y en la tercera mitad de
  `FreshStartGroupsLoss.covers`: lo aceptado sin leer el History solo cubre «nada fuera del outbox». Filas y espejo sin cifra
  (decisión B2) y la mitad personal no cambian.
- Texto reusado (`groups.errors.captureUnfinished`, y en «Empezar de cero» su `leadUnknown` delante): dice la verdad en este
  caso. Sin cadenas nuevas.
- La puerta para volver a entrar en la nube la sigue decidiendo el motivo que se enseña (regla fijada en
  `SyncSignInBannerLogicTests`).

**Tests.** `YalaTests/CloudSync/GroupsStuckDrainUncountedOfferTests.swift` (lógica pura con controles, «Empezar de cero» por
el coordinador con un History que se lee tras cada captura y falla en la oferta, y el source-scan de las cuatro ofertas) y tres
casos de la celda C real en `GroupsNoSessionLossExitTests` (atasco sin salida y sin canario de oferta, salida con la cifra al
volver a leerse, y lo aceptado que sigue leyendo el History). **Rojo medido** sobre el código sin el fix: los 8 casos
`MUTACIÓN` en rojo y los 3 controles en verde; «Empezar de cero» ofrecía `.attestUnavailable` con `Int.max`, y una aceptación
sin cifra dejaba borrar un cambio `h9` que ningún aviso contó. **Mutantes: 12, todos muertos** (el M7, la celda C anotando la
oferta siempre, sobrevivía y lo mató la aserción del canario). Cuatro tests viejos fijaban el comportamiento anterior y se
actualizaron: «aceptado sin cifra: cubre cualquiera» y tres source-scans de las ofertas. **Gate:** builds Yala y Yala Dev sin
warnings nuevos; unit 9042/9043 (el rojo es `SpikeR3ContainerReleaseTests` eje 4a, flaky conocido con ticket
`spike-r3-eje-4b-flaky-en-suite-completa`: aislado, rojo-verde-verde sobre el mismo árbol); XCUITest 9/9
(`SessionExitsPerCellUITests`, `AppleIDCloseNoticeUITests`) con el centinela a 0.

**Review adversarial** (lente de datos y lente de verdad del copy).
- Datos: tumbó una decisión mía. Recontar la oferta de la celda C sin lo aceptado (para que el texto fuera exacto con la
  captura curada) dejaba de leer el History en la comprobación pegada al arm, que no captura: un cambio apuntado tras el aviso
  se iba con el borrado. Retirado; la oferta se cuenta con lo aceptado puesto. Precio: en ese rincón (aceptado + captura
  curada + History ilegible) sale «no se pudieron preparar» aunque la captura de ese paso terminara. No pierde nada.
- Copy: nada falso. Dos huecos de información, aceptados o con ticket (abajo).

**Sin device-QA ni capturas.** El caso exige que el History falle a demanda en la relectura de la oferta y no en la captura:
solo lo dan los seams de test. El aviso que sale ya existía y no cambia.

**Hallazgos, a backlog:**
- `personal-loss-without-a-count-covers-own-edits-made-after-the-notice`: el mismo hueco en la mitad PERSONAL del cierre en
  la nube (`PersonalLoss.uncaptured == nil`).
- `stuck-groups-unread-history-with-another-account-names-one-cause`: con otra cuenta y el History ilegible en la oferta, el
  aviso nombra solo el atasco; el invitado del Welcome pierde el texto de las dos causas.

**Aceptado, sin ticket:** con la sesión caducada o sin App Attest, el aviso del atasco no dice la causa de fondo; sale al
volver a intentarlo, con su cifra. Es la misma forma que Jürgen decidió dejar en
`stuck-groups-drain-with-another-account-and-a-cycle-reason-names-two-of-three-causes`.
