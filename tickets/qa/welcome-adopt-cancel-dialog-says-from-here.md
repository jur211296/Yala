---
id: welcome-adopt-cancel-dialog-says-from-here
status: qa
priority: low
area: "modo-nube, onboarding, adopt, copy"
created: 2026-09-23
updated: 2026-10-06
source: "review adversarial de `welcome-adopt-effect-failure-has-no-reason-and-no-cancel` (2026-09-23), lente de SwiftUI y copy"
---

# Al cancelar la entrada a tu cuenta desde la bienvenida, el diálogo dice «desde aquí» y te saca de la pantalla

## El problema, en lenguaje de usuario

Entro en mi cuenta de la nube desde la bienvenida y toco «Cancelar la activación». El diálogo dice «Puedes volver a
activar la nube en este dispositivo desde aquí cuando quieras». Al confirmar, la app me lleva a la pantalla de elegir,
y el «aquí» ya no existe. Puedo volver por «Ya tengo cuenta», pero la frase se escribió para la tarjeta de Almacenamiento.

## Por qué pasa (leído el 2026-09-23)

La bienvenida reusa el cuerpo del diálogo de Almacenamiento (`StorageFailureCopyLogic.cancelMigrationBody`:
`storage.confirm.cancelAdoptBody` / `cancelAdoptEffectBody`), por decisión de Jürgen del mismo día: «mismos textos».
Engañoso, no falso.

## Qué habría que decidir (es de producto)

¿Se deja así, o la bienvenida lleva un cuerpo propio sin «desde aquí» (dos claves nuevas en 16 idiomas)?

## Decisión (Jürgen, 2026-10-04): opción B

La bienvenida lleva un cuerpo propio, sin «desde aquí», aunque sean dos claves nuevas en los 16 idiomas.

## Qué se hizo (2026-10-06)

- **Lo que ve el usuario.** En la bienvenida, el diálogo de «Cancelar la activación» conserva su primera frase (qué pasó
  con los datos) y cambia la segunda: «Volverás al inicio. Cuando quieras, puedes entrar otra vez en tu cuenta con «Ya
  tengo una cuenta»». El botón se nombra con el texto exacto del selector de cada idioma (es-ES «Ya tengo cuenta», pt
  «Já tenho conta»…). Almacenamiento no cambia.
- **Medido, no supuesto:** al confirmar, el poll ve la cancelación aterrizada y llama a `onBack`, que abre el Welcome en
  `.chooser` (ContentView); ahí salen siempre las tres filas, y «Ya tengo una cuenta» lleva a la sub-elección y de ella a
  la misma pantalla de entrar en la cuenta.
- **Código.** `welcome.cloud.cancelAdoptBody` / `welcome.cloud.cancelAdoptEffectBody` (16 `Localizable.strings`; `es` y `pt`
  copia byte a byte de `es-419` y `pt-BR`; es-AR con voseo). `StorageFailureCopyLogic.cancelMigrationBody` gana
  `surface: .storage | .welcome` sin default: la fase se sigue eligiendo en un solo sitio y cada pantalla declara dónde
  está. La rama de «Migrar» es la misma en las dos.
- **Red.** `WelcomeAdoptExitTests.cancelBody_perPhase_andPerSurface` (las 8 combinaciones fase × pantalla),
  `welcomeBodies_inEveryLocale_dropTheFromHereSentence_andNameTheChooserButton` (en cada locale: empieza por la primera
  frase de Almacenamiento, no contiene su segunda, nombra el botón del selector, y hereda las prohibiciones de los
  cuerpos del adopt) y los scans de cableado de las dos pantallas.
- **Capturas: no hay.** No existe semilla que monte la bienvenida con un adopt en curso: haría falta entrar en una cuenta
  real de la nube y dejar el claim aparcado. Por eso el device-QA.

## Device-QA (iPhone, con una cuenta de la nube que ya tenga datos)

Montaje: instala el build en un iPhone sin Yala (o borra la app) y deja la red encendida.

1. Abre Yala. En «¡Hola! ¿Qué quieres hacer en Yala?», toca **Ya tengo una cuenta** y entra con tu cuenta de la nube.
2. Mientras sale la barra de progreso, toca **Cancelar la activación**.
3. Comprueba que el diálogo dice «Este dispositivo no cambió nada de lo que tienes en la nube. Volverás al inicio. Cuando
   quieras, puedes entrar otra vez en tu cuenta con «Ya tengo una cuenta».» y **no** dice «desde aquí».
4. Toca **Sí, cancelar**. Comprueba que vuelves a «¡Hola! ¿Qué quieres hacer en Yala?» y que **Ya tengo una cuenta** te deja
   entrar otra vez.
5. Control: en Configuración → «Dónde viven tus datos», el mismo diálogo de una activación en curso sigue diciendo «…desde aquí cuando
   quieras». No hace falta forzarlo si no sale solo.

Si el paso 2 llega tarde (la barra termina en segundos), repite con la red lenta (Ajustes → Desarrollador → Network Link
Conditioner, «Very Bad Network»).
