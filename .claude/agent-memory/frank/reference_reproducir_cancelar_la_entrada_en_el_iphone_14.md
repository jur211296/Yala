---
name: reproducir-cancelar-la-entrada-en-el-iphone-14
description: Cómo cancelar a tiempo «Cancelar la activación» en el iPhone 14 con Device MCP y medir qué quedó; -uitest-reset no borra la sesión del llavero
metadata:
  type: reference
---

Medido el 2026-11-16 (lote de bugs del barrido final de 2.3, card xhbn), iPhone 14 con Yala Dev:

- **El botón «Cancelar la activación» solo está activo ~2 s** (sale desactivado al 22 % y la entrada termina al 61-100 %):
  a mano por capturas llega tarde y la cuenta entra. Lo que funciona: un `batch_commands` con «Cargar mis datos y entrar»,
  `wait 1.5` y 8 toques en (195, 621) separados 0,3 s; el diálogo sale y «Sí, cancelar» va en (195, 488).
- **El daño sale al REABRIR**, no a los segundos: tras cancelar, el almacén estaba vacío a los 23 s y con «Grupos PEN» y
  2 grupos tras reabrir. Medir: `devicectl … copy from --domain-type appGroupDataContainer` + sqlite3
  ([[reference-contar-el-store-del-iphone-con-devicectl]]).
- **`-uitest -uitest-reset` borra datos pero NO la sesión de la nube** (vive en el llavero): la bienvenida se queda con una
  sesión viva y Grupos baja al pasar a primer plano. Para un teléfono limpio, entra en la cuenta y Ajustes › Cerrar sesión.
- Una cuenta de prueba puede ser hoy SOLO de grupos en el servidor (test@ el 16-nov): que entre por la puerta principal a
  «Grupos en tu cuenta de Yala» es la ruta correcta (`trigger=account-entry-groups-only`), no el bug.

Ver [[conducir-el-iphone-real-con-device-mcp]].
