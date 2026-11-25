---
name: simular-un-aviso-de-banco-con-un-recordatorio
description: Probar «Avisos del banco» en el iPhone 14 sin app de banco — un recordatorio con el texto del aviso dispara la automatización; trampas del teclado y de Yala/Yala Dev.
metadata:
  type: reference
---

El iPhone 14 de pruebas no tiene app de banco. Para el paso «una compra real» de «Avisos del banco» (24-nov-2026, lote de
bugs de la build 8) funcionó: automatización «Al recibir una notificación de **Recordatorios**» + la acción de Yala, y un
recordatorio con hora cuyo título es el aviso. Llegó a la Bandeja y el banco pasó a «Funcionando».

- **Título sin `/`, `é` ni `*`**: `type_text` de Device MCP los cambia con el teclado español (`/`→`-`, `é`→`€e`,
  `*`→`(`). El lector acepta `PEN 12.50`: «Realizaste un consumo de PEN 12.50 con tu Tarjeta BCP en TAMBO MIRAFLORES».
- **`set_clipboard` pide aprobación en Device MCP**: sin Jürgen delante caduca a los 2 min. No cuentes con él.
- **En Atajos, «Registrar movimiento desde texto» sale dos veces (Yala y Yala Dev) y son indistinguibles.** Entra por la
  app («Yala» en el buscador › toca la app) y busca la acción dentro. La primera vez fue a Yala Dev y no llegó nada a Yala.
- El comercio se queda con la línea de la hora del recordatorio («TAMBO MIRAFLORES hoy, 7:20 p»): es del recordatorio,
  no del lector.
- Recordatorios solo deja horas de 5 en 5 min; la notificación llega aunque haya un modo de concentración («Importante»).
- Limpiar después: la automatización se borra con pulsación larga y el atajo que crea queda aparte en «Todos los atajos».

Relacionado: [[conducir-el-iphone-real-con-device-mcp]].
