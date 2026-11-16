Yala
# Explorar qué formularios de Yala se convierten en flujos guiados como el onboarding, con una maqueta comentable por flujo
---
toca: docs/exploracion/formularios-guiados/, tickets/done/2026-11-15-exploracion-formularios-guiados.md
esfuerzo: high
cierre: cierra-sola
---

## Qué pidió Jürgen (15-nov)
Los formularios actuales son largos, complicados y confusos. Quiere ir transformando los flujos habituales en algo como el onboarding (preguntas una a una con tarjetas, chips y el estilo del chat guiado), mucho más sencillo para el usuario. Por ejemplo, al **crear una cuenta** se abre el guiado tipo chat del onboarding, con una opción arriba de **«Usar formulario»** para quien prefiera el formulario de siempre.

Esta sesión es **solo exploración y maqueta, sin tocar el código de la app**.

## Qué hacer
1. **Inventario:** recorre el código y lista todos los flujos de creación y edición que hoy son formularios. Como mínimo: crear cuenta, crear presupuesto, crear pago planificado o recurrente, crear favorito, más lo que encuentres (nuevo registro, transferencia, grupo, gasto de grupo, saldo inicial de miembro, categoría, etiqueta, meta, etc.). Para cada uno di cuántos campos tiene, cuáles son obligatorios y qué confunde.
2. **Recomendación:** marca cuáles conviene convertir en guiado y cuáles no (por ejemplo, un registro rápido quizá se queda como está), con el motivo, valor y esfuerzo, y en qué orden.
3. **Una maqueta por flujo recomendado**, con el estilo real del onboarding de Yala. Las guías son `Yala/App/Views/Onboarding/PrimerosPasos/` (`FirstBudgetFlowView`, `FirstScheduledPaymentFlowView`, `FirstAccountFlowView`, `TutorialQuestionPieces`) y el chat del onboarding de Yala IA. Cada maqueta incluye:
   - La opción arriba para cambiar a «Usar formulario».
   - **Todas** las preguntas que cubren los campos del formulario actual (no quites ninguna, porque Jürgen decide qué quitar), cada una con su texto propuesto, el tipo de respuesta (chips, tarjetas, monto, fecha, etc.), el valor por defecto o sugerido, y cuándo se salta (por ejemplo, si solo tiene una moneda).
   - La pantalla de confirmación y la de éxito.
   - Textos con el brand voice (`docs/planning/BRAND-VOICE.md`), en español neutro latinoamericano, muy sencillo para alguien que no sabe nada de dinero.
4. Coherencia con lo que ya está en cola: hay una sesión que hará un «motor de guiados» dentro de Yala IA para presupuestos y pagos recurrentes (`ia-guiados-presupuesto-y-recurrentes`). Las maquetas deben poder reusar ese mismo motor y verse igual. Dilo en la recomendación.

## El artifact (lo más importante)
- Un artifact visual de Claude, interactivo (nunca Markdown ni PDF), con navegación por flujo y las pantallas de cada uno en un marco de iPhone, en modo oscuro como la app.
- **Comentarios de Jürgen:** en cada pantalla y en cada pregunta debe poder escribir un comentario (quitar, cambiar texto, reordenar, etc.). Los comentarios se guardan en el navegador (no se pierden al recargar), con un contador por flujo y un botón **«Copiar todos los comentarios»** que los copie en texto ordenado (flujo, pantalla, pregunta y comentario) para pegármelos en el chat. Así la implementación se hace tal cual la maqueta con sus comentarios.
- Publicado y con su link en el cierre. Guarda la fuente en `docs/exploracion/formularios-guiados/`.

## Cierre
- PR a 2.3 solo con `docs/exploracion/formularios-guiados/` y el ticket, sin firma de IA.
- Cierre según el modo fijado al arrancar: si está completo y el modo lo permite, `/cerrar-total`.
- En el cierre van el link del artifact, «Saltado o asumido sin preguntar» y «Decidido sin consultar», cada uno con su motivo o «Nada».

## Paso 0 — decisiones (resueltas en autónomo, sesión nocturna)

1. **Comentarios:** en el navegador (`localStorage`) + «Copiar todos los comentarios», como pide el encargo. Sin base compartida: nadie la pidió y añade una pieza que puede fallar.
2. **Maquetas:** una por cada flujo marcado «Convertir». Los «No» no llevan maqueta.
3. **Campos:** ninguno se quita. Cada campo del formulario actual tiene su pregunta, aunque casi siempre se salte.
4. **«Usar formulario»:** botón en la barra de arriba, en todas las preguntas; lo respondido pasa al formulario.
5. **Confirmación:** pantalla «Revisa antes de crear» con cada respuesta y «Cambiar» al lado (Primeros pasos no la tiene).
6. **Tema:** solo oscuro, como pide el encargo.
7. **Navegación:** cada flujo enseña todas sus pantallas en fila y un modo «Recorrer» de una en una.
8. **Entrega:** PR a 2.3 en cola de auto-merge (el diff es solo docs/tickets; el encargo pide PR).
9. **Motor de guiados de Yala IA:** su encargo no está en esta máquina. Se asume que generaliza las piezas de Primeros pasos (`TutorialQuestionScreen`, `TutorialOptionButton`, `TutorialSelectableTile`, `TutorialChip`, `TutorialAmountField`) a pasos declarados como datos; las maquetas se escriben como datos con ese contrato.
