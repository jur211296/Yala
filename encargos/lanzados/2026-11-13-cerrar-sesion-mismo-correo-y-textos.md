Yala
# Cerrar sesión con pantalla propia, Apple y Google con el mismo correo, y textos que cuentan lo que pasó
---
card: tablero-cerrar-sesion-una-vista-propia-con-spinn-p9q0
toca: Yala/Services/CloudSync/CloudSessionSignOut.swift, Yala/App/Views/Shared/SignOutBlockedCopy.swift, Yala/App/Views/Profile/ProfileView.swift, Yala/App/Views/SignOut/, Yala/App/Views/Onboarding/WelcomeCloudSignInView.swift, Yala/App/Views/Onboarding/WelcomeGroupsChooserView.swift, Yala/App/Views/Shared/DestructiveScopeSheet.swift, Yala/Utils/L10n.swift, Yala/Utils/L10n+Bienvenida23Alta.swift, Yala/Utils/L10n+UXAudit22Lote04Decididas.swift, Yala/Resources/de.lproj/Localizable.strings, Yala/Resources/en-GB.lproj/Localizable.strings, Yala/Resources/en.lproj/Localizable.strings, Yala/Resources/es-419.lproj/Localizable.strings, Yala/Resources/es-AR.lproj/Localizable.strings, Yala/Resources/es-ES.lproj/Localizable.strings, Yala/Resources/es.lproj/Localizable.strings, Yala/Resources/fr.lproj/Localizable.strings, Yala/Resources/it.lproj/Localizable.strings, Yala/Resources/ja.lproj/Localizable.strings, Yala/Resources/nl.lproj/Localizable.strings, Yala/Resources/pl.lproj/Localizable.strings, Yala/Resources/pt-BR.lproj/Localizable.strings, Yala/Resources/pt-PT.lproj/Localizable.strings, Yala/Resources/pt.lproj/Localizable.strings, Yala/Resources/zh-Hans.lproj/Localizable.strings, YalaTests/SignOutAndSameEmail/, tickets/backlog/sign-out-view-same-email-honest-copy.md, tickets/done/sign-out-view-same-email-honest-copy.md
esfuerzo: high
cierre: cierra-sola
---

Lote de bugs del recorrido de la bienvenida en el iPhone 14 (13-nov), reportados por Jürgen. Lee cada card entera.

1. `tablero-cerrar-sesion-una-vista-propia-con-spinn-p9q0`: cerrar sesión (y «Quitar mis datos» en modo iCloud mientras sube cambios) con una vista propia y spinner, sin dejar navegar por Ajustes, y sin pedir reabrir Yala salvo que haya iCloud de por medio.
2. `tablero-apple-y-google-con-el-mismo-correo-una-p-188b` (Jürgen: «grave»): una pantalla dice que es la misma cuenta y otra que sería nueva. Con Apple, «Ya tienes una cuenta» muestra el correo como con Google. Mide qué admite hoy la base de datos con el mismo correo. Cambiar cómo el servidor vincula cuentas es vital: se pregunta, no se asume.
3. `tablero-textos-de-entrada-y-salida-que-no-cuenta-luc1`: textos que no cuentan lo que pasó (Pro a quien no tiene Pro, la copia antigua de iCloud al eliminar la cuenta, y los demás de la card). Todos los idiomas, en español neutro latinoamericano para es-419.

**Pruebas:** de punta a punta en el iPhone 14 por DeviceMCP (conectado a la Mini; ya no tenemos las limitaciones del simulador). Si el iPhone está ocupado, usa un segundo simulador. Tests que fallen sin el arreglo, en la subcarpeta propia de `toca:`. Corre solo las pruebas de interfaz que toca el cambio y la suite completa una vez al final. Si hay dos timeouts seguidos, la prueba es inestable: anótalo y sigue. Tope de 30 minutos en pruebas de interfaz, y nunca más de 3 minutos sin escribir avance.

**Archivos:** puede correr en paralelo con otra sesión de Yala en la otra máquina, así que te quedas dentro de `toca:`. Si de verdad hace falta tocar algo fuera, que sea un cambio mínimo: lo anotas en «Decidido sin consultar» y rebasas sobre 2.3 antes del PR. Hay PR abiertos de la bienvenida y de «entrar con la cuenta a medias» contra 2.3: rebasa sobre lo último antes de abrir el tuyo.

**Entrega:** un PR contra 2.3 (la 2.2 está cerrada), mergeado si CI pasa, el ticket en done y las cards en QA. Commits y PR sin firma de IA. Lo menor y reversible lo decides y lo anotas en «Decidido sin consultar». Lo vital (acceso, datos del servidor, seguridad) se pregunta según el modo de la sesión. Si el trabajo queda completo y el modo lo permite, cierra con `/cerrar-total`.

## Paso 0 — decisiones (resueltas en semi, 13-nov 19:50)

**Medido antes de decidir:**

- **Mismo correo = misma cuenta, ya hoy.** GoTrue enlaza Apple y Google con el mismo correo verificado al mismo usuario
  (H4 del 16-jul en `docs/DECISIONS.md`) y E10 lo midió otra vez el 13-nov. Dos cuentas solo con correos distintos
  («Ocultar mi correo» de Apple). Jürgen ya decidió (16:15) que siga así: **no se toca el servidor**, solo textos.
- **Con Apple la etiqueta dice «Apple»** porque lee el correo capturado, que Apple solo da la primera vez. La sesión sí
  lo trae (`CloudAuthService.sessionEmail`).
- **El cierre en la nube no reabre si el cambio de almacén en caliente sale bien** (card ypit). Mientras dura, la fase
  es `.awaitingRelaunch` y la ventana enseña «Ya casi está». En E04/E05 se quedó ahí: el cambio no salió. Se mide en el
  iPhone 14 por qué.

**Decidido (menor y reversible):**

1. Pantalla propia de progreso («Cerrando sesión…», «Quitando tus datos…», «Eliminando tu cuenta…») en una ventana de
   UIKit por encima de Ajustes y sus hojas (recurso de `LeaderSignOutBusyOverlay`). Sale mientras el cierre o el borrado
   trabajan y mientras el cambio en caliente está en vuelo; se retira si el cierre se bloquea (su aviso, como hoy), si
   termina en el Welcome o si hay que reabrir. Dentro, la subida a iCloud con su cifra.
2. Eliminar la cuenta sin reabrir termina en «Tu cuenta se eliminó» con lo borrado y «Continuar».
3. Reabrir solo con iCloud montado (no se cambia en caliente), explicado. Tras borrar la cuenta, «Cuenta eliminada» y no
   «Sesión cerrada». Si el cambio en caliente falla sin iCloud, se arregla la causa medida.
4. «Vamos a crear tu cuenta»: con el mismo correo, Apple y Google abren la misma cuenta; con otro, se crea otra. La
   etiqueta del acceso enseña el correo de la sesión también con Apple.
5. Textos: Pro solo con Pro; la copia de iCloud como condición verdadera; el alta del Welcome no nombra iCloud;
   «Creamos tu cuenta» + tres preguntas; sin «Descargando tus datos…» en una cuenta creada en este teléfono; el nombre
   con mayúscula inicial si llega todo en mayúsculas o minúsculas.

**Fuera de `toca:`, mínimo:** `SignOutRelaunchView` (variante de texto), `CloudHydrationBanner` (un término),
`WelcomeConversationLogic` (mayúscula), y sus tests. Se anota en «Decidido sin consultar».
