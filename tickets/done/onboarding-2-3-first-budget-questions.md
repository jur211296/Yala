---
id: onboarding-2-3-first-budget-questions
status: done
priority: high
area: onboarding
created: 2026-11-12
updated: 2026-11-12
source: tablero-bienvenida-2-3-paso-3-primer-presupuesto-4l1q (docs/onboarding-2-3/SPEC.md, Y23-11)
qa-status: passed
qa-date: 2026-11-12
qa-notes: simulador iPhone 17 Pro iOS 27.2 - página corta, ¿Qué gastos cuenta?, ¿Cuáles? con «Llevas», ¿Algo que no quieras contar? (todas marcadas), período, tope, nombre propuesto, avisos 75/100, ¿En tu Panel?, ¡Listo!, guía de Más y mazo en el paso 4, recorridos por XCUITest con capturas; lo que se guarda, por test unitario
---
# Bienvenida 2.3 · Paso 3 · Primer presupuesto (Y23-11)

«Crea tu primer presupuesto» del mazo abre la página corta (tres partes cada 3,4 s, quietas con Reducir movimiento o
VoiceOver: «Un tope para lo que gastas» con la tarjeta «Tu tope de este mes», «Tú eliges qué cuenta» con las categorías de
la persona marcándose, «Yala te avisa a tiempo» con un aviso de ejemplo y «Si te pasas, lo ves en rojo»), con «Crear mi
presupuesto» y «Omitir este paso» a la vista.

Después, preguntas con la tarjeta del presupuesto llenándose arriba: ¿Qué gastos cuenta? (Todos mis gastos / Solo algunas
categorías) → ¿Cuáles? (todas las categorías de gasto en rejilla de 3, con «Llevas S/ X» si tienen gasto este mes) →
¿Algo que no quieras contar? (subcategorías en círculos de 4, todas marcadas) → ¿Cada cuánto se renueva? (Mensual,
Semanal, Anual, Una sola vez con fechas) → tope → nombre propuesto («Mis gastos del mes», la categoría o «A y B») →
avisos (75 % y 100 % destacado, solo 100 %, No) → ¿Lo ponemos en tu Panel? → ¡Listo! con «Ver mi Panel».

Se guarda con el ViewModel del editor (`BudgetEditorViewModel.saveBudget`): subcategorías marcadas (`subcategoryIDs`),
período, fechas, umbrales y, si dijo que sí al Panel, «Mostrar en el widget» y la sección Planificación con solo el
widget de Presupuestos. Elegir aviso pide el permiso de iOS si nunca se pidió (Y23-17) y enciende las alertas de
presupuesto si queda permitido. Al cerrar: el paso queda hecho, guía «Tus presupuestos viven en Más» → Más con foco en
Presupuestos, y el mazo en el paso 4. «Omitir este paso» lo deja omitido.

Fuera de alcance (ficha): cuentas, etiquetas, necesidad, gastos de grupo, 50 %/90 % y personalizar (siguen en Editar
presupuesto) y sugerir el monto.

Pruebas: `YalaTests/Bienvenida23PasosPlanificacionTests`, `YalaTests/Bienvenida23PasosPlanificacionGuardadoTests` y
`YalaUITests/Flows/Bienvenida23PlanificacionUITests#test_step3_budgetByCategories_withAlerts_inPanel_thenDeckMovesToStep4`.
