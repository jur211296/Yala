---
id: onboarding-2-3-write-without-opening-step
status: done
priority: high
area: onboarding
created: 2026-11-12
updated: 2026-11-12
source: tablero-bienvenida-2-3-paso-7-anota-sin-abrir-ya-arjq (docs/onboarding-2-3/SPEC.md, Y23-16)
qa-status: pass
qa-date: 2026-11-12
qa-notes: simulador iPhone 17 Pro iOS 27.2 - página corta de 4 partes, los cuatro mini tutoriales, la pantalla de entre medias, omitir y terminar con el mazo completo; capturas y XCUITest
---
# Bienvenida 2.3 · Paso 7 · Anota sin abrir Yala (Y23-16)

«Yala en tu pantalla de inicio» del mazo abre, a pantalla completa como los pasos 3 a 5:

- Una página corta «Anota sin abrir Yala» con una parte por manera (avanza sola cada 3,4 s; quieta con Reducir movimiento
  o VoiceOver): widget, Apple Pay, compartir una foto y Siri. «Empezar» y «Omitir este paso».
- Un mini tutorial por manera, todos omitibles (X, «Omitir»), con «N de 4 · nombre»: «Añade el widget» (4 pasos), «Registrar
  con Apple Pay» (los pasos y la garantía de Tutoriales, «Abrir Atajos»), «Compártele una foto a Yala» (hoja de compartir
  con el recibo de ejemplo, 3 pasos, insignia Pro; la guía de compartir es nueva) y «¿Qué le digo a Siri?» (las seis
  frases de la ficha con su insignia Pro y «Abrir mis atajos de Yala»).
- Entre uno y otro, «Paso 7 de 7»: las maneras con su estado, «¡Van N de 4!» o «Sigamos», la siguiente y «Omitir».
- Terminar con al menos una vista da el paso por hecho; todas omitidas u «Omitir este paso», por omitido; «Atrás» desde la
  primera parte deja el mazo en el 7. Con el paso resuelto se completa Primeros pasos (Y23-18).

**Cuatro maneras, no cinco:** «Tu correo» (Y23-19) no está desplegado (ver `onboarding-2-3-bank-email-step`). La ficha pide
que hasta entonces el paso enseñe cuatro.

Avisos: la frase rápida de Siri es «Nuevo registro en Yala» (la de la ficha, que existe en `AppShortcuts.xcstrings`; la
pantalla «Siri y Atajos» enseña «Registra en Yala», las dos funcionan). En es-419 el paso 3 de compartir dice «monto»
(BRAND-VOICE) donde el prototipo decía «importe».

Pruebas: `YalaTests/Bienvenida23FinalTests` (homeScreen_*) y
`YalaUITests/Flows/Bienvenida23FinalUITests#test_step7_fourWays_doneAndSkipped_thenTheDeckCompletes`.
