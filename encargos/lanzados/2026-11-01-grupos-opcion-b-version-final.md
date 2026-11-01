---
esfuerzo: high
release: no
---
# Grupos: versión final de la opción B con Jürgen (líneas en tu parte y Cobro) e implementación

Card: tablero-grupos-version-final-de-la-opcion-b-con-hozg

## Contexto
El 1-nov a las 14:32 Jürgen eligió la **opción B** de las propuestas para partir tu parte de un movimiento de grupo en líneas (gasto, ingreso o recarga) y para apuntar **Cobros** como tipo de movimiento del grupo. Las propuestas están en `docs/disenos/grupos-tu-parte-en-lineas/` (`README.md` y `propuestas.html`, PR #731). Jürgen tiene detalles de B que no le cuadran.

## 1. Primero: acordar la versión final con Jürgen (sesión INTERACTIVA)
- Lee el doc de propuestas completo, sobre todo la opción B y sus 9 cards.
- Pregúntale a Jürgen, con AskUserQuestion o con una pregunta abierta en la sesión, **qué cambiaría de B**. Él ya eligió B: no le vuelvas a ofrecer A o C.
- Itera con él hasta cerrar los detalles pendientes.
- **No implementes nada** hasta acordar la versión final. Déjala escrita en el doc del repo (sección «Versión final acordada» en `docs/disenos/grupos-tu-parte-en-lineas/README.md`).

## 2. Después: implementar lo que quepa en esta sesión
- Orden: primero las **líneas en tu parte**, después el **Cobro**.
- Cada parte va con tests y con capturas de antes y después en el digest.
- Lo que toque el servidor (Worker o Supabase) se prueba en **staging antes de producción**.
- Si no cabe todo, crea cards de lo que falta en 2.2 (alta, cierra-sola, asignadas a frank). Cada una lleva su brief y entra en la cola **antes del barrido QA (S36)**.

## 3. Cierre: la excepción de decisión vital de diseño
Esta sesión **no cierra sola** mientras falte acordar la versión final con Jürgen. Si Jürgen no responde, espera; no decidas por él. Cuando la versión esté acordada y escrita, y lo que cupo esté implementado (y lo demás tenga card), cierra.

Termina con /cerrar-total.

## Paso 0 — decisiones

> Sesión interactiva: D1–D4 las tomó Jürgen en la sesión (1-nov); D5–D8 son técnicas, resueltas por Frank con su OK al plan.

**D1 · ¿Qué cambia de B?** → El formulario de Nuevo gasto no cambia; partir tu parte va a la Bandeja, a la pantalla de
éxito y al detalle del registro, y solo con el puente activo. No hay Cobro: una venta es un gasto de grupo con
categoría de ingreso. La línea de ingreso desaparece (Gasto | Recarga). *(Jürgen.)*
**D2 · Venta por cobrar mientras no pagan** → «Grupos» la suma (por cobrar) y Estadísticas no la cuenta. *(Jürgen, 1·a.)*
**D3 · Pago parcial** → cubre lo más antiguo primero; el ingreso cuenta el día del pago. *(Jürgen, 2·a.)*
**D4 · Vender a medias y cobrar tú todo** → fuera de alcance; dos registros. *(Jürgen.)*
**D5 · Qué entra en esta sesión** → la versión final escrita, 11 cards en el tablero, las reglas de la receta
(`GroupSplitLinesRecipe`) con tests y el diseño técnico del puente en `tickets/in-progress/grupos-tu-parte-en-lineas.md`.
Sin servidor y sin pantallas. *(OK de Jürgen al plan.)*
**D6 · Dinero de las líneas** → `Decimal`, guardado como texto en el JSON. Por qué: 500 + 10 tiene que dar 510 exacto.
**D7 · Referencias de la receta** → por `shortcutID` (identidad de sync de cuenta y subcategoría). Por qué: un
`PersistentIdentifier` no viaja entre aparatos.
**D8 · Una receta de versión posterior** → se lee como `.newerVersion` y no se pisa. Por qué: un aparato viejo no debe
rehacer en una línea lo que escribió uno nuevo.
