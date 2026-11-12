---
id: welcome-groups-back-forgets-first-time-after-invite-screen
status: backlog
priority: low
area: "welcome, grupos, navegación"
created: 2026-10-24
updated: 2026-10-24
source: "encargo 2026-10-24-welcome-solo-grupos-a-b (card jyhh), visto en el QA del simulador"
---

# «Volver» de «¿Cómo empiezas?» olvida que venías de «Es mi primera vez» si pasaste por «Pega tu enlace»

## El problema, en lenguaje de usuario

Desde el 24-oct, «Es mi primera vez» tiene la salida «¿Solo vienes a dividir gastos? Empieza por aquí», que abre
«¿Cómo empiezas?» (crear un grupo o unirse). Su «Volver» devuelve a «Es mi primera vez»… salvo en un caso: si la
persona entra en «Me invitaron a un grupo», toca «Atrás» en «Pega tu enlace de invitación» y después «Volver», acaba
en «¡Hola! ¿Qué quieres hacer en Yala?» en vez de en «Es mi primera vez». Sube un nivel de más; no pierde nada y la
pantalla a la que llega ya la había visto.

## Por qué pasa (medido en el simulador, iPhone 17 Pro, iOS 27.0)

«Pega tu enlace» vive fuera del Welcome: al volver, el Welcome se monta de nuevo en «¿Cómo empiezas?» y el origen
(`WelcomeFlowContainer.groupsChooserOrigin`, un `@State`) arranca en el elector. Lo mismo pasaría al cancelar el
inicio de sesión de «Crear mi primer grupo», que también vuelve por `ContentView`.

## Qué haría falta

Que `ContentView` recuerde el origen junto al step al que devuelve (`returnToWelcomeChooser(…, step: .groupsChooser)`),
como ya hace `onRestoreOrigin` para Restaurar. Se dejó fuera del encargo A+B a propósito: era tocar `ContentView`
por un caso de un nivel.
