---
id: onboarding-2-3-groups-tutorial-step
status: qa
priority: high
area: onboarding
created: 2026-11-12
updated: 2026-11-12
source: tablero-bienvenida-2-3-paso-5-grupos-con-el-esti-yuyn (docs/onboarding-2-3/SPEC.md, Y23-13)
qa-status: partial
qa-date: 2026-11-12
qa-notes: simulador iPhone 17 Pro iOS 27.2 - las tres partes, el consentimiento que no avanza solo, «¿Qué quieres hacer?» y «Ahora no» con el mazo en el paso 6, por XCUITest con capturas; reglas de la marca y del aviso de «ya lo viste», por test unitario. Falta en el iPhone, con cuenta de Yala de verdad: crear el primer grupo y unirse por enlace desde el tutorial
---
# Bienvenida 2.3 · Paso 5 · Grupos con el estilo del tutorial (Y23-13)

«Divide gastos con tu grupo» del mazo:

- Si `hasShownGroupsOnboarding` ya está en sí, el paso se da por hecho, el mazo pasa al 6 y un aviso lo dice («Grupos ya
  lo conoces: lo viste al entrar. Seguimos con el paso 6.»).
- Si no, el onboarding de Grupos de hoy, con sus mismos textos, como página corta del tutorial («Grupos · paso N de 3»):
  «Comparte gastos sin perderles el rastro» (la animación de hoy), «Tres pasos, cero hojas de cálculo» (tres tarjetas y la
  nota del registro en la cuenta personal) y el consentimiento (cuatro puntos, que no avanza solo: «Aceptar y continuar» /
  «Ahora no»). Después, «¿Qué quieres hacer?»: Crear mi primer grupo / Tengo un enlace de invitación / Ahora no.
- Crear sigue por el formulario de grupo de siempre en la pestaña Grupos, con su puerta de cuenta (con iCloud privado
  pide conectar la cuenta) y la hoja «Invitar por WhatsApp u otra app» al crear. Tengo un enlace abre la pantalla de pegar
  el enlace de siempre y la unión de siempre («¿Es este grupo?» → «Unirme al grupo»).
- Al terminar aquí se marca `hasShownGroupsOnboarding` (Grupos no lo repite). Al volver al Panel tras crear o unirse, la
  guía «Tus grupos, a un toque» sobre la pestaña Grupos; el mazo en el paso 6.

Avisos para Jürgen: el título del consentimiento es el de la app hoy, «Grupos en tu cuenta de Yala» (decisión 51 de 2.3,
los dos nombres de sitio); la ficha decía «Grupos en la nube». La creación del grupo NO va con preguntas dentro del
tutorial como en el prototipo: la ficha dice que GroupFormView y la hoja de invitar ya existen y que solo hay que «verlo
como página del tutorial», así que se reusa el formulario.

## Guion de QA en el iPhone 14 (Yala Dev, instalación nueva de 2.3)

1. Borra Yala Dev, instálala y entra con Google o Apple. Haz o salta los pasos 1 a 4 hasta que el mazo diga «5 de 7».
2. Toca el mazo: deben salir las tres partes de Grupos; en la tercera, «Aceptar y continuar». Debe salir «¿Qué quieres
   hacer?».
3. Toca «Crear mi primer grupo»: tiene que abrirse el formulario de grupo en la pestaña Grupos. Crea «Prueba QA» y cierra
   la hoja de invitar con «Más tarde».
4. Vuelve al Panel: tiene que salir la guía «Tus grupos, a un toque» y el mazo en «6 de 7».
5. Toca la pestaña Grupos: no debe volver a salir el onboarding de Grupos.
6. (Opcional, con un enlace de invitación de otra cuenta) Repite desde una instalación nueva eligiendo «Tengo un enlace
   de invitación», pega el enlace y únete.

Pruebas: `YalaTests/Bienvenida23PasosPlanificacionTests` y
`YalaUITests/Flows/Bienvenida23PlanificacionUITests#test_step5_groupsTutorial_acceptThenNotNow_thenDeckMovesToStep6`.
