---
id: sign-out-view-same-email-honest-copy
status: done
priority: high
area: "sign-out, account-deletion, welcome, l10n"
created: 2026-11-13
updated: 2026-11-13
card: tablero-cerrar-sesion-una-vista-propia-con-spinn-p9q0
source: "recorrido de la bienvenida con Jürgen en el iPhone 14 (13-nov), escenarios E02, E04, E05, E06, E08, E10, E11"
---

# Cerrar sesión con pantalla propia, Apple y Google con el mismo correo, y textos que cuentan lo que pasó

Tres cards del recorrido del 13-nov (`tickets/recorrido-bienvenida-2026-11-13/README.md`):

1. `tablero-cerrar-sesion-una-vista-propia-con-spinn-p9q0`: tras confirmar «Cerrar sesión», Ajustes se queda con la fila
   girando y se puede navegar; y en E04 (Google, sin iCloud de por medio) acabó en «Ya casi está — vuelve a abrir Yala».
   Igual al eliminar la cuenta (E05) y al «Quitar mis datos» en modo iCloud mientras sube (E08).
2. `tablero-apple-y-google-con-el-mismo-correo-una-p-188b`: «Vamos a crear tu cuenta» dice «con Apple sería una cuenta
   nueva» y «Tu cuenta de Yala» dice que el mismo correo abre la misma cuenta. Con Apple, «Ya tienes una cuenta» dice
   «Apple» en vez del correo.
3. `tablero-textos-de-entrada-y-salida-que-no-cuenta-luc1`: «Tu suscripción Pro no cambia» a quien no tiene Pro; la
   «copia antigua de iCloud» al eliminar la cuenta; «Puedes volver a tu iCloud» en una cuenta nueva; «¡Tu cuenta está
   lista!» antes de las tres preguntas; «Descargando tus datos…» en una cuenta recién creada; «¿Te llamo JURGEN?».

Las decisiones están en el Paso 0 del encargo (`encargos/lanzados/2026-11-13-cerrar-sesion-mismo-correo-y-textos.md`).

## Hecho cuando

Cerrar sesión y Eliminar cuenta en modo cuenta muestran su propia vista de progreso y vuelven a la bienvenida sin pedir
reabrir; con iCloud, se pide solo si es imprescindible y se explica. Ninguna pantalla dice que Apple y Google con el mismo
correo son cuentas distintas, y con Apple se ve el correo. Cada pantalla dice lo que acaba de pasar. Probado en el
iPhone 14.

## Hecho (13-nov-2026)

- **Pantalla propia del cierre** (`Yala/App/Views/SignOut/SignOutProgressOverlay.swift`): «Cerrando sesión…», «Quitando tus
  datos de este dispositivo…» o «Eliminando tu cuenta…», con la subida a iCloud y su cifra dentro. Ventana de UIKit de
  nivel alto, como `LeaderSignOutBusyOverlay`: tapa Ajustes y sus hojas y sobrevive al cambio de almacén. Se queda mientras
  el cambio en caliente está en vuelo (`CloudSessionSignOut.inPlaceSwapInFlight`, nuevo), así que ya no asoma «Ya casi
  está» mientras se cambia. Al eliminar la cuenta sin reabrir, termina en «Tu cuenta se eliminó» con «Continuar».
- **Reabrir, explicado**: con iCloud montado la pantalla dice por qué hay que reabrir; tras eliminar la cuenta, «Cuenta
  eliminada» en vez de «Sesión cerrada» (`SignOutRelaunchView`).
- **Mismo correo**: «Vamos a crear tu cuenta» dice que con el mismo correo Apple y Google abren la misma cuenta; la
  etiqueta del acceso enseña el correo de la sesión también con Apple.
- **Textos**: Pro solo con Pro; la copia de iCloud como condición; el consentimiento del Welcome sin iCloud; «Creamos tu
  cuenta» + tres preguntas; sin «Descargando tus datos…» en una cuenta creada aquí; el nombre con mayúscula inicial.
- Tests: `YalaTests/SignOutAndSameEmail/` y `YalaUITests/SignOutAndSameEmail/SignOutProgressScreenUITests`.

**Sin medir: por qué en E04 y E05 el cambio en caliente no salió** (el teléfono no estuvo disponible). Si vuelve a pasar,
la pantalla de reabrir sale igual que antes, ahora con su explicación; la causa la dice la consola (paso A.4).

## Device-QA (iPhone 14, Yala Dev de 2.3 con este cambio)

Montaje: en la Mac, Xcode › scheme **Yala Dev** › destino **iPhone 14** › Run. Partir de la bienvenida (si hay sesión,
Ajustes › Cerrar sesión).

**A · Cerrar sesión en la nube sin reabrir (Google)**
1. Bienvenida › Entrar con Google › la cuenta test.
2. En «Ya tienes una cuenta» la etiqueta enseña el correo. Toca «Cargar mis datos y entrar».
3. Ajustes › Cerrar sesión › confirma.
4. Esperado: pantalla «Cerrando sesión…» con spinner; Ajustes no se puede tocar; termina en la bienvenida **sin** pedir
   reabrir. Si sale «Ya casi está — vuelve a abrir Yala»: con el iPhone conectado, abre Console.app en la Mac, elige el
   iPhone, filtra por `CloudSignOut swap` y copia la línea (`SKIPPED` o `ABORTED reason=…`).

**B · Apple con el mismo correo**
1. Bienvenida › Entrar con Apple (Apple ID de test@yala-app.pe).
2. Esperado: «Ya tienes una cuenta» enseña **test@yala-app.pe**, no «Apple», y entra a la misma cuenta que Google test.
3. Con un Apple ID sin cuenta de Yala: «Vamos a crear tu cuenta» dice «Con el mismo correo, Apple y Google abren la misma
   cuenta de Yala…». Ninguna pantalla dice que sería una cuenta nueva.

**C · Cuenta nueva**
1. Desde «Vamos a crear tu cuenta», toca «Crear mi cuenta».
2. Esperado: el consentimiento no nombra iCloud; luego «Creamos tu cuenta · Ahora, tres preguntas rápidas…»; la primera
   pregunta propone tu nombre con mayúscula inicial («¿Te llamo Jurgen?»).
3. En el Panel no sale «Descargando tus datos…».

**D · Eliminar la cuenta (modo cuenta)**
1. Ajustes › Tu cuenta de Yala › Eliminar mi cuenta.
2. Esperado en la hoja: la nota de iCloud dice «Si usabas Yala con tu iCloud antes de crear tu cuenta…».
3. Confirma las dos veces. Esperado: «Eliminando tu cuenta…» y después «Tu cuenta se eliminó» con «Continuar»; al tocarlo,
   la bienvenida, sin pedir reabrir.

**E · Quitar mis datos en modo iCloud con cambios por subir**
1. Entra con tu iCloud con datos, apunta un gasto y ve enseguida a Ajustes › Quitar mis datos de este iPhone › confirma.
2. Esperado: «Quitando tus datos de este dispositivo…» con «Subiendo tus cambios a iCloud…» y la cifra, sin poder navegar;
   al terminar, «Ya casi está» explicando que iCloud solo se suelta al cerrar Yala.

**F · Vaciar datos sin Pro**: Ajustes › Vaciar datos › la hoja ya no dice «Tu suscripción Pro no cambia».
