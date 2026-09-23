---
id: device-qa-discard-gate-returns-to-restore-without-icloud
status: done
priority: high
area: "onboarding, modo-nube"
created: 2026-09-14
source: "device-QA del PR de `activation-discard-gate-exits-without-wiping-when-icloud-is-unreachable` (2026-09-14)"
updated: 2026-09-23
qa-status: not-replicable
qa-date: 2026-09-23
qa-notes: barrido 2026-09-23 sin device-QA - variante sin iCloud de la puerta de descarte; WelcomePrivateICloudGateWiringTests
---

# Device-QA · «Empezar desde cero» sin iCloud vuelve a Restaurar, y no promete nada

## Qué se arregló, en lenguaje de usuario

Uso Yala solo para grupos y activo Yala completo. En «Restaurar» toco **«Empezar desde cero»**. La app va
a mirar qué hay en mi iCloud y no lo consigue —se cae la red, o iCloud está apagado en el teléfono—.

**Antes:** me decía «Seguir así», me llevaba al onboarding, y mis datos viejos seguían enteros. Un borrado
anunciado que nunca ocurrió. Y peor: la app quedaba **apuntada** para el aviso del espejo tardío, cuyo
botón de borrar se lleva las preferencias y **el dominio de Grupos** — o sea que quien activaba Yala
completo justo para conservar sus grupos podía acabar sin ellos, arranques después.

**Ahora:** dice que no pudo revisar el iCloud, que **no borró nada**, y devuelve a Restaurar con las dos
opciones abiertas: reintentar o traerse los datos.

## Por qué NO es simulable

Dos capas, y las dos cierran el paso:

1. **`measure()` sale por `SwiftDataConfiguration.isUITesting` antes de tocar CloudKit**, así que bajo
   XCUITest la puerta nunca llega a las fases `.noICloud` / `.unreachable`.
2. **`ICloudPersonalCorpusProbe` no tiene seam de uitest**, y el simulador no tiene cuentas de iCloud
   reales: no hay forma de provocar un `.failed` distinguible de un `.noAccount`.

Lo simulable es el cableado, y eso lo cubre `YalaTests/WelcomePrivateICloudGateWiringTests` con **catorce
mutantes verificados** — uno de ellos sobrevivió al primer test y obligó a reescribirlo.

## Qué hace falta

- Un iPhone real con Yala instalada, con **sesión de grupos** viva (al menos un grupo con movimientos).
- Un Apple ID con **datos personales previos en iCloud** (movimientos, cuentas), para poder llegar a
  «Restaurar → encontramos tus datos».
- Poder cortar la red (modo avión) y poder apagar iCloud en Ajustes de iOS.

## Recorridos

### 1 · El caso principal: la red se cae en la ventana

1. Con la sesión solo-grupos, Perfil → **«Activar Yala completo»** → «Es mi primera vez» → «Tu cuenta en
   tu iCloud privado».
2. La app pide reabrirse (relanzamiento del espejo). Reabrir. Debe aterrizar en **Restaurar** con las
   cifras de lo que hay en iCloud.
3. Tocar **«Empezar desde cero»** y confirmar el diálogo.
4. **En cuanto aparezca «Revisando qué hay en tu iCloud…», activar el modo avión.**
   - Si la sonda ya contestó, volver atrás y repetir: la ventana es de segundos y puede hacer falta un
     par de intentos.
   - **Se espera:** «No pudimos conectarnos a iCloud», con «Reintentar» arriba y **«Volver atrás»**
     abajo. El cuerpo dice que **no se borró nada**.
   - **FALLO si dice «Seguir así»** o si el cuerpo habla de continuar: ése es el copy viejo.
5. Tocar **«Volver atrás»**. **Se espera:** la pantalla de Restaurar, con sus opciones.
6. Quitar el modo avión y tocar **«Traer mis datos»**. **Se espera:** el restore encuentra el corpus y lo
   trae. Los datos siguen enteros — nadie borró nada.

### 2 · El daño de detrás, que es lo que de verdad hay que comprobar

Es el recorrido caro y **el que decide si el PR cumplió**: prueba que la app no quedó apuntada para el
borrado con scope `.handover`.

1. Repetir los pasos 1-5 del recorrido 1 (llegar al aviso sin red y tocar «Volver atrás»).
2. Quitar el modo avión. Desde Restaurar, tocar **«Empezar desde cero»** otra vez, ahora **con red**.
   Confirmar las dos veces y dejar que el borrado termine.
3. Terminar el onboarding personal.
4. **Comprobar que los grupos siguen ahí**, con sus movimientos.
5. Cerrar Yala del todo y **reabrirla dos o tres veces**, con red.
   - **Se espera: NO sale ningún aviso de «Encontramos datos tuyos en iCloud».**
   - **FALLO GRAVE si sale.** Ese aviso es el del espejo tardío: su botón de borrar purga el dominio de
     Grupos, y quien activó Yala completo lo hizo precisamente para conservarlos. Si aparece, **no tocar
     el botón de borrar** y avisar.

### 3 · La otra fase: iCloud apagado en el teléfono

El ticket daba esta fase por inalcanzable y **se midió que no lo es**: «Empezar desde cero» también se
ofrece desde los estados de Restaurar que no encontraron nada.

1. Ajustes de iOS → apagar **iCloud** para Yala (o cerrar sesión de iCloud).
2. Con la sesión solo-grupos, activar Yala completo → «Es mi primera vez» → «iCloud privado» →
   relanzamiento → Restaurar.
3. La pantalla dirá que no encontró nada (o que iCloud está desactivado). Tocar **«Empezar desde cero»**.
   - **Se espera:** «No pudimos revisar tu iCloud», el cuerpo diciendo que **iCloud está apagado en este
     teléfono** y que no se borró nada, y dos botones: **«Reintentar búsqueda»** y **«Volver atrás»**.
   - **FALLO si el botón dice «Seguir así»** o si al tocarlo aterriza en el onboarding.
4. **Sin salir de la puerta**, ir a Ajustes de iOS, **encender iCloud**, volver a Yala y tocar
   **«Reintentar búsqueda»**.
   - **Se espera:** la puerta vuelve a medir y aterriza donde corresponda (`.found` con cifras, o el
     onboarding si no había nada).
   - **FALLO si ese botón no existe.** Sin él, esta pantalla y Restaurar se devuelven la pelota: las dos
     ofrecen solo «Empezar desde cero» / «Volver atrás», y la activación no se puede terminar desde
     dentro. Es el defecto que la review adversarial cazó antes de commitear.
5. Repetir hasta el paso 3 y tocar **«Volver atrás»**. **Se espera:** Restaurar.
6. **El chevron, que es el otro control que sale de aquí.** Repetir hasta el paso 3 y tocar la **flecha de
   la barra** en vez del botón. **Se espera:** Restaurar, igual. Los dos van al mismo sitio y los dos
   retiran el borrado pendiente — si uno de los dos dejara la app apuntada, el recorrido 2 lo destapa.
7. Volver a encender iCloud.

### 4 · Control negativo — el Welcome NO cambia

Sin él, los tres recorridos de arriba podrían pasar con la puerta del Welcome rota igual.

1. En un teléfono sin Yala configurada (o tras «Empezar de cero» completo), abrir la app → Welcome →
   «Es mi primera vez» → «Tu cuenta en tu iCloud privado».
2. **Con el modo avión puesto** desde antes de tocar esa opción.
   - **Se espera:** «No pudimos conectarnos a iCloud» con **«Seguir así»** de segunda salida, y al
     tocarla la app **sigue** al onboarding.
   - **FALLO si vuelve atrás**: ahí no hay app detrás a la que volver, y el ADR dice que no poder
     preguntar JAMÁS bloquea. Un primer arranque sin conexión se quedaría sin ninguna forma de entrar.

## Qué hacer con el resultado

- Todo PASS → cerrar este ticket.
- El recorrido 2 en FALLO → ticket `high` inmediato: el testigo del espejo tardío se sigue escribiendo por
  algún camino de esta puerta.
- El recorrido 4 en FALLO → ticket `high`: los dos desenlaces están intercambiados.

## Barrido de `qa` · 2026-09-23 · cerrado sin device-QA

Sale de la cola de device-QA por el barrido que pidió Jürgen el 2026-09-23 (encargo `2026-09-23-barrido-qa-in-qa-pre-device`). Es la variante sin iCloud de la misma puerta que se prueba en `restore-start-fresh-keeps-the-imported-corpus`, y necesita una ventana sin red de segundos. Lo cubre `WelcomePrivateICloudGateWiringTests`.
