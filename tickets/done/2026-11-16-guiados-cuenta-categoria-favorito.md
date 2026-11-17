---
id: 2026-11-16-guiados-cuenta-categoria-favorito
status: done
priority: high
area: ai
created: 2026-11-16
updated: 2026-11-16
source: encargo 2026-11-16-guiados-cuenta-categoria-favorito (Jürgen, 16-nov, sesión nocturna)
---
# Crear una cuenta, una categoría y un favorito conversando con Yala IA

Con el mismo motor de los guiados de presupuesto y de pago planificado, tres flujos nuevos para CREAR desde el chat:
una cuenta, una categoría (o subcategorías dentro de una que ya existe) y un favorito. Editar sigue abriendo el
formulario. Las preguntas salen de `docs/exploracion/formularios-guiados/inventario.md`.

## Paso 0 — decisiones (resueltas en autónomo (bypass), sesión nocturna; ninguna vital)

**Base.** El PR de presupuesto y pagos ya estaba mergeado. El de «subcategorías, opciones avanzadas…» seguía abierto
en cola de auto-merge con el CI corriendo: esta rama parte de su cabeza (no se duplica nada) y se rebasa sobre `2.3`
antes de abrir el PR.

**Cuenta** (las piezas de Primeros pasos: `FirstAccountFlowLogic`, `FirstAccountDraft`, `FirstAccountCreator`,
`FirstAccountCardPreview`, y los textos de `L10n.PrimerosPasos23.Account`):

1. Preguntas: tipo → monedas → nombre → saldo de cada moneda (en una sola pregunta, un campo por moneda) → en tarjeta,
   día de cierre, día de pago y recordatorio → ¿opciones avanzadas? → últimos 4 números (no en efectivo ni «todo
   junto») y «¿cuenta en tus reportes?» → revisar.
2. Monedas: con una sola moneda en Yala no se pregunta (como el presupuesto). Se elige entre la principal, las de tus
   cuentas, dólares y euros; la principal va marcada.
3. Nombre: sin repetir el de otra cuenta (la pregunta lo dice en vez de apagar el botón). En efectivo y «todo junto»
   se propone («¿La llamamos «Efectivo»?»).
4. «No sé, ayúdame a sacarlo» (la calculadora de saldo) **queda fuera**: es una ayuda opcional que sigue en Primeros
   pasos y en el formulario.
5. Límite del plan gratis (4 cuentas): se mira al pedirla y antes de crear. Si ya está lleno, Yala IA lo dice y no
   abre la tarjeta.
6. «Ver la cuenta» abre su ficha en el Panel (el mismo camino que el aviso de la tarjeta).

**Categoría y subcategoría:**

7. Primera pregunta: «¿Una categoría nueva o subcategorías dentro de una que ya tienes?» (no se pregunta si la frase
   dice «subcategoría» o «categoría»).
8. Nueva: nombre (sin repetir) → ícono y color (ícono propuesto por el nombre, más «Otro ícono» con el selector de
   siempre) → subcategorías (al menos una; campo para añadir) → ¿opciones avanzadas? → necesidad de cada subcategoría
   → revisar.
9. Dentro de una existente: ¿en cuál? → subcategorías (sin repetir las que ya tiene) → ¿opciones avanzadas? →
   necesidad → revisar. Las nuevas heredan el color y el ícono de la categoría, como el formulario.
10. Solo categorías de **gasto** (hoy el formulario tampoco crea categorías de ingreso). «Usar al registrar» no se
    pregunta: nace visible, como propone el inventario.
11. «Ver tus categorías» abre Ajustes › Categorías en una hoja encima del chat.

**Favorito:**

12. Preguntas: gasto, ingreso o transferencia → subcategoría (siempre a nivel de subcategoría; no en transferencia) →
    cuenta (y en transferencia, a qué cuenta, sin ofrecer la de origen) → monto o «cambia cada vez» → nombre (con la
    subcategoría como idea) → ¿opciones avanzadas? → necesidad (solo gasto), etiquetas (si tienes; no en
    transferencia) y nota → revisar.
13. La subcategoría es obligatoria en gasto e ingreso: un favorito sin categoría deja registros por clasificar.
14. Con una sola cuenta no se pregunta la cuenta (salvo en transferencia).
15. Se guarda por `FavoriteEditorViewModel.saveFavorite`, el mismo del editor. «Ver tus favoritos» abre la lista de
    Ajustes en una hoja.

**Para los tres:**

16. Solo pregunta lo que falta; lo dicho en la frase sale «Lo dijiste tú»; nada se crea sin «Revisa antes de crear»;
    tarjeta de éxito con «Ver…». Se entiende en el teléfono (sin red, sin cuota): iCloud y nube igual.
17. La frase tiene que **pedir** crear (verbo + la cosa, juntos: «crea una cuenta», «nueva categoría», «agrega un
    favorito»). «Agrega 20 soles a la cuenta BCP» sigue siendo un registro.
18. Los atajos del saludo de Yala IA **no** cambian (no estaba pedido; el saludo no está entre los ficheros del
    encargo).
