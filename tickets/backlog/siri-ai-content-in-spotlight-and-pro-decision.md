---
id: siri-ai-content-in-spotlight-and-pro-decision
status: backlog
priority: medium
area: "siri, platform, privacy"
created: 2026-10-18
updated: 2026-10-18
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
