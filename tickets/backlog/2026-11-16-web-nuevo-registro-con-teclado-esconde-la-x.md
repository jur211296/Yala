---
id: 2026-11-16-web-nuevo-registro-con-teclado-esconde-la-x
status: backlog
priority: very-low
area: web
created: 2026-11-16
updated: 2026-11-16
source: hallazgo del lote 4 de «Yala web como la app» (Safari del iPhone 14, producción)
---
# Yala web: con el teclado abierto, la ✕ de «Nuevo registro» queda fuera de la vista

En Safari del iPhone, al abrir «Nuevo registro» el foco va al monto y sale el teclado: la hoja se desplaza y la ✕ y el
título quedan arriba, fuera de la pantalla. Al cerrar el teclado vuelven. Se puede cerrar igual (cerrar el teclado y la
✕, o tocar fuera), pero no a la vista. Probable arreglo: la hoja con `max-height` sobre el viewport visual
(`100svh`/`visualViewport`) o la cabecera fija dentro de la hoja.
