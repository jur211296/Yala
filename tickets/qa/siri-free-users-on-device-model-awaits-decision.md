---
id: siri-free-users-on-device-model-awaits-decision
status: qa
qa-status: needs-device-testing
priority: medium
area: siri
created: 2026-10-21
updated: 2026-10-21
source: auditoría UX 2.2 · lote 15 · L15-6 (decisión de Jürgen del 2026-10-18, el matiz) · card `tablero-ux-2-2-l15-6-sin-pro-siri-dice-activa-ya-2yze`
---

# «Anotar con Siri» para quien no tiene Pro, con el modelo del propio iPhone: ¿se enciende?

Jürgen eligió la opción B de L15-6 (sin Pro, Siri abre la hoja de Pro, hecho) con un matiz: que el usuario gratis pueda
usar IA «usando el propio modelo de Siri si lo tienen disponible, que no implica gastos para nosotros».

## Qué se midió (2026-10-21, SDK de iOS 27.1)

- `FoundationModels` (`SystemLanguageModel`, `LanguageModelSession`) existe desde iOS 26, el mínimo de Yala. Dice si el
  modelo está disponible en ESE aparato (Apple Intelligence encendido y descargado; iPhone 15 Pro o posterior) y genera
  una estructura tipada (`@Generable`).
- Es viable: está implementado en `Yala/App/Intents/SiriOnDeviceEntry.swift` y cableado en `SiriNaturalEntryIntent`
  (`SiriEntryRoute.decide`): sin Pro, con el interruptor encendido y el modelo disponible, Siri lee el dictado en el
  teléfono —sin servidor, sin coste y sin que el texto salga del iPhone— y deja el borrador en la Bandeja como con Pro.
- Va APAGADO (`SiriOnDeviceEntry.isEnabled` es `false` fuera de DEBUG). Encenderlo cambia lo que vive un usuario gratis:
  en vez de la hoja de Pro, un borrador. Por eso es una decisión.
- No medido: la calidad de la lectura del modelo del iPhone frente al del servidor, ni cuánto tarda dentro del tiempo que
  Siri da a un atajo. Pide un iPhone con Apple Intelligence (en DEBUG se enciende con la clave del App Group
  `debug.siriOnDeviceFreeEntry`).

## Qué hay que decidir

- **A · Encenderlo** para todos los que no tienen Pro y sí el modelo (los demás siguen viendo la hoja de Pro).
- **B · Dejarlo apagado** y retirar el código si no se va a usar.
- **C · Medirlo antes** en un iPhone con Apple Intelligence (calidad y tiempo) y decidir con el dato.

Recomendación: C, y si la lectura es razonable, A. Lo que se regala es la parte que no cuesta (la lectura local) y la
hoja de Pro sigue para quien no tiene el modelo.

## Decisión (2026-10-21, 05:18 Lima)

**A · Encenderlo** para quien no tiene Pro y sí el modelo; los demás siguen viendo la hoja de Pro.

## Resultado (2026-10-21)

- **Encendido en todos los builds** (`SiriOnDeviceEntry.isEnabled = true`); la clave de DEBUG se retiró. Apagarlo es una
  línea.
- **«Modelo listo»** = Apple Intelligence disponible en ese aparato **y** que el modelo admita el idioma del teléfono. Los
  motivos de «no» tienen nombre (`SiriOnDeviceModelState`: `deviceNotEligible`, `appleIntelligenceNotEnabled`,
  `modelNotReady`, `languageNotSupported`) y todos llevan a la hoja de Pro.
- **Si el modelo falla al leer**, el borrador básico de siempre (la lectura local del monto).
- **Señal sin datos personales**: `siriEntryRoute` en cada invocación (`route=… model=…`) y `siriOnDeviceParse` en cada
  lectura del teléfono (`ok` · `noAmount` · `failed:<tipo>#<código>`, con los milisegundos). Con eso el gate Pro de Siri
  deja señal por primera vez (mitad Siri de `canarios-y-breadcrumbs-sin-emisor`).
- **Tests**: `SiriEntryRouteTests` (matriz Pro sí/no × cada estado del modelo, interruptor, traducción de
  `FoundationModels`, cableado y detalle sin PII), dos casos de `MetricsServiceTests` y el XCUITest
  `SiriOnDeviceEntryUITests` (App Intents Testing, seam `-uitest-siri-model`): sin modelo o sin descargar → hoja de Pro;
  con modelo (stub) → borrador en la Bandeja, sin hoja de Pro.

## Guion de prueba en iPhone (Jürgen)

Montaje: build de TestFlight de 2.2 con este cambio. Cuenta **sin Pro** (si tu cuenta tiene Pro: Ajustes de Yala, en
Yala Dev, apaga el Pro de prueba; o usa una cuenta de pruebas sin suscripción).

1. **iPhone con Apple Intelligence** (15 Pro o posterior), Ajustes › Apple Intelligence y Siri › encendido, idioma
   español, y el modelo ya descargado (la pantalla de Apple Intelligence no dice «Descargando»).
2. Di a Siri: «Oye Siri, anota un gasto en Yala» y, cuando pregunte, «Anota 20 soles en almuerzo». Apunta con un
   cronómetro cuánto tarda Siri en contestar.
   - Esperado: Siri dice «Borrador creado: …» y **no** abre la hoja de Pro.
3. Abre Yala › Bandeja: hay un borrador de **20 soles**, gasto, con nota de almuerzo y la subcategoría que haya elegido el
   modelo. Apunta si la subcategoría es la que esperabas.
4. Cambia el idioma del iPhone a inglés (Ajustes › General › Idioma), repite con «Note 20 dollars for lunch». Mismo
   esperado, en inglés.
5. Comparación con el servidor: activa el Pro de prueba (o usa una cuenta Pro) y repite el paso 2 con la misma frase.
   Apunta el tiempo y la subcategoría de los dos para compararlos.
6. **Sin modelo**: en el mismo iPhone, apaga Apple Intelligence (Ajustes › Apple Intelligence y Siri) y vuelve a la
   cuenta sin Pro. Repite el paso 2.
   - Esperado: Siri dice «Activa Yala Pro…» y **Yala se abre en la hoja de Pro** (no se queda en el aviso).
7. Si tienes un iPhone sin Apple Intelligence (anterior al 15 Pro), repite el paso 6 allí: mismo esperado.
8. **Pro sin cambios**: con Pro, el paso 2 deja el borrador como siempre (lectura del servidor).

Qué devolver: tiempo y calidad (importe, gasto/ingreso, subcategoría) del teléfono frente al servidor en ES y EN, y si
algún paso no hizo lo esperado. La señal `siriEntryRoute` / `siriOnDeviceParse` del panel de métricas lo confirma tras
la prueba (aparece al volver a abrir Yala).
