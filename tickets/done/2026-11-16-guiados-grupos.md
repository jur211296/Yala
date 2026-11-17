---
id: 2026-11-16-guiados-grupos
status: done
priority: high
area: ai
created: 2026-11-17
updated: 2026-11-17
source: encargo 2026-11-17-guiados-grupos (Jürgen, sesión nocturna)
---
# Crear un grupo, anotar una deuda de antes y repartir un gasto de grupo conversando con Yala IA

Con el mismo motor de los guiados (presupuesto, pago planificado, cuenta, categoría y favorito), tres flujos nuevos de
Grupos desde el chat. Las preguntas salen de `docs/exploracion/formularios-guiados/inventario.md`. Los formularios de
Grupos no cambian: el guiado guarda por las mismas piezas que ellos.

## Paso 0 — decisiones (resueltas en autónomo, sesión nocturna; ninguna vital)

**Base.** El PR de presupuesto y pagos ya estaba mergeado. Los de «subcategorías, opciones avanzadas…» y «cuenta,
categoría y favorito» seguían abiertos, con el CI verde y en cola de auto-merge; el segundo contiene al primero. Esta
rama parte de su cabeza (no se duplica nada) y se rebasa sobre `2.3` antes de abrir el PR.

**Crear un grupo** (guarda por `GroupBackendMembershipService.createGroup`, el mismo camino que «Nuevo grupo»):

1. Preguntas: ¿para qué es? (viaje, casa, pareja, amigos u otro: pone el ícono y el color) → nombre (con un ejemplo
   según lo anterior) → ¿cómo te llamas? (solo si Yala no sabe tu nombre) → ¿cómo llevamos las monedas? (cada gasto en
   su moneda o todo en una) → ¿en qué moneda? (solo con «todo en una») → ¿cómo suelen dividir? → ¿opciones avanzadas? →
   ¿juntamos las deudas para que haya menos pagos? → revisar.
2. **Miembros: se invitan con el enlace al terminar.** En Yala nadie entra a un grupo por su nombre: cada persona se une
   con la invitación. La tarjeta de éxito abre la hoja «Invitar» de siempre (la del inventario: «Éxito = la hoja Invitar
   de hoy») y lleva «Ver el grupo». No se inventan miembros.
3. Con una sola moneda en Yala no se pregunta cómo llevar las monedas: queda «cada gasto en su moneda», como el
   formulario por defecto.
4. Crear un grupo necesita la cuenta de Yala y el permiso de Grupos (`GroupCreateRoutingLogic`). Sin ellos, Yala IA lo
   dice en una frase y no abre la tarjeta; con el canal apagado, el texto que ya usa Grupos. Es lo único de los tres
   flujos que necesita red: sin ella sale el error de siempre y la tarjeta se queda en «Revisa antes de crear».

**Anotar una deuda de antes** (guarda por `GroupExpenseService.setOpeningBalance`, el mismo del formulario):

5. Solo en grupos donde puedes anotarla: activos, que admiten cambios, con dos personas o más y donde eres dueño o
   administrador (`OpeningBalancePermissionLogic`). Sin ninguno, Yala IA lo dice. Con uno solo, no se pregunta el grupo.
6. Preguntas: grupo → ¿quién debía dinero antes de usar Yala? → ¿a quién? (en un grupo de dos, es la otra persona) →
   ¿cuánto? → ¿opciones avanzadas? → ¿desde cuándo? (solo fechas pasadas; por defecto, hoy) → revisar con la frase
   «Luis le debe S/ 120 a Ana».
7. La moneda es la del grupo y se cambia en la confirmación. Si esas dos personas ya tenían una deuda de antes en esa
   moneda, la confirmación lo avisa («Reemplaza la que ya tenían») en vez del diálogo del formulario: es el mismo
   reemplazo.

**Repartir un gasto de grupo** (guarda por `GroupExpenseViewModel.save`, el mismo del formulario, con su puente):

8. Se abre con «gasto de grupo», «en el grupo X», «divide / reparte … entre» con una cifra, **o con una cifra y el
   nombre de alguien de tus grupos** («pagué 120 de la cena con Ana y Luis»). Sin un nombre de tus grupos, «pagué 120 de
   la cena» sigue siendo un registro personal.
9. Preguntas: grupo (se deduce por su nombre o por las personas nombradas) → ¿qué fue? → ¿cuánto? → **¿Quién pagó?** →
   **¿Cómo lo dividen?** (en partes iguales entre todos, en partes iguales solo entre algunos, o un monto para cada
   uno, que tiene que cuadrar) → ¿con qué cuenta pagaste? (solo si pagaste tú y el gasto se refleja en tus cuentas, como
   el formulario) → ¿opciones avanzadas? (categoría y fecha) → revisar.
10. «Pagué» marca que pagaste tú; «con Ana y Luis» deja el reparto en partes iguales entre tú, Ana y Luis. La moneda es
    la del grupo y se cambia en la confirmación.
11. Porcentajes y partes quedan en el formulario: en el chat no caben en una pregunta.
12. Solo en los grupos donde puedes anotar un gasto (`GroupService.eligibleGroupsForExpense`).

**Para los tres:**

13. Solo pregunta lo que falta; lo dicho en la frase sale «Lo dijiste tú»; nada se guarda sin «Revisa antes de
    crear»; tarjeta de éxito con «Ver el grupo».
14. **Propuesta, no hecha:** el mismo mini guiado «¿Quién pagó?» → «¿Cómo lo dividen?» podría abrir el reparto dentro del
    formulario de gasto de grupo. No se tocó el formulario.
