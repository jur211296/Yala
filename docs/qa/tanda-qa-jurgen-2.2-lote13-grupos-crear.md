# Tanda de QA · 2.2 · lote decidido 13 — Grupos: crear el primer grupo, educativo, consentimiento y entrar

Barrido del 2026-10-21, acotado a las 10 cards de la sesión. **Revisadas 10 · cerradas en el barrido 7 · para el iPhone
3 · para capturas 0** (las capturas del antes y el después ya están en
`~/Claude/entregas/Yala--lote-decidido-2-2-13-grupos-crear/capturas/`). Tiempo total en el iPhone: **~12 min**.

Lo que se queda necesita **inicio de sesión real con Apple o Google** y **crear un grupo en el servidor** (§4): el
simulador no tiene sesión real y crear es server-first. Todo lo demás se probó en el simulador.

## Bloqueantes

| Card | ¿Bloquea 2.2? | Por qué |
|---|---|---|
| L12-12 | Sí | Es el primer contacto de quien viene a crear un grupo; si el alta y la creación no casan, se queda sin grupo. |
| L12-4 | No | El registro del consentimiento contra la cuenta lo fijan tests; se mira que la cadena no lo pida dos veces. |
| L13-8 | No | Si falla, cae en el comportamiento anterior (la pestaña Grupos). |

## Montaje único

**Build:** el primero de 2.2 que lleve este PR, en **Yala Dev** (contra staging), en el iPhone de pruebas.
**Estado:** Yala Dev recién instalada (bórrala y vuelve a instalarla) o, si ya está, «Cerrar sesión» en Ajustes hasta
volver a la bienvenida. Ten a mano una cuenta de Apple o Google **que no tenga grupos**.

### 1 · L12-12 + L12-4 · «Crear mi primer grupo» desde la bienvenida (~5 min)

1. Abre Yala Dev → **Empezar** → **Vengo por un grupo** → **Crear mi primer grupo**.
2. **Esperado:** sale directamente «Grupos en la nube» con cuatro puntos y **Aceptar y continuar** (no los dos
   pasos de «Así funcionan los grupos»). Arriba a la izquierda hay una «X», no una flecha.
3. Toca **Aceptar y continuar**. **Esperado:** «Conecta tu cuenta» con «Continuar con Apple», «Continuar con Google» y
   debajo «Si ya tienes cuenta, entras; si no, se crea.». **No** vuelve a salir «Grupos en la nube».
4. Entra con tu cuenta. **Esperado:** «Nuevo grupo» con **Tu nombre en el grupo** arriba y el nombre del grupo debajo
   («Ej.: Viaje a Cusco»). El ✓ está apagado hasta que escribes los dos.
5. Escribe tu nombre y «Depa Miraflores» → ✓. **Esperado:** aterrizas en Grupos con el grupo creado y la hoja
   ««Depa Miraflores» está listo» para invitar.
6. Abre el grupo → Miembros. **Esperado:** sales con el nombre que escribiste (no «Usuario»).

### 2 · L13-8 · «Grupo» del botón + sin grupos (~4 min)

Necesita una cuenta **sin grupos** y con Yala completo (Panel con cuentas). Si el paso 1 te dejó solo con Grupos, usa
otra instalación o sáltalo y dímelo.

1. En el **Panel**, baja hasta que aparezca el botón **+** abajo a la derecha → **Grupo**.
2. **Esperado:** una hoja «Para dividir un gasto, primero crea un grupo» con **Crear grupo**.
3. **Crear grupo** → escribe un nombre → ✓. **Esperado:** se abre el gasto con el aviso **Ahora apunta el gasto**
   arriba (sin la hoja de invitar en medio).
4. Cierra el gasto sin guardar, vuelve a la pestaña Grupos y crea otro grupo desde el **+** de Grupos.
   **Esperado:** sale la hoja de invitar, y **no** se abre ningún gasto solo.

### 3 · L12-4 · el consentimiento queda en tu cuenta (~3 min)

1. Tras el paso 1, cierra Yala del todo (deslízala fuera) y vuelve a abrirla.
2. **Esperado:** Grupos no vuelve a pedir «Grupos en la nube» ni «Ver y aceptar».
3. Si tienes un segundo dispositivo a mano: entra con la misma cuenta en él y abre Grupos. **Esperado:** tampoco te lo
   pide (el consentimiento viajó con la cuenta). Si no lo tienes, sáltalo.

## Lo que pasó a done en el barrido

| Card | Motivo | Evidencia |
|---|---|---|
| L12-1 | Probado en el simulador y con XCUITest | `GroupsCrearDecididoUITests#test_groupDetailTabs_nameOnlyOnTheSelectedOne_andSaldos`; capturas `antes-1-detalle-grupo`, `despues-1-detalle-grupo`, `despues-1b-saldos` |
| L12-3 | Probado en el simulador y con XCUITest | `GroupsCrearDecididoUITests#test_needsConsentEmptyState_buttonSaysReviewAndAccept`; `antes-6-ultimo-paso` / `despues-6-ver-y-aceptar` |
| L12-5 | Probado en el simulador | `antes-7-consentimiento` / `despues-7-consentimiento`, `despues-4-educativo-paso3-consentimiento` |
| L12-6 | Probado en el simulador | `antes-3-educativo-paso2` / `despues-3-educativo-paso2` |
| L12-7 | Probado en el simulador y con XCUITest | `GroupsEducationalUITests#test_educational_lastStep_isTheConsent_andAcceptingGoesStraightToTheAccount`; `antes-5-conecta-tu-cuenta` / `despues-5-continuar-con-apple-google` |
| L12-9 | Probado en el simulador y con XCUITest | `GroupsCrearDecididoUITests#test_newGroupForm_optionsAreFoldedUnderMoreOptions`; `antes-2-formulario-grupo` / `despues-2-*` |
| L12-11 | Probado en el simulador y con XCUITest (consentimiento → formulario) | `GroupsCrearDecididoUITests#test_createGroup_afterAcceptingTheConsent_opensTheForm`; `despues-8-tras-aceptar-formulario` |

## Lo que se queda

| Card | Qué lo retiene (§4) |
|---|---|
| L12-12 | Inicio de sesión real + crear el grupo en el servidor |
| L12-4 | Inicio de sesión real: que el consentimiento aceptado sin cuenta se registre en ella |
| L13-8 | Crear el grupo en el servidor (el gasto con aviso aparece tras crearlo) |
