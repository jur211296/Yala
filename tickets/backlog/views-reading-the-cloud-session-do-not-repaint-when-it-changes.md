---
id: views-reading-the-cloud-session-do-not-repaint-when-it-changes
status: backlog
priority: low
area: "modo-nube, grupos, ajustes"
created: 2026-10-23
updated: 2026-10-23
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
