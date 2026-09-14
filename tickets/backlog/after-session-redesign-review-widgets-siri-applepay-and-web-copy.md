---
id: after-session-redesign-review-widgets-siri-applepay-and-web-copy
status: backlog
priority: medium
area: "widgets, intents, web, marketing"
created: 2026-09-09
updated: 2026-09-14
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

- [ ] **Widgets** (`YalaWidgets/`, DTO del App Group): qué enseñan en la celda «sin privada + nube solo
      grupos» (no hay Panel) y en «nube completa» (¿la caché sobrevive al cierre de sesión? ¿se vacía con
      el wipe local?). El ticket descartado `widget-snapshot-visitor-overwrites-owner` describía el
      síntoma para la visita; el hecho de fondo —la caché del widget no sabe de sesiones— sigue vivo.
- [ ] **Siri** y **Apple Pay** (cola en App Group, `Yala/App/Intents`): qué pasa con una entrada en cola
      cuando la sesión activa es solo-grupos, o cuando se cerró sesión entre el intent y el drenaje.
- [ ] **Notificaciones** de informes y recordatorios (`ReportNotificationService`, pagos planificados):
      que no programen nada sin finanzas personales, y que el cierre de sesión las cancele.
- [ ] **Exportación** (`ExportWizard`): qué exporta cada celda.
- [ ] `qa/coverage-index.json`: áreas nuevas por celda de sesión.

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
