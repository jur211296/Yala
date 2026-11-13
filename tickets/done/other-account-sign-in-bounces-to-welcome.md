---
id: other-account-sign-in-bounces-to-welcome
status: done
priority: high
area: "welcome, cloud-sign-in"
created: 2026-11-13
updated: 2026-11-13
card: tablero-entrar-con-otra-cuenta-de-google-o-apple-38q3
source: "QA de Jürgen en el iPhone 14 con Yala Dev 2.3 (13-nov)"
---

# Entrar con otra cuenta de Google o Apple funciona al primer intento, sin cerrar Yala ni quedar en bucle

Tres fallos de la bienvenida 2.3, vistos por Jürgen el 13-nov:

1. **Google · «Usar otra cuenta» rebota a la bienvenida.** Solo al tocar otra vez «Entrar con Google» sale el selector.
   Causa: el botón soltaba la sesión y volvía a la vitrina (`useAnotherAccount` → `onBack()`).
2. **Google pide cerrar Yala y, al reabrir, otra vez el inicio de sesión.** Causa (confirmada por Jürgen: el teléfono
   tenía datos del iCloud privado): con ese corpus, la entrada deja iCloud aparte (opción B del 10-nov) por la vuelta al
   neutro del cierre privado; esa vuelta suelta y purga la sesión de la nube (regla del 26-sep) y, con el espejo
   montado, vaciar exige reabrir. Al volver no hay sesión.
3. **Apple · «Usar otra cuenta» queda en bucle.** «Iniciar sesión con Apple» firma siempre con el Apple ID del teléfono:
   rebotar y volver a tocar Apple daba la misma cuenta.

## Hecho cuando

- «Usar otra cuenta» con Google abre el selector de cuentas en el acto.
- Con datos del iCloud privado, entrar a la nube pide reabrir una vez y se firma una sola vez.
- Apple no entra en bucle: con el inicio de sesión web de Apple, «Otra cuenta de Apple»; sin él, la nota de que Apple
  usa el Apple ID del teléfono y «Entrar con Google».
- Tests que caen sin el arreglo.

## Decisiones

- Jürgen, 13-nov: la reapertura va ANTES de firmar (alternativa 2), y la bienvenida no debería abrir iCloud hasta que la
  persona lo elija (alternativa 1, encargo aparte).

## Resolución (2026-11-13)

- **Fallo 1 (Google)**: «Usar otra cuenta» suelta la sesión y vuelve a firmar en el acto (`WelcomeUseAnotherAccount`,
  `useAnotherAccount()` en `WelcomeCloudSignInView`). La flecha «Volver» conserva lo de siempre (`leaveUnifiedAccess`).
- **Fallo 3 (Apple)**: con el inicio de sesión web de Apple (DEV hoy) la salida es «Otra cuenta de Apple», que abre Apple
  por la web (`CloudAuthService.signIn(…, appleOnTheWeb:)`); sin él (producción hoy), la nota de siempre y «Entrar con
  Google». Textos reutilizados, ya en los 16 idiomas.
- **Fallo 2**: con corpus del iCloud privado (con copia en iCloud, sin sello de claim, sin restauración en curso y fuera
  de la nube), la entrada única deja iCloud aparte ANTES de firmar (`WelcomeLeaveICloudBeforeSignIn`): una reapertura y
  un solo inicio de sesión. La regla de seguridad del 26-sep (el vaciado purga la sesión) no se toca.
- Pruebas: `YalaTests/WelcomeOtherAccount/WelcomeOtherAccountTests` (tabla pura + escaneo del cableado; mutantes:
  devolver `onBack()` o quitar el chequeo de iCloud los pone en rojo), `Bienvenida23AltaUITests` (dos casos nuevos, 8/8),
  `YalaTests` entero.

## Device-QA en el iPhone 14 (Yala Dev, staging)

Montaje: Yala Dev recién instalada. Para el paso 3, antes elegir «iCloud privado» en la bienvenida con una cuenta de
iCloud que ya tenga datos de Yala Dev, dejar que los traiga y volver atrás hasta la vitrina (así la bienvenida queda con
iCloud abierto, como el 13-nov).

1. Vitrina → «Entrar con Google» → elegir la cuenta de staging con grupos → en «¿Cargamos tus datos y entramos?» tocar
   «Usar otra cuenta». **Esperado:** se abre en el acto el selector de cuentas de Google, sin pasar por la vitrina.
2. Vitrina → «Entrar con Apple» → en la hoja, la salida dice «Otra cuenta de Apple» y abre la página de Apple para
   escribir otro Apple ID. Cancelar vuelve a la vitrina, sin bucle.
3. Con iCloud abierto (montaje de arriba) → «Entrar con Google». **Esperado:** primero el aviso de que los datos se
   quedan en iCloud y la pantalla de reabrir; al reabrir, el consentimiento y Google UNA vez; después, la cuenta.
