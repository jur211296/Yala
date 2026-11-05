# Bienvenida: volver atrás sin perder el camino, cerrar sin bajar iCloud y avisos que no se pierden con Ajustes abierto
toca: Bienvenida (`ContentView.swift`, `Onboarding/`, `WelcomeGroupsGateView`), cola de avisos del shell con hojas de pestaña (Ajustes), XCUITest de la bienvenida

Rama base: 2.3. Un solo PR contra 2.3, un solo cierre. Máquina: la Mini, con simulador.
Ola 1 de la 2.3 (lote N1 de `docs/planning/cola-2-3-propuesta.md`). En paralelo corren el aislamiento de los unit tests (solo `YalaTests/`, en la Max) y el control del coste de la IA (solo `gateway/`, sin simulador). No toques `YalaTests/` salvo los tests nuevos de este lote, ni nada de `gateway/`. Por esa separación de ficheros las tres sesiones pueden ir a la vez.

Objetivo: que la bienvenida recuerde de dónde vienes, que cerrar la app antes de elegir no adjunte tu iCloud privado y que un aviso importante no se pierda detrás de Ajustes.

Lote de cinco cards del tablero de Yala:

1. «Volver atrás desde el acceso a la nube deja el Welcome como ya elegido, y si la app se cierra ahí se salta la comprobación de iCloud». El onBack del cover de nube tiene que devolver el selector a «no elegido». Test que cierre la app en ese punto y compruebe que la comprobación de iCloud corre.
2. «Welcome solo grupos: volver desde la invitación olvida que venías de «Es mi primera vez»». Volver deja a la persona en la pantalla de la que vino, con XCUITest.
3. «Cerrar Yala en la bienvenida antes de elegir hace que el siguiente arranque baje tu iCloud privado». Ya está decidido (Jürgen, 26-oct): el montaje neutro dura hasta que se elija, no un solo arranque. Test del montaje.
4. «Los botones de las pantallas de la puerta de Grupos no tienen su identificador de accesibilidad en runtime». Que cada botón exponga su identificador (p. ej. `.accessibilityElement(children: .contain)` en el contenedor) y que un XCUITest lo encuentre.
5. «Con Ajustes abierto, un aviso importante (cambio de Apple ID, vaciado remoto) puede perderse hasta el siguiente arranque». Las hojas de pestaña entran en la matriz de la cola de avisos; test que lo pruebe con Ajustes abierto.

Hecha cuando: los cinco tickets pasan a `tickets/done` en el PR, cada arreglo tiene su test (unitario o XCUITest) en verde, `/gate` pasa y el cierre trae un guion corto de prueba para el iPhone.

Restricciones:
- Usa el simulador solo cuando haga falta, pidiendo turno como siempre.
- Toca sincronización y la puerta de Grupos: pide review adversarial antes del PR.
- Nada de despliegues a producción sin el OK de Jürgen.
- PREGUNTAR, NO SALTAR: si alguna duda bloquea o cambia el resultado, pregunta con `preguntar-bot "pregunta con opciones"`. No asumas ni te saltes nada.

Mueve las cards con `tablero`: en curso al empezar e in qa al cerrar.
El cierre trae la sección «Saltado o asumido sin preguntar».
Cierra sola: termina con /cerrar-total.

## Paso 0 — decisiones

> Resueltas en autónomo (bypass): las recomendaciones se dan por buenas. Se discuten en el PR. D6 está preguntada al bot dueño y no se da por hecha.

**D0 · ¿Base?** → la rama nació de `2.2`; se re-apuntó a `origin/2.3` (el encargo dice base 2.3) sin commits propios de por medio.
Por qué: el PR va contra 2.3. Alternativa descartada: rebasar al final (arrastraría 25 commits de 2.2).

**D1 · z5dd: ¿cómo se devuelve el chooser a «no elegido»?** → el `onBack` del cover de nube pone `hasShownWelcomeChooser = false`, y también el `onBack` de Restaurar (misma instancia del patrón: marca al encaminar, vuelve sin bajarlo).
Por qué: es el gesto que ya hacen `onCreateAnotherAccount` y `onCancelFromStep1`. Alternativa descartada: marcar al comprometerse (más superficie, toca las tres entradas y el alta born-cloud).

**D2 · zlbn: ¿cómo dura el neutro hasta elegir?** → el primer arranque de instalación nueva arma el neutro durable existente (`neutralMountArmedKey`) con marca de dueño propia (`freshInstallOwnsNeutralMountKey`); caduca con el chooser como los otros y se retira en el arranque siguiente a terminar el onboarding. Un dueño previo (cierre de sesión, borrado del corpus) no se toca; un dueño posterior se lo queda.
Por qué: reusa el mecanismo y el anti-bucle ya probados; la marca de dueño evita un neutro superviviente cuando algo vuelve a bajar el chooser. Alternativa descartada: quitar el término del archivo en `isFreshInstallForNeutralMount` (rompería la promesa de no-regresión del parque).

**D3 · ¿Test de z5dd y zlbn: XCUITest o unitario?** → unitario (simulación de arranques con las funciones puras del montaje) + source-scan del cableado.
Por qué: bajo `-uitest` cada arranque purga `hasShownWelcomeChooser` y el store es otro sin espejo; un XCUITest que relance no ve el bug.

**D4 · mgaj: ¿dónde vive el origen de «¿Cómo empiezas?»?** → el contenedor lo reporta al abrirlo (`onGroupsChooserOrigin`) y `ContentView` lo guarda y lo devuelve al re-montar (`groupsChooserOrigin`). XCUITest por «Pega tu enlace»; se añade el id `invite_recovery_back` a su «Volver».

**D5 · i64u** → `.accessibilityElement(children: .contain)` en `noticeShell`; el XCUITest del aviso de borrado fallido pasa a buscar `welcome_groups_gate_wipe_failed_back` y afirma que ningún botón sale con el id de la pantalla.

**D6 · ulks: con Ajustes abierto, ¿el aviso crítico espera o sale?** → **A, decidida por Jürgen (2026-11-04)**: Ajustes se cierra y el aviso crítico sale al momento. «Las hojas de pestaña entran en la matriz» = entran en la misma clasificación del 11-oct, donde los críticos salen ya. Descartadas B (esperar: contradice el 11-oct y la card) y C (excepción solo para Ajustes).
Implementación: Ajustes publica en su ventana que está delante; si el aviso que toca es de integridad, el shell le pide cerrarse, retiene el aviso y lo drena con la ventana libre (no presenta mientras otra hoja se va). Quedó en `docs/entry-points.md`.
Medido (iOS 27.2, simulador): sin el cierre explícito el aviso tampoco se perdía —UIKit tumba Ajustes al presentar encima y Ajustes se reabre bien—, así que el XCUITest fija el desenlace y los tests unitarios fijan el mecanismo.

**D7 · Máquina** → la sesión corre en la Max (el encargo decía la Mini). No había simulador `iPhone 17 Pro`; se creó uno (iOS 27.2) para el gate.
