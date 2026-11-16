---
toca: Yala/App/Views/, Yala/App/ViewModels/, Yala/Resources/, YalaUITests/, YalaTests/
release: no
---
Yala
# Lote de cierre 2.2: traba en Perfil, títulos cortados, texto al máximo, «sol peruano» y «Guardar listos» de la Bandeja

Lote de 5 tareas chicas de 2.2 (un PR, un cierre), autorizado por Jürgen el 9-nov. Son las últimas mías antes de subir 2.2 a TestFlight y App Store. Lee cada card en el tablero (`tablero listar --proyecto Yala --version 2.2`) antes de empezar, y el informe `docs/qa/qa-fisico-2-2-iphone14.md` (PR #874, abierto) para las capturas.

## Las 5 cards
1. «La app se traba en Perfil (App Hang) · YALA-IOS-G» (lista para lanzar). Ojo: hoy se mergeó en 2.2 el arreglo de la foto de perfil (PR #875). Mide primero si ya lo cubre; si sí, ciérrala con evidencia; si no, arréglalo.
2. «En el iPhone 14, dos títulos salen cortados con el texto a tamaño normal»: «Salda deudas con un par de toq…» en la intro de Grupos y «Pagos plani…» en la tarjeta del Panel.
3. «Con el texto al máximo, los iconos de vista de Pagos planificados se montan unos sobre otros y el menú del + parte o corta sus opciones» («Gru-po», «Ima-gen», «Ma…»; «Pagado» sale «Paga…»).
4. «Onboarding: la moneda de la cuenta principal sale en minúscula («sol peruano»)» y en el resto «Sol Peruano»: unifica.
5. «UI nocturna · «Guardar listos» de la Bandeja falla 3 de 3 en InboxCrudUITests»: mide contra la versión publicada si es bug de la app o del test; arregla lo que corresponda sin debilitar el test.

## Cómo
- Desde `origin/2.2` al día. Un solo PR contra 2.2, commits y PR sin firma de IA.
- Verifica en simulador (texto normal y tamaño de accesibilidad máximo). Haz tú mismo el QA en el iPhone 14 por DeviceMCP cuando haga falta para dar algo por bueno. En la Max puedes usar un segundo simulador si otro está ocupado (tope 2).
- Hay un PR abierto de la calculadora del saldo (#876, solo test de onboarding): no lo pises.
- Jürgen pidió (9-nov) que esto cierre solo hasta done: NO dejes ninguna card en «in qa». Haz tú el QA (simulador y, si hace falta, iPhone 14), mergea con CI verde y mueve las 5 cards directo a done con evidencia (PR, capturas, tests). Si alguna no se puede resolver, déjala con la explicación y sigue con las demás.

## Límites
- No toques TestFlight, marketing/ ni 1.0.
- Lo menor y reversible lo decides tú y lo anotas en «Decidido sin consultar».

## Cierre
Según el modo fijado al arrancar: en semiautónomo, si está completo y mergeado, `/cerrar-total`; lo vital se pregunta y se espera con la sesión viva. En nocturno, lo vital va a checkpoint recuperable con card «Espera decisión» para Jürgen, sin mergear lo incompleto; si está completo, `/cerrar-total`.

## Paso 0 — decisiones (resueltas en semiautónomo, por Frank)

- Aviso de sesión viva «registrar-decisiones-2026-11-05» sobre Views/ViewModels/Resources/tests: medido caducado (sin worktree ni tmux en la Max). Se sigue.
- Card del cuelgue de Perfil: el arreglo de la foto (PR #875) NO lo cubre. Sentry trae solo frames del runtime de Swift resolviendo el tipo genérico de la lista de Ajustes (`listColumn`) la primera vez que se abre. Arreglo: cortar el tipo con barreras de tipo por sección. Se mide con `PERF ajustes` (Debug) antes y después.
- Títulos cortados: la tarjeta de la intro de Grupos no reservaba alto para el título (se comprimía a una línea) → `fixedSize(vertical)` como su cuerpo. La cabecera pequeña del Panel (`PanelSmallWidgetHeader`, 13 widgets) pasa a 2 líneas: los títulos que caben no cambian.
- Texto al máximo: iconos de vista con tope de tamaño de texto y Large Content Viewer (el círculo es de tamaño fijo); insignia + fecha apiladas a tamaños de accesibilidad (lista y línea de tiempo); menú del + sin ancho fijo a tamaños de accesibilidad.
- Moneda: se unifica a como la escribe el resto de Yala («Sol Peruano», `.capitalized`), no al revés: es lo que ven ya ~20 pantallas.
- «Guardar listos»: bug del test, no de la app (la Bandeja se cierra sola sin pendientes, igual que en 1.0). El test espera a que se cierre y lo afirma.
