---
id: siri-ai-content-in-spotlight-and-pro-decision
status: qa
priority: medium
area: "siri, platform, privacy"
created: 2026-10-18
updated: 2026-10-28
source: "docs/siri-ios-27-2026-10.md (card «Integrar Yala con el nuevo Siri con IA de iOS 27»)"
---

# Siri con IA: ¿tus datos en Spotlight y «esta cuenta»? ¿Las preguntas a Siri, gratis o Pro?

Dos decisiones de Jürgen que dejó abiertas la integración con el Siri de iOS 27 (opción B ya entregada en 2.2, ver
`docs/siri-ios-27-2026-10.md`).

## 1 · ¿Se hace la opción C, y hasta dónde?

Lo que añadiría a lo que ya hay:

- **Cuentas y movimientos en el índice de Spotlight**: Siri los encuentra por significado («lo que pagué en el cine») y
  salen en las búsquedas del iPhone.
- **«Esta cuenta» / «este gasto» con la pantalla abierta** (anotar vistas con su entidad).
- **«Busca Starbucks en Yala»** con el esquema de búsqueda en la app.
- **Aprender lo que repites** (donaciones de interacciones).

Privacidad: nombres de comercios, notas e importes pasan al índice del sistema; salen en Spotlight a quien tenga el
iPhone desbloqueado y Apple Intelligence puede leerlos. Coste: mantener el índice con cada alta, cambio, borrado y
sync, y vaciarlo al cerrar sesión o vaciar datos.

Opciones: **A.** No hacer C. **B.** Solo cuentas (sin importes) en Spotlight y «esta cuenta» en pantalla.
**C.** Todo, movimientos incluidos. **Recomiendo B**: da a Siri lo que más se pregunta (las cuentas) sin poner importes
ni comercios en las búsquedas del iPhone.

## 2 · ¿Las preguntas a Siri son gratis o Pro?

Hoy «¿Cuánto gasté?» y «¿Cuánto tengo?» son **gratis**, como los widgets que ya enseñan esos números (decidido por la
sesión, reversible en una línea). «Anotar con Siri» sigue siendo Pro.

Opciones: **A.** Gratis (como está). **B.** Pro. **Recomiendo A**: son los mismos números del widget, y cobrar por oírlos
y no por verlos sería raro.

## Decidido e implementado (2026-10-28, encargo S20)

Jürgen (2026-10-18): **C** en Spotlight, con movimientos, y las preguntas a Siri **gratis** (sin cambio de código).

Qué entra: las tarjetas de cuenta del Panel (nombre y divisas, sin saldo) y los movimientos que Registros enseña sin
filtros (importe, categoría, cuenta y fecha). No entran los de cuentas excluidas de estadísticas, los de grupos con el
ajuste de Registros apagado, ingresos en «Solo gastos», transferencias ni ajustes de saldo. Con la vista de solo grupos
el índice se vacía. Se vacía también al cerrar sesión o vaciar datos. Tocar un resultado abre la ficha o el registro.
Visto en el simulador: «Plomero» sale en Buscar y abre su detalle; «Ahorros USD» abre su ficha; tras «Empezar de cero»
ya no sale nada.

Queda fuera (no lo pedía el encargo): «esta cuenta» con la pantalla abierta, «Busca … en Yala» y donaciones.

## Guion de QA en el iPhone

1. Abre Yala en tu iPhone con tus datos y espera unos segundos.
2. Sal a la pantalla de inicio, desliza hacia abajo y busca el nombre de un comercio o nota de un gasto reciente.
   Debe salir con el icono de Yala, importe, categoría, cuenta y fecha. Tócalo: abre ese registro.
3. Busca el nombre de una cuenta: sale como «Cuenta · PEN». Tócala: abre su ficha en el Panel.
4. Pregúntale a Siri «¿cuánto tengo en mi <cuenta>?»: debe reconocer la cuenta.
5. Activa «Requerir Face ID» en el icono de Yala (mantén pulsado el icono) y repite el paso 2: no debe salir nada de Yala.
6. En una cuenta excluida de las estadísticas, busca uno de sus gastos: no debe salir.
