---
id: invite-join-button-covers-paste-with-a-long-link
status: qa
priority: low
area: "groups, welcome"
created: 2026-11-05
updated: 2026-11-06
source: "QA en el iPhone de pruebas del 2026-11-05 (montaje A, L12-16)"
---

# Con un enlace largo y el teclado abierto, «Unirme al grupo» tapa el botón «Pegar»

En «Pega tu enlace de invitación», con el enlace en el campo (4 líneas) y el teclado abierto, el botón fijo «Unirme al
grupo» sube con el teclado y tapa la mitad de «Pegar». Con el campo vacío no se tocan. iPhone 14 (390 pt), iOS 27.2.
Captura de las 18:06 en la sesión (`A2-iphone-*` de `~/Claude/entregas/2026-11-05-qa-dispositivo-fisico-device-mcp/evidencia`).

## Hecho (2026-11-06, lote UI 2.3)

«Unirme al grupo» deja de flotar encima del contenido: va en el borde inferior del scroll (`safeAreaInset`), y al
escribir o enfocar el campo el scroll lleva «Pegar» a la vista. Medido en el simulador (iPhone 17 Pro) con un enlace de
cinco líneas y el teclado abierto: con la vista de 2.3 el botón quedaba encima de «Pegar»; ahora «Pegar» queda entero
por encima. Test: `InviteRecoveryPasteVisibleUITests` (rojo con la vista de antes).
Evidencia: `~/Claude/entregas/2026-11-06-lote-bugs-ui-idioma-ipad-grupos/evidencia/antes-2.png` · `~/Claude/entregas/2026-11-06-lote-bugs-ui-idioma-ipad-grupos/evidencia/despues-2.png`.

**Guion de QA (iPhone 14):** Welcome › «Me invitaron a un grupo» › «Unirme con un enlace»; pega un enlace largo (que
ocupe 4 líneas) y deja el teclado abierto: «Pegar» se ve entero por encima de «Unirme al grupo».
