# Mejorar el flujo de caja para que nutra el Flujo proyectado
toca: experiencia flujo de caja → Flujo proyectado

Rama base: origin/2.3 (con Flujo proyectado ya mergeado si aún no lo está). Un solo PR, un solo cierre. Máquina: la libre. Si la prueba va mejor en el celular que en el simulador, usa el iPhone 14 conectado por DeviceMCP. Si corres en la Max y otra sesión de otro proyecto ya usa un simulador, puedes abrir un segundo (tope 2 en la Max) o usar el iPhone 14 conectado por DeviceMCP. En la Mini el tope de simuladores es 1. Cierre autónomo. Termina con `/cerrar-total`. Commits y PR sin firma de IA.

## Contexto
Card: Mejorar la experiencia del flujo de caja para que nutra el Flujo proyectado (tablero-mejorar-la-experiencia-del-flujo-de-caja-jdv9). Va después de la implementación de Flujo proyectado.

## Qué se pide
Mejorar el flujo de caja para alimentar bien el proyectado (datos, UX, consistencia con Tendencias/Panel/widgets). Si faltan decisiones de producto, `preguntar-bot` con opciones. Card a `in qa` con guion.

## Qué NO hay que tocar
marketing/, rehacer WidgetKit desde cero sin necesidad.

## Cómo se sabe que está bien
Card OK; gate verde; `/cerrar-total`.

## Paso 0 — decisiones (resueltas en autónomo (bypass), 2026-11-06 23:45 Lima)

Medido antes de decidir: con plan, el gasto fuera de sus líneas no se proyecta («Otros» solo existe en meses pasados y
el actual, como real); del proyectado no hay camino al plan; armar el plan ya es una pantalla con líneas sugeridas.

1. **Base**: `origin/2.3` (Flujo proyectado ya mergeado). Rama del encargo re-apuntada ahí.
2. **Gasto fuera del plan** → ritmo de 90 días de lo que ninguna línea cubre, sumado al plan (regla de «Otros» para la
   cobertura). Es la opción A de la pregunta 1; se pregunta a las 5:00 (regla nocturna) y se construye mientras.
3. **Puerta del proyectado al plan** → enlace bajo «Proyectado al cierre» en Tendencias y Panel, «Afinar con…» sin plan,
   «Ver tu plan…» con él; no en «Solo gastos» ni en widgets. Opción A de la pregunta 2, mismo trato.
4. **Mantener el plan** (pregunta 3) → no se construye hasta la respuesta.
5. **Rótulo de la fuente con plan** → no cambia («Estimado con tu plan de flujo de caja»), aunque ahora el plan lleve
   también el ritmo de lo de fuera: el copy nuevo sería otra decisión de producto y la cifra ya es estimación.
6. **Widgets** → sin cambios de UI; reciben el mismo cálculo por `WidgetDataCache`.
7. **Review adversarial** → sí: cálculo financiero.
