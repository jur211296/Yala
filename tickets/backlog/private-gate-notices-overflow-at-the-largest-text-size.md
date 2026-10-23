---
id: private-gate-notices-overflow-at-the-largest-text-size
status: backlog
priority: low
area: "onboarding, accesibilidad"
created: 2026-10-20
updated: 2026-10-20
source: "pase de estrés del encargo 2026-10-20-qa-2-1-icloud-privado-rechazar-y-enlace"
---

# Los avisos de la puerta privada no caben con el texto más grande

## En lenguaje de usuario

Con el texto de accesibilidad al máximo, los avisos de «Tu cuenta en tu iCloud privado» («No pudimos conectarnos a iCloud», «iCloud tardó demasiado en responder»…) cortan el título con puntos suspensivos y dejan los botones fuera de la pantalla.

## Lo medido (2026-10-20)

- iPhone 17 Pro, iOS 27.0, AX5, alemán: el título sale «iCloud hat zu…» y «Reintentar» queda bajo el borde, sin scroll. Captura: `/Users/jur/Claude/worktrees/_capturas/2026-10-20-qa-2-1-icloud-privado-rechazar-y-enlace/estres-2-icloud-tardo-AX5-de.png`.
- Es del componente común (`WelcomePrivateICloudGateView.noticeShell` dentro de `WelcomeFlowScreen`, sin `ScrollView`): afecta a todos sus avisos, también a los que ya existían.

## Lo que habría que hacer

El molde de `swiftui-ds.md` para pantallas que reparten su alto con `Spacer`s (`GeometryReader` + `ScrollView` + `minHeight`) y el título con `fixedSize(horizontal: false, vertical: true)`.
