---
id: welcome-adopt-cancel-then-close-mounts-the-icloud-mirror
status: qa
priority: low
area: "onboarding, modo-nube"
created: 2026-11-04
updated: 2026-11-06
source: "review adversarial (lente de montaje) del lote N1 de la 2.3, bienvenida"
---

# Cancelar la entrada a la cuenta en la bienvenida y cerrar la app monta el espejo de iCloud y entra a la app

## En lenguaje de usuario

Instalación nueva. En la bienvenida toco «Ya tengo una cuenta», entro, empieza a traer mi cuenta y toco «Cancelar»:
vuelvo a la bienvenida. Si cierro Yala ahí y la abro, ya no veo la bienvenida y el teléfono adjunta mi iCloud privado.

## Lo leído (2026-11-04, inferido; no medido en un aparato)

- `onAdoptStarted` (`ContentView.swift`) retira el neutro (`retireNeutralMountOnChoice`) y pone
  `hasCompletedOnboarding = true` (su seguridad ante un kill), y la salida del adopt por `onBack` no deshace ninguna de
  las dos. El `hasShownWelcomeChooser = false` del lote N1 no recupera el neutro.
- Ya pasaba antes del lote N1 (`welcome-cloud-back-leaves-chooser-marked-seen`, `welcome-fresh-install-neutral-mount-lasts-one-launch`).

## Qué habría que decidir

Si la salida del adopt (cancelar, o el techo) devuelve el neutro y el onboarding a «sin hacer», o si basta con lo de
hoy porque el adopt cancelado ya dejó escrito algo de la cuenta.

## Resolución (2026-11-06, decisión A de Jürgen)

- **Decisión:** al salir hacia atrás del adopt (Cancelar, o la flecha tras el techo o un error), se deshace lo que marcó
  `onAdoptStarted` SOLO si el journal de la migración prueba que no se trajo ni subió nada; ante cualquier duda se
  mantiene la protección de hoy. No contradice la decisión A del 6-oct (`fresh-start-shell-alert-after-an-adopt-exit-…`):
  aquella eligió no tocar el marcado para arreglar el aviso de «Borrar todo y continuar»; con huella, esa celda sigue igual.
- **Qué cambia para el usuario:** cancelar la entrada a la cuenta en la bienvenida y cerrar Yala vuelve a abrir en la
  bienvenida, sin adjuntar el iCloud privado.
- **Cómo:** `onAdoptStarted` apunta, antes de marcar y solo en el primer intento (un «Reintentar» no la pisa), cómo
  estaban el onboarding, la sesión privada y el montaje neutro (`WelcomeAdoptBackOut.Snapshot`, en `WelcomeFlowModifier`).
  Las dos salidas que vuelven al chooser (`onBack` y «Crear otra cuenta») llaman a `restoreStateIfAdoptLeftNoTrace()`; las
  que dejan otro estado legítimo (entrar a la app, alta en la nube, solo grupos) sueltan la foto. Se repone solo si
  `WelcomeAdoptBackOut.leftNoTrace`: journal legible, fase `notStarted` o `failedRollback`, sin el efecto del adopt
  pendiente, **y** o la salida fue del claim (`stalled`, `sessionExpired`, `accountUnavailable`: no suben ni bajan filas)
  o el teléfono no tiene datos propios (`checkHasExistingData`, que falla cerrado). `.cancelled` no basta solo: también la
  deja cancelar el efecto, que puede haber subido huérfanas. Con cualquier otra cosa no toca nada y un kill aterriza en la
  app como hasta hoy.
- **Review adversarial:** cazó tres cosas en la primera versión, las tres corregidas: la foto se pisaba al reintentar, se
  quedaba viva tras un alta en la nube o una entrada solo de grupos (y podía reponerse mucho después sobre un teléfono en la
  nube), y `failedRollback` por sí solo no probaba «no se subió nada» (el relevo de la ida sale por ahí con páginas subidas).
- **Tests:** `WelcomeAdoptBackOutTests` (tabla de `leftNoTrace` con datos locales y sin ellos, por salida; el neutro de
  instalación nueva vuelve con su dueño; sin neutro previo no se arma nada; cableado: foto antes de marcar y solo una vez,
  las dos salidas al chooser restauran y las otras tres sueltan la foto). `FreshStartAfterAdoptExitTests` y el conteo de
  `PrivateSessionMarkTests` (nueve gestos que pasan por el espejo) ajustados.

## Guion de device-QA (iPhone de pruebas, Yala Dev, cuenta de la nube real)

1. En el iPhone 14, borra Yala Dev e instálala desde Xcode.
2. En la bienvenida, «Ya tengo una cuenta» → entra con tu cuenta de Yala.
3. Cuando aparezca la barra de «Trayendo tu cuenta», toca «Cancelar la activación» y confirma. Debes volver a la
   bienvenida.
4. Cierra Yala del todo (desliza hacia arriba en el selector de apps) y ábrela.
5. Debe abrir en la bienvenida otra vez. Si abre en la app, apúntalo en la card.
6. Para comprobar que no adjuntó iCloud: elige «Es mi primera vez» → privacidad total; debe pasar por «Ya tienes datos
   en tu iCloud» (pregunta), no traer los datos sin preguntar.
