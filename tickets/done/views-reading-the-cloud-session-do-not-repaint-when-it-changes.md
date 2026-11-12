---
id: views-reading-the-cloud-session-do-not-repaint-when-it-changes
status: done
priority: low
area: "modo-nube, grupos, ajustes"
created: 2026-10-23
updated: 2026-10-28
source: "review adversarial de la card nve0 (encargo 2026-10-23-grupos-refresco-y-entrada-2-2)"
---

# Seis vistas pintan con la sesión de la nube y no se enteran cuando cambia

## Qué pasa

`CloudAuthService` no es observable: una vista que lea `CloudAuthService.shared.hasSession` en su body no se repinta al
iniciar o cerrar sesión. La card nve0 lo arregló en la pestaña de Grupos («Crea tu cuenta de Yala» seguía más de 10 s tras
conectar la cuenta) con el aviso nuevo `CloudAuthService.sessionDidChangeNotification`. La review encontró el mismo patrón,
sin medir en pantalla, en:

- `ProfileView.swift` (dos lecturas) y `YalaAccountView.swift`
- `GroupsOnboardingView.swift` (dos lecturas)
- `CloudAttestNoticeBanner.swift` (Panel)
- `WelcomeGroupsGateView.swift`
- `AppleIDCloseNoticeView.swift`

`StorageSettingsView` se salva porque repinta cada segundo con el tick del journal.

## Y el aviso tiene un hueco

La sesión que el SDK borra solo tras un refresco terminal no mueve `sessionEpoch` y no avisa.

## Qué hacer

Medir en el simulador cuáles de las seis se quedan desfasadas de verdad (con `-uitest-fake-cloud-session-after`, el seam de
nve0) y escuchar el aviso en las que sí, molde `GroupsIdentityRevisionObservers`. El hueco del SDK, aparte.

## Hecha cuando

Cada vista de la lista repinta al cambiar la sesión, o consta por qué no hace falta.

## Resultado (2026-10-28, card n533)

Medido en el simulador con `-uitest-fake-cloud-session-after` (ahora se arma también al abrir Ajustes):

- **Ajustes — desfasada de verdad (medido).** Con Ajustes abierto, la sesión entraba y «Tu cuenta de Yala» no salía
  hasta cerrar y volver a abrir: `YalaAccountUITests#test_sessionArrivingWithSettingsOpen_showsTheYalaAccountRow` en rojo
  sin el arreglo, verde 2 de 2 con él, y rojo otra vez con el mutante que quita las dos lecturas atadas.
- **El arreglo, uno para todas:** `CloudSessionRevision`, un contador `@Observable` que sube el único emisor del aviso
  de nve0. Cada lectura de la sesión que pinta llama a `track()` justo antes, y SwiftUI repinta el `body` que la evalúa.
  Lo llevan Ajustes (`signOutRowPath`, `deleteAccountRowHasSession`), «Tu cuenta de Yala» (`model`), el educativo de
  Grupos (`ctaSection`), el aviso del attest (`CloudAttestNotice.isShowing`, Panel y Almacenamiento), el aviso del
  cambio de Apple ID (`currentCell`) y, encontrada al buscar el patrón, la hoja de invitación a un grupo
  (`joinTapRoute`, que pinta el aviso de «elegir cuenta»). Lo fija `CloudSessionRevisionWiringTests`.
- **Inferidas, no medidas:** el seam no llega a «Tu cuenta de Yala» (solo existe con sesión), al aviso del attest (pide
  `storageMode == .cloud`, sin seam) ni a los modales del educativo y del Apple ID. Se atan igual: es una lectura de
  más, sin coste.
- **No hace falta: `WelcomeGroupsGateView`.** Lee la celda solo en funciones (al evaluar y al confirmar), nunca en el
  `body`, y la confirmación la vuelve a leer.
- **El hueco del SDK, aparte:** `cloud-session-removed-by-the-sdk-does-not-announce-itself`.
