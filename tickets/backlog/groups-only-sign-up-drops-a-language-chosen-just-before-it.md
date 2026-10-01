---
id: groups-only-sign-up-drops-a-language-chosen-just-before-it
status: backlog
priority: low
area: "sesiones, idioma, onboarding"
created: 2026-10-01
source: "review adversarial de neutral-boot-hands-owner-prefs-to-whoever-signs-in-next (2026-10-01)"
---

# El alta solo-grupos borra el idioma que la persona acaba de elegir en el selector

## Qué le pasa al usuario

En un iPhone con el idioma del sistema no soportado por Yala y sin idioma elegido, la app enseña primero el selector
de idioma. La persona elige uno, entra por un grupo, y en mitad del alta la app cambia sola al idioma de reserva. En el
arranque siguiente el selector vuelve a salir.

## Por qué pasa (medido en el árbol del PR)

- `ContentView` presenta `LanguageSelectionView` antes del Welcome cuando no hay override y el idioma del sistema no
  está soportado; la elección va a `LanguageManager.overrideLanguage`.
- Las dos altas solo-grupos llaman a `GroupsOnlySignUpPreferenceReset.resetLive()`, que retira el override en local
  porque no puede distinguirlo del que aplicó el arranque neutro desde el iCloud-KV del dueño (la elección también se
  escribió en ese KV: sin marcas, la puerta está abierta).

## Población

Pequeña: hace falta un idioma del sistema no soportado **y** un iCloud-KV sin override (si el dueño tenía uno, el
arranque neutro lo aplica y el selector no sale).

## Opciones

1. Que el selector deje una marca local «elegido en este arranque» y el reset la respete.
2. Conservar el override cuando el idioma del sistema no está soportado (reintroduce el idioma del dueño a esa
   población).
3. Aceptarlo: la persona lo cambia en Perfil.

## Residuales menores de la misma review (gravedad baja, sin ticket propio)

- La caché de Siri (`SiriIntentContextCache`) conserva la divisa del dueño hasta el siguiente paso a primer plano.
- La foto del widget conserva divisa y formato del dueño hasta el siguiente `WidgetDataCache.updateCache`.
- `SessionState.selectedTrendMetric` puede quedarse en «gastos» si el dueño tenía el modo solo-gastos; solo se ve tras
  «Activar Yala completo» sin relanzar.
