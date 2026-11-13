---
id: account-ready-returns-to-welcome-and-asks-to-relaunch
status: done
priority: very-high
area: "welcome, cloud-sign-in"
created: 2026-11-13
updated: 2026-11-13
card: tablero-despues-de-ya-esta-tu-cuenta-yala-vuelve-zrya
source: "Jürgen, iPhone 14, 13-nov 09:46 (staging, cuenta con grupos)"
---

# Después de «¡Tu cuenta está lista!», Yala vuelve a la bienvenida

Al entrar con Google en una cuenta que ya existe, el adopt termina, sale «¡Tu cuenta está lista!» y, al tocar
«Empezar», aparece la bienvenida en vez del Panel. Al cerrar y reabrir Yala, entra al Panel con los datos.

## Hecho cuando

Tras «¡Tu cuenta está lista!» → «Empezar» se llega al Panel, sin bienvenida; con test que caiga sin el arreglo y probado
en el iPhone 14.

## Resolución (2026-11-13)

Medido en el iPhone 14 con logs de consola, desde una instalación de verdad nueva: «Empezar» llama a `onFinishedToApp`,
que lee `hasCompletedOnboarding = true`; el cover se cierra y su `onDismiss` (`welcomeCoverDidDismiss`) lee `false` en la
línea siguiente. Es el cierre de cuando se presentó el cover, con el `@AppStorage` de antes del adopt, y con `false` el
respaldo reabría el elector, que en 2.3 pinta la bienvenida.

Arreglo: el respaldo lee el onboarding de su almacén en el momento (`WelcomeCoverContentLogic.onboardingCompletedNow`) y
decide con `dismissFallbackReopensChooser`. Tests: `WelcomeCoverFallbackAfterAdoptTests` (decisión, lectura y cableado)
y el scan de `WelcomeCoverContentLogicTests`; con el mutante (la lectura vieja) caen los dos scans.

Fuera de este ticket, por decisión de Jürgen: «Un último paso: reabre Yala» sale cuando el proceso arrancó con el espejo
de iCloud montado; lo trabaja la sesión «Entrar con otra cuenta de Google o Apple» (punto 2 de su encargo), con las
mediciones de aquí.
