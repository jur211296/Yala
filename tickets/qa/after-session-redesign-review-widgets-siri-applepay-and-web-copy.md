---
id: after-session-redesign-review-widgets-siri-applepay-and-web-copy
status: qa
priority: high
area: "widgets, intents, web, marketing"
created: 2026-09-09
updated: 2026-10-09
source: "ADR 2026-09-09 «Sesiones — dos ejes» — consecuencias; pedido por Jürgen para DESPUÉS del rediseño"
---

# Después del rediseño de sesiones: revisar widgets, Siri, Apple Pay, notificaciones y todos los textos de la web

## Qué es esto

Una lista de comprobación **posterior** a implementar el ADR de sesiones (últimos tickets:
`shell-derives-from-two-session-axes`). Jürgen pidió dejarlo anotado y no mezclarlo con el rediseño.
Nada de aquí se ha medido todavía; cada punto empieza por medir.

## YA MEDIDO (2026-09-14): las tres puertas cuelgan del CIERRE DE SESIÓN, no del borrado

Esto deja de ser «nada se ha medido todavía» para los tres puntos de abajo. Sale de la review
adversarial de `wipe-alert-fires-on-a-session-that-no-longer-obeys-the-signal`, y el hallazgo es el
mismo en las tres superficies: **se arman con `isSignOutWipeArmed()` o las llama solo el sign-out**, así
que un borrado que llega por el ESPEJO de CloudKit —el caso del teléfono prestado cuyo dueño vacía desde
otro dispositivo— no las toca.

- **Widget**: `WidgetDataCache.clearCache()` tiene exactamente dos llamadores, los dos dentro de
  `DataWipeService`; su puerta de suspensión lee `StorageModePersistence.isSignOutWipeArmed()`. ⇒ la
  pantalla de inicio sigue pintando el saldo y los últimos movimientos del dueño hasta el próximo
  arranque en frío o tarea de fondo.
- **Siri**: `SiriIntentContextCache.clear()` tiene UN llamador, `AppGroupInboundPurge`, y esa purga
  declara un solo llamador: `SwiftDataConfiguration.performSignOutWipeIfArmed`. ⇒ el snapshot del App
  Group con las subcategorías del dueño sobrevive, y `QuickExpenseIntent` lo lee.
- **Notificaciones locales**: `NotificationService.isPersonalWipeArmed` es otra vez
  `isSignOutWipeArmed()`, y `cancelAllNotifications()` solo lo llaman tres caminos de cierre de sesión.
  ⇒ **los recordatorios de pagos programados del dueño se siguen entregando, con sus montos**, en el
  teléfono que le prestó.

Atribución honesta: el botón «Empezar de cero» del aviso de vaciado remoto tampoco limpiaba ninguna de
las tres (solo baja `hasCompletedOnboarding` y borra dos centinelas de semilla), así que el hueco es
anterior y vale para las dos ramas. Lo que cambió el 2026-09-14 es que ese aviso ya no sale en esa
celda, así que ahora hay **cero** señal dentro de la app frente a tres superficies que siguen
afirmando.

## Dentro del repo (Frank)

- [x] **Widgets** (`YalaWidgets/`, DTO del App Group): qué enseñan en la celda «sin privada + nube solo
      grupos» (no hay Panel) y en «nube completa» (¿la caché sobrevive al cierre de sesión? ¿se vacía con
      el wipe local?). El ticket descartado `widget-snapshot-visitor-overwrites-owner` describía el
      síntoma para la visita; el hecho de fondo —la caché del widget no sabe de sesiones— sigue vivo.
- [x] **Siri** y **Apple Pay** (cola en App Group, `Yala/App/Intents`): qué pasa con una entrada en cola
      cuando la sesión activa es solo-grupos, o cuando se cerró sesión entre el intent y el drenaje.
- [x] **Notificaciones** de informes y recordatorios (`ReportNotificationService`, pagos planificados):
      que no programen nada sin finanzas personales, y que el cierre de sesión las cancele.
      — 2026-10-08: el cierre las cancela (los tres caminos de `cancelAllNotifications()`) y ahora también el
      vaciado remoto. «Nada sin finanzas personales» queda INFERIDO: en solo grupos no hay `NotificationItem` ni
      `ScheduledPayment` que programar; los informes no se programan (salen al abrir). Lo cubre el device-QA.
- [x] **Exportación** (`ExportWizard`): qué exporta cada celda.
- [x] `qa/coverage-index.json`: áreas nuevas por celda de sesión.

## Fuera del territorio de Frank (Lola — `marketing/` y `Web/`)

- [ ] La web, la FAQ, la política de privacidad y los términos dicen que los datos de Grupos viajan
      «por iCloud, no por servidores nuestros» vía CloudKit Sharing (revisión web del 2026-09-03, L2,
      `Web/REVISION-WEB-UX-A11Y-2026-09-03.md:95`). Con el ADR la historia es «Grupos = cuenta en la
      nube (Google/Apple), en el backend de Yala». Hay que reescribir esas cuatro superficies.
- [ ] Ficha de la App Store (7 idiomas) y capturas: la elección privado / nube y la mini-app de Grupos
      como se ve al terminar el rediseño.
- [ ] Etiquetas de privacidad de App Store Connect: comprobar que declaran lo que la cuenta en la nube
      recoge (probablemente ya, desde el Modo Nube; medir).

## Cuándo

Después de que `shell-derives-from-two-session-axes` esté en `2.1`. No antes: cualquier medición
anterior describiría una app que va a cambiar.

## Decisiones de Jürgen (2026-09-09, pasada de desbloqueo)

Preguntadas una a una antes de soltar la cola autónoma. **Mandan sobre lo escrito arriba.**

- **Este ticket se PARTE EN DOS.** Aquí se queda la mitad de Frank (widgets, Siri, Apple Pay,
  notificaciones, exportación, `coverage-index`). La mitad de Lola —web, FAQ, política, términos, ficha
  de la App Store y etiquetas de privacidad— vive ahora en
  **`tickets/backlog/session-redesign-web-and-store-copy.md`**. Cada uno se cierra por su cuenta y el
  runbook deja de esperar a un territorio que no es de Frank.
- **La corrección legal BLOQUEA la publicación.** La política de privacidad y los términos dicen que los
  datos de Grupos viajan «por iCloud, no por servidores nuestros»; con el rediseño eso es falso. **No se
  publica el rediseño en la App Store hasta que esos documentos estén corregidos.** Es una afirmación
  sobre dónde viven los datos de la gente y no puede ser falsa ni un día. Está en el ticket de Lola,
  pero el bloqueo es del release, así que también se anota aquí.
- **El widget en «solo grupos» invita a activar Yala completo.** No se queda vacío ni se convierte en un
  widget de grupos: dice que aún no hay finanzas personales y lleva a activarlas. El hueco se usa como
  puerta de entrada.

## Medido en 2.1 (triage 2026-10-08)

- El prerequisito ya está: `shell-derives-from-two-session-axes` está en `done`.
- Los tres limpiadores siguen colgando solo de cierres. `WidgetDataCache.clearCache()`: `DataWipeService.swift:283,1059`, `CloudSessionSignOut.swift:1519`, `SecondarySessionRetirement.swift:110`. `SiriIntentContextCache.clear()`: solo `AppGroupInboundPurge.swift:67`. `cancelAllNotifications()`: `CloudSessionSignOut.swift:1515`, `SwiftDataConfiguration.swift:559`, `SecondarySessionRetirement.swift:112`.
- `startFreshAfterRemoteWipeNotice` (`ContentView.swift:1710`) no llama a ninguno ⇒ tras un vaciado remoto siguen el saldo del widget, las subcategorías de Siri y los recordatorios con montos del dueño.
- El widget en «solo grupos» no invita a activar Yala completo: nada de eso en `YalaWidgets/`.

Triage 2026-10-08: abierto · medium → high · el prerequisito ya está en done y el hueco medido el 14-sep sigue: un vaciado remoto deja widget, Siri y recordatorios del dueño (ContentView.swift:1710).

## Lo entregado (2026-10-08)

**Vaciado remoto: las dos ramas del receptor limpian lo que hay fuera del store.**

- **«Empezar de cero» del aviso** (`ContentView.startFreshAfterRemoteWipeNotice`) llama a `RemoteWipeSharedSurfaces`
  (molde de `purgeSharedSurfaces`): vacía el snapshot del widget y el de Siri, retira los avisos programados y barre
  las marcas del resumen diario de pagos (con lo programado retirado, «este día ya tiene resumen» mentiría). Las de
  avisos ya entregados se quedan: si las filas vuelven tras un hueco pasajero de CloudKit, barrerlas repetía banners.
  No toca las colas de Apple Pay/Siri ni los avisos ya entregados: son capturas e historial de este teléfono.
- **La señal** (`handleRemoteWipeSignal`) ya vaciaba el widget y cancelaba los avisos dentro del borrado orquestado; le
  faltaba Siri. `SiriIntentContextCache.clear()` entra en el PASO 3 de `DataWipeService.wipeAllUserData`, junto al
  widget: así cubre también «Vaciar datos» y los borrados del Welcome y del aviso tardío, que tenían el mismo hueco. No
  se cancela nada más en esa rama: correría contra la reprogramación de los recordatorios que sobreviven al corte.
- **«Ahora no» no limpia**: los datos pueden volver, y el aviso vuelve si siguen fuera.

**Widget en solo grupos: invita a activar Yala completo** (decisión del 2026-09-09).

- La app publica el eje en una clave propia del App Group (`widget_groupsOnlySession`), fuera del snapshot para no
  arriesgar su decode. La escriben `WidgetDataCache.updateCache` y el `didSet` de `SessionState.hasPrivateSession`.
- Los 15 widgets de datos (11 de pantalla de inicio y 4 de pantalla bloqueada) pintan «Aún no tienes finanzas
  personales · Activar Yala completo»; los de entrada rápida no cambian. El toque abre `yala://activate-full`: en solo
  grupos, «Activar Yala completo»; si ya se activó, el Panel. Textos en los 16 idiomas del widget.

**Medido de paso.**

- Siri en solo grupos se para sola (snapshot con `hasRealAccount == false`). Apple Pay no: lo deja escrito
  `apple-pay-capture-in-a-groups-only-session-has-no-personal-inbox`.
- Exportación: ya va por celda (Perfil → «Exportar datos» abre la de Grupos en solo grupos y la personal en el resto).
- `coverage-index`: actualizadas las áreas de iCloud/multidispositivo, widgets, Siri y deep links.

**Tests**: `YalaTests/CloudSync/RemoteWipeSharedSurfacesTests.swift` (seis suites). La de la señal recorre
`wipeLocallyForRemoteWipeSignal` real contra un store en disco y el App Group del host, y sale roja sin el cambio.

## Guion de device-QA (Jürgen)

Hace falta un iPhone «prestado» con TU Apple ID y Yala en sesión privada, y otro dispositivo tuyo (iPad o iPhone)
con Yala en el mismo Apple ID. El simulador no tiene CloudKit, por eso esto va en dispositivo.

1. En el iPhone prestado, abre Yala con algunos movimientos, un pago programado para mañana y una subcategoría propia.
2. Añade el widget **Balance** a la pantalla de inicio y comprueba que enseña tu saldo.
3. Cierra Yala en el iPhone (deslízala fuera del selector de apps).
4. En el otro dispositivo: Perfil → Ajustes → **Vaciar datos** → confirma.
5. Espera 1-2 minutos y abre Yala en el iPhone prestado.
6. Según lo que salga:
   - **Si aparece «Tus datos fueron eliminados de iCloud»**, toca **Empezar de cero**.
   - **Si no aparece aviso** y la app se vacía sola, sigue.
7. Sal a la pantalla de inicio. **El widget Balance ya no enseña tu saldo** (sale vacío o en cero).
8. Ajustes del iPhone → Notificaciones → Yala no tiene que sonar mañana con el pago programado. Para comprobarlo
   antes: cambia la hora del pago a dentro de 2 minutos ANTES del paso 4 y espera; no debe llegar el aviso.
9. Di «Oye Siri, gasto en Yala» con una frase que nombre tu subcategoría propia: el borrador que salga no debe
   proponerla (si eres Pro).

**Widget en solo grupos** (cualquier iPhone):

1. Entra en Yala por «Vengo por un grupo» (o usa un teléfono ya en solo grupos).
2. Añade el widget **Balance**: tiene que decir «Aún no tienes finanzas personales · Activar Yala completo».
3. Tócalo: se abre Yala en «Activar Yala completo».
4. Termina la activación y vuelve a la pantalla de inicio: el widget pasa a enseñar el saldo.

## Residuales (review adversarial del 2026-10-08, dos lentes)

- **Galería de widgets en solo grupos**: el modificador no distingue la vista previa, así que la galería enseña 15
  invitaciones iguales. Decisión de producto, no se tocó.
- **Reprogramación en vuelo** (inferido): una tarea de `rescheduleAllNotifications` que suspende justo antes de
  «Empezar de cero» puede volver a programar algo del dueño tras la purga; nada arma `isPersonalWipeArmed` aquí. La
  ventana es estrecha: el toque llega al menos 5 s después de la caída de las filas.
- **Siri sin subcategorías en la misma sesión** (inferido): tras un borrado con onboarding sin salir de la app, el
  primer dictado va con listas vacías hasta el siguiente primer plano (antes iba con las viejas). Degrada, no bloquea.
- **Previo a este cambio**: `DataWipeService.rescheduleSurvivingReminders` no vuelve a planificar los resúmenes de los
  pagos que sobreviven al corte; quedan mudos hasta el siguiente primer plano.
