---
id: panel-and-groups-show-data-on-entry
status: done
priority: very-high
area: "bienvenida, panel, grupos, modo-nube"
created: 2026-11-13
updated: 2026-11-13
source: "recorrido de la bienvenida en el iPhone 14 (13-nov), cards c8i9, 3f57, x5tm, zkyg, wju5"
---

# Al entrar, el Panel y Grupos muestran lo que ya tienes, y la bienvenida cabe en el iPhone 14

## Qué pasa hoy (para quien usa Yala)

1. Tras «¡Tu cuenta está lista!», el Panel sale en S/ 0 con «Crea tu primera cuenta» y Registros dice «Sin registros»,
   aunque los datos ya están llegando al teléfono. Solo se arregla cambiando de pestaña, o cerrando Yala.
2. Tras reabrir, la guía «Tu saldo se mueve solo» queda debajo de la barra de pestañas.
3. Quien entra por «Dividir gastos con amigos» aterriza en el Panel personal, no en Grupos.
4. Quien ya tiene grupos ve la intro de usuario nuevo de Grupos y vuelve a aceptar el consentimiento.
5. En el iPhone 14, el enlace «Dividir gastos con amigos» empuja «Entrar con mi iCloud» fuera de la pantalla.

## Causa del bug 1 (medida en el código)

Los datos de la cuenta no los escribe el traspaso en sí: los baja el motor de la nube en su primer tirón, justo
después. Ese tirón solo marcaba «hay cambios pendientes» (`SessionState.markRemoteChangePending`), y lo pendiente solo se
aplica al volver a primer plano o al aparecer una vista (`applyPendingChangesIfNeeded`). Con el Panel ya pintado nadie lo
recargaba, y Registros recarga solo con `dataVersion`, así que tampoco.

**La pista del identificador de sesión entre Apple y Google, refutada por grep:** ni el Panel ni Registros filtran por
la sesión (`PanelViewModel`, `RecordsViewModel` y `RecordsStandaloneView` no leen `CloudAuthService`, el `sub` ni ningún
hash de cuenta). E10 («vacío incluso tras reabrir») encaja con la misma causa si el tirón del motor aterrizó después del
primer cálculo del Panel; queda por confirmar en el iPhone.

## Decisiones (Paso 0, en el encargo)

- El refresco va en el aviso del motor (`AppBootstrapper`), no en el Panel: arregla también Registros y Grupos.
- La espera del Panel es su esqueleto: empieza solo si el Panel carga vacío con el motor sin su primer tirón, y sigue
  hasta que el tirón termina (sin datos a medias). Techo de 60 s, para no quedarse ahí sin red.
- La puerta de Grupos se recuerda en memoria desde «Entra aquí» hasta «Empezar».
- Sin intro de Grupos si la cuenta ya tiene algún grupo; con sesión y sin grupos aún en el teléfono, se decide tras el
  primer tirón de Grupos de esa entrada y solo con la pestaña a la vista.
- Sin cambios de texto.

## Qué se hizo

- **Bug 1:** el aviso del motor de la nube tras un tirón con cambios aplica en el acto con la app delante
  (`RemoteChangesFanOut`), así que el Panel, Registros y Grupos recargan solos. El Panel, si carga vacío con el motor sin
  su primer tirón, enseña su esqueleto hasta que el tirón termina (`PanelAccountDataWait`, techo 60 s).
- **Bug 2:** al sacar «Tu saldo se mueve solo», el Panel sube hasta la píldora que señala (`PanelView`).
- **Bug 3:** «Entra aquí» de «¿Cómo empiezas?» apunta la puerta de Grupos y «Empezar» la consume y abre Grupos
  (`WelcomeGroupsDoorLanding`).
- **Bug 4:** sin intro de Grupos si ya hay grupos; con sesión y sin grupos aún, la decisión espera al primer tirón de
  Grupos de esa entrada, con la pestaña a la vista.
- **Bug 5:** sin cambio de código aquí. Medido el 13-nov con la rama del PR de ajustes del Welcome en un simulador
  iPhone 14 (390×844): con «Dividir gastos con amigos» a la vista, los tres botones caben enteros («Entrar con iCloud
  privado» acaba en y=702; el enlace va de 714 a 758). Lo arregla ese PR.

## Device-QA en el iPhone 14 (Yala Dev, staging)

El simulador no puede entrar en una cuenta de la nube (no tiene App Attest), así que lo de entrar se prueba en el teléfono.

1. Instala Yala Dev de esta rama desde cero. En la bienvenida, «Entrar con Google» con la cuenta que tiene datos y dos
   grupos. «Cargar mis datos y entrar» → «¡Tu cuenta está lista!» → «Empezar».
   **Esperado:** el Panel enseña el esqueleto unos segundos y después tus cuentas y tu saldo (S/ 1353), sin pasar por
   Registros. Nunca «Crea tu primera cuenta» con S/ 0.
2. Ve a Registros: ya están tus registros. Ve a Grupos: la lista de grupos, sin «Comparte gastos sin perderles el
   rastro» ni «Aceptar y continuar».
3. Cierra sesión. Bienvenida → «Dividir gastos con amigos» → «Entra aquí» → misma cuenta → «Empezar».
   **Esperado:** aterrizas en la pestaña Grupos, con tus dos grupos y sin intro.
4. Con una cuenta que tenga dinero en dólares y la tendencia en «Saldo»: cierra y abre Yala.
   **Esperado:** si sale «Tu saldo se mueve solo», el Panel sube hasta la píldora «Hoy» y la tarjeta queda entera
   encima de la barra de pestañas.
5. (E10) Entrar con Apple sobre la cuenta abierta antes con Google (mismo correo): el Panel enseña los datos, también
   tras cerrar y abrir Yala.
