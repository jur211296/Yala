---
id: welcome-groups-gate-loops-on-legacy-cloudkit-groups
status: done
priority: high
area: "groups, welcome, sign-out"
created: 2026-10-29
updated: 2026-10-29
source: "card tablero-welcome-borrar-icloud-en-bucle-si-solo-q-5b3g (reporte de Pia, 24-oct), investigación S24"
---

# La puerta de Grupos del Welcome entra en bucle si el teléfono guarda grupos de la era CloudKit

## Qué ve la persona

Entra por «Crear mi primer grupo» o por una invitación. La app le pide dejar el teléfono en blanco
(«Continuar y borrar» en la invitación; el organizador con copia en iCloud lo hace sin preguntar).
Yala se reinicia y vuelve a pedir lo mismo, una y otra vez. No puede crear el grupo ni unirse. Solo
sale entrando con una cuenta completa en la nube, que es lo que hizo Pia.

El iCloud no interviene: el bucle sale igual con el iCloud vacío. El texto de la invitación nombra
iCloud porque elige su copy según el canal de copia, no por lo que haya allí.

## La causa, medida en código (2.2 @ fda2fc445)

Cuatro piezas, y el bucle sale de que no cuentan lo mismo:

1. **La puerta cuenta TODOS los grupos.** `ContentView.checkHasExistingData` y `checkHasGroupsData`
   hacen `fetchCount(FetchDescriptor<SplitGroup>())` sin predicado. Un grupo de la era CloudKit cuenta
   como «hay datos de alguien». La del organizador lo lee en
   `WelcomeGroupsGateView.evaluate` (`GroupsOrganizerGateLogic.decide`); la del invitado, en
   `GroupInviteNeutralGateLogic.decide` vía `checkHasWelcomeDeviceData`.
2. **El borrado de la vuelta al neutro NO se lleva esos grupos.** Es el cierre privado
   (`CloudSessionSignOut.signOut` → celda `.privateSignOut` → `ExitKind.privateOnly`). Su fórmula,
   `CloudSignOutFlowLogic.wipeForgetsGroups`, solo marca el store de Grupos para borrar si
   `kind.pushesGroups` (falso en `.privateOnly`) o si `CloudSessionSignOut.hasBackendGroupRows` encuentra
   un grupo con `isBackendGroup || movedToBackendAt != nil`. Un grupo de la era CloudKit que nunca migró
   no cumple ninguna: el fichero del store de Grupos sobrevive al borrado del arranque
   (`SwiftDataConfiguration`, rama `signOutWipeIncludesGroups`).
3. **El arranque siguiente vuelve a la misma celda.** El borrado limpia `PrivateSessionMark`, y la
   lectura `hasPrivateSession` da `true` con la marca ausente. Sin sesión en la nube, la celda vuelve a
   ser `.privateSignOut`. Las dos puertas apagan la marca al terminar el alta
   (`GroupsOrganizerOnboarding`, `GroupInviteOnboardingView`), después de pasar, nunca antes.
4. **Lo demás sí queda limpio.** El store personal se borra entero (adiós a las filas puenteadas), el
   neutro durable está armado y `hasShownWelcomeChooser` se resetea, así que monta sin espejo. El único
   término que sigue encendido es el de los grupos del punto 1.

⇒ puerta → borrado que conserva los grupos viejos → reinicio → la puerta los vuelve a contar → igual.
Ningún término cambia entre vueltas, así que el bucle no tiene fin.

**Reproducción:** no se reprodujo en el simulador. Haría falta sembrar un `SplitGroup` con
`isBackendGroup == false` y `movedToBackendAt == nil` y recorrer la puerta con reinicios reales. La
cadena está leída entera en el código y casa con los tres síntomas del reporte: el bucle, que no
pudiera borrar ni crear la cuenta de grupos, y que saliera con una cuenta completa de Google.

## A quién le puede pasar hoy

Se necesitan las tres cosas:

- grupos de la era CloudKit que nunca pasaron al backend en el store de Grupos del teléfono.
  `SplitGroup` existe en el código publicado desde `v2.0.0` (2026-06-18). Ningún camino de 2.1/2.2
  crea grupos así, así que solo los tiene una instalación que viene de entonces;
- el Welcome a la vista: el onboarding personal sin terminar (la puerta del invitado deja pasar con
  él terminado, y la del organizador solo vive en el Welcome);
- entrar por «Crear mi primer grupo» o por una invitación.

Hay una ruta al Welcome que no pide venir de una instalación rara: **cerrar sesión desde Ajustes en una
sesión privada sin cuenta de grupos**. Ese cierre conserva los grupos viejos (ticket
`private-sign-out-keeps-legacy-cloudkit-groups`), deja el teléfono en el Welcome, y desde ahí la
puerta de Grupos entra en el bucle. Lo que aquel ticket llamaba «población teórica» tiene ya un caso
reportado: Pia.

No hay telemetría que lo cuente: ni la puerta ni el borrado emiten un canario por vuelta. Sin
medir: cuántas instalaciones de 2.0.x conservan grupos sin migrar.

## Decisión: A (Jürgen, 2026-10-29 05:31)

La vuelta al neutro de la puerta de Grupos se lleva también los grupos de la era CloudKit.

## Hecho (2026-10-29)

- `CloudSessionSignOut.signOut` gana `neutralReturnFromGroupsGate` (por defecto `false`). Lo pasa solo
  `WelcomeGroupsGateView.returnToNeutral`, que es el único sitio por el que vuelven al neutro las dos puertas
  (organizador e invitado). El coordinador lo guarda hasta `armAfterCredentials`, también en los cierres que se
  retoman tras un bloqueo, y lo retira al armar o al reconocer el bloqueo.
- `CloudSignOutFlowLogic.wipeForgetsGroups` gana el término `groupsGateWithGroupRows`: con la puerta detrás y **algún
  `SplitGroup` en el store** (lo mismo que cuenta la puerta), el borrado se lleva el store de Grupos entero. Sin grupos no
  marca: la marca retira además el libro de conservados del desasociar y la cuenta de grupos asociada, y ahí no hay nada
  que volver a contar (lo cazó la review adversarial). Los grupos que el aviso tardío conservó para la persona también
  se van: el borrado retira esa marca, y si se quedaran la vuelta siguiente los contaría, el mismo bucle.
- **Ajustes y la hoja del cambio de Apple ID no cambian** (pasan `false`): siguen esperando la decisión de
  `private-sign-out-keeps-legacy-cloudkit-groups`. No es la misma línea: comparten la fórmula, no la llamada.
- Sin cambio de copy: el aviso al organizador con copia en iCloud sigue sin nombrar los grupos viejos (pendiente de
  decisión, abajo).
- Tests: `GroupsGateLegacyGroupsWipeTests` recorre la cadena con stores reales en disco para las dos puertas (grupo
  de la era CloudKit sembrado → la puerta pide el neutro → fórmula del arm → borrado real del arranque → remontar →
  la puerta deja pasar), con su control (sin el término el grupo sobrevive y la puerta vuelve a pedir el neutro).
  `GroupsGateLegacyGroupsWipeWiringTests` fija que solo la puerta pide el término y que el coordinador lo lleva al
  arm (firma con `= false`, recuento exacto de escrituras). Otro par fija que sin grupos el libro de conservados y la
  cuenta asociada sobreviven, y con grupos se van. La tabla de `wipeForgetsGroupsTable` pasa a 3 × 2 × 2 × 2.
  Mutantes en rojo: quitar el término de la fórmula, pasar `false` desde la puerta y pasar `false` desde el arm.

## Device-QA (Jürgen)

No se reprodujo en el simulador: ningún seed crea grupos de la era CloudKit y, con `-uitest`, el borrado del
arranque no corre. Hace falta un teléfono que venga de 2.0 con grupos viejos sin migrar (el de Pia era uno):

1. Instala el TestFlight 2.2 (4) encima, sin borrar la app.
2. Si la app no está en el Welcome, ciérrale sesión desde Ajustes (ese cierre conserva los grupos viejos: es la ruta
   del ticket hermano). **Solo en un teléfono de pruebas**: el cierre borra lo personal del teléfono (queda en iCloud).
3. En el Welcome, toca «Crear mi primer grupo» (o abre una invitación y toca «Continuar y borrar»).
4. Yala se reinicia **una vez** y te deja crear el grupo (o unirte). Antes volvía a pedir lo mismo sin fin.

Si no hay un teléfono así, el test de la cadena es la prueba y el ticket se cierra con él.

## Arreglo: barato, pero borra o conserva datos, y eso lo decide Jürgen

Las dos opciones cortan el bucle. Lo que cambia es qué pasa con los grupos viejos:

- **A. (recomendada) La vuelta al neutro de la puerta de Grupos se lleva también los grupos de la era
  CloudKit.** Cumple lo que la pantalla promete («este teléfono tiene que quedar en blanco») y hace lo
  mismo que «Es mi primera vez» del Welcome, que ya los borra con el `.handover` tras preguntar. Esos
  grupos no pueden volver: la Fase 3 retiró su transporte. Hace falta que el cierre sepa que lo llama la
  puerta (un parámetro de `signOut` que llegue a `armAfterCredentials`), y no tocar el cierre desde
  Ajustes, que sigue esperando la decisión de `private-sign-out-keeps-legacy-cloudkit-groups`. Va con
  review adversarial: toca el borrado del cierre de sesión.
- **B. La puerta deja de contar los grupos de la era CloudKit.** No borra nada. Pero el detector cuenta
  también las filas puenteadas, el bridge no queda sellado en esta celda, y los grupos viejos de otra
  persona se quedarían a la vista de quien entra. Es más frágil y más difícil de razonar.

Queda pendiente decidir si la rama del organizador con copia en iCloud, que hoy informa sin preguntar,
debe nombrar que se borran los grupos viejos.

## Cómo se sabe que está arreglado

- Un test que encadene la puerta, la fórmula del borrado y la celda del arranque siguiente con un grupo
  de la era CloudKit: tras la vuelta al neutro, la puerta dice `.proceed`.
- En el simulador: sembrar un grupo legacy, entrar por «Crear mi primer grupo» y llegar a la creación
  tras un único reinicio. Lo mismo por una invitación.

Cerrado en el barrido de QA 2026-10-30: criterio estricto (filtro doble); motivo y evidencia en docs/qa/tanda-qa-jurgen-2.2-barrido-2026-10-30.md.
