Yala
# Al entrar, el Panel y Grupos muestran lo que ya tienes, y la bienvenida cabe en el iPhone 14
---
card: tablero-tras-tu-cuenta-esta-lista-el-panel-sale-c8i9
toca: Yala/App/ViewModels/PanelViewModel.swift, Yala/App/ViewModels/RecordsViewModel.swift, Yala/App/Logic/LiveAnchorEducationLogic.swift, Yala/App/Views/Panel/Sheets/BalanceLiveAnchorEducationSheet.swift, Yala/App/Tips/YalaTips.swift, Yala/App/Models/AppRouter.swift, Yala/App/Views/Onboarding/WelcomeChooserView.swift, Yala/App/Views/Onboarding/WelcomeShowcaseView.swift, Yala/App/Logic/GroupsOnboardingLogic.swift, Yala/App/Logic/ReturningGroupsMemberLogic.swift, Yala/App/Logic/GroupsConsentPathLogic.swift, Yala/App/Logic/RouterConsumerGateLogic.swift, YalaTests/PanelAfterAccountReady/, tickets/backlog/panel-and-groups-show-data-on-entry.md, tickets/done/panel-and-groups-show-data-on-entry.md
esfuerzo: high
cierre: cierra-sola
---

Lote de bugs del recorrido de la bienvenida en el iPhone 14 (13-nov), reportados por Jürgen. Lee cada card entera.

1. `tablero-tras-tu-cuenta-esta-lista-el-panel-sale-c8i9` (muy grave): tras «¡Tu cuenta está lista!» el Panel y Registros salen vacíos aunque el store ya tiene los datos; en un caso (Apple sobre una cuenta abierta antes con Google, mismo correo) siguen vacíos incluso tras reabrir. Que las vistas se enteren cuando el adopt escribe los datos, y mide la pista del identificador de sesión entre Apple y Google. Jürgen: «no confundamos al usuario»; si los datos de verdad no están listos, un spinner, nunca un Panel en cero.
2. `tablero-tras-reabrir-la-guia-tu-saldo-se-mueve-s-3f57`: tras reabrir, la guía «Tu saldo se mueve solo» queda debajo de la barra de pestañas.
3. `tablero-entrar-por-dividir-con-amigos-lleva-al-p-x5tm`: entrar por «Dividir con amigos» lleva al Panel personal y no a Grupos.
4. `tablero-grupos-muestra-la-intro-de-usuario-nuevo-zkyg`: Grupos muestra la intro y vuelve a pedir el consentimiento a quien ya tiene grupos.
5. `tablero-bienvenida-en-el-iphone-14-dividir-gasto-wju5`: primero verifica con la build de 2.3 actual (los ajustes visuales del Welcome ya están en un PR); si ya no pasa, cierra la card con la evidencia.

No cambies textos salvo lo mínimo; si hace falta, anótalo. `PanelViewModel.swift` también lo toca el lote de cuelgues de Sentry: rebasa sobre 2.3 si ya se mergeó.

**Pruebas:** de punta a punta en el iPhone 14 por DeviceMCP (conectado a la Mini; ya no tenemos las limitaciones del simulador). Si el iPhone está ocupado, usa un segundo simulador. Tests que fallen sin el arreglo, en la subcarpeta propia de `toca:`. Corre solo las pruebas de interfaz que toca el cambio y la suite completa una vez al final. Si hay dos timeouts seguidos, la prueba es inestable: anótalo y sigue. Tope de 30 minutos en pruebas de interfaz, y nunca más de 3 minutos sin escribir avance.

**Archivos:** puede correr en paralelo con otra sesión de Yala en la otra máquina, así que te quedas dentro de `toca:`. Si de verdad hace falta tocar algo fuera, que sea un cambio mínimo: lo anotas en «Decidido sin consultar» y rebasas sobre 2.3 antes del PR. Hay PR abiertos de la bienvenida y de «entrar con la cuenta a medias» contra 2.3: rebasa sobre lo último antes de abrir el tuyo.

**Entrega:** un PR contra 2.3 (la 2.2 está cerrada), mergeado si CI pasa, el ticket en done y las cards en QA. Commits y PR sin firma de IA. Lo menor y reversible lo decides y lo anotas en «Decidido sin consultar». Lo vital (acceso, datos del servidor, seguridad) se pregunta según el modo de la sesión. Si el trabajo queda completo y el modo lo permite, cierra con `/cerrar-total`.

## Paso 0 — decisiones (resueltas en semi, sin preguntar: ninguna es vital)

1. **Bug 1, dónde va el refresco:** en el aviso del motor de la nube (`AppBootstrapper`, fuera de `toca:`), no en cada
   pantalla. Causa medida en el código: el primer tirón del motor solo marcaba «cambios pendientes», y eso solo se aplica
   al volver a primer plano. Arregla Panel, Registros y Grupos a la vez.
2. **Bug 1, «spinner, nunca un Panel en cero»:** el esqueleto del Panel, solo si el Panel carga vacío con el motor sin
   su primer tirón; sigue hasta que el tirón termina (sin datos a medias). Techo 60 s.
3. **Bug 1, pista Apple/Google:** refutada por grep (ninguna vista filtra por la sesión). Se anota en el ticket.
4. **Bug 2:** el Panel sube hasta lo que señala la guía, como ya hace con el tour Pro (`PanelView`, fuera de `toca:`).
5. **Bug 3:** la puerta de Grupos se recuerda en memoria desde «Entra aquí» hasta «Empezar» (lógica nueva +
   `WelcomeFlowContainer` y `ContentView`, fuera de `toca:`, cambios mínimos).
6. **Bug 4:** sin intro si hay grupos; con sesión y sin grupos aún, se decide tras el primer tirón de Grupos y solo con
   la pestaña a la vista (`GroupsContainerView`, fuera de `toca:`).
7. **Bug 5:** depende del PR abierto de ajustes del Welcome (aún no está en 2.3); se verifica con su rama y, si ya no
   pasa, se cierra la card con la evidencia.
8. Textos: ninguno cambia.
