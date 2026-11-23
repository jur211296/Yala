---
id: private-sign-out-wait-uitest-times-out-on-2-3
status: backlog
priority: medium
area: "cierre de sesión, XCUITest"
owner: frank
created: 2026-11-10
deadline: 2026-11-17
updated: 2026-11-10
source: "gate del lote 10 de las mejoras necesarias 2.3 (Ajustes y Pro: textos), 2026-11-10, Max"
---

# En 2.3, el test de la espera al cerrar sesión sin cuenta se queda sin respuesta de la app

## El problema, en lenguaje de usuario

Al cerrar sesión con iCloud privado y sin cuenta de Yala, mientras Yala espera a subir los cambios, debería salir la
tarjeta «Subiendo tus cambios a iCloud» y, a los 45 s, el aviso con «Exportar mis registros · Esperar · Quitar mis
datos igualmente». El XCUITest que lo comprueba ya no llega a verlo en 2.3: la app deja de contestar a las consultas
de accesibilidad justo después de confirmar la salida. No sabemos todavía si la persona ve la pantalla colgada o si
solo se cuelga la accesibilidad.

## Lo medido (2026-11-10, Max, iPhone 17 Pro, iOS 27.2, scheme `Yala Dev`)

- `UXAudit22Lote04UITests/test_privateSignOut_waitShowsTheUploadCard_andTheNoticeOffersExportFirst` cae en la
  línea 75 (`card.waitForExistence(timeout: 15)`) con `Failed to get matching snapshots: Timed out while evaluating UI
  query`, a los ~137-142 s. No es una aserción sobre el contenido: la consulta no obtiene respuesta.
- **4 de 4 corridas en rojo**: una dentro del subconjunto del gate (centinela en 0, solo en el simulador) y tres a solas.
- **Preexistente en 2.3**: una de las tres corridas a solas fue sobre `origin/2.3` (`ae4627207`) sin las dos vistas
  del lote 10. Cae igual, en la misma línea. Del lote 10 solo quedaba el cambio de un texto de la prueba de Pro, que
  no sale en esta pantalla.
- En 2.2 estaba en verde el 2026-10-24 (barrido de QA de 2.2, cards `dxow` y `wtme`).

## Qué mirar primero

1. El vídeo del `.xcresult` (último fotograma con `ffmpeg`): ¿la pantalla está colgada o solo la accesibilidad?
2. Si está colgada, `sample` del proceso durante la espera (molde: memoria `reference_medir_un_cuelgue_de_tipos_con_sample`).
3. Correrlo en `origin/2.2` el mismo día, para saber si es de 2.3 o de los dos.

## Criterio de terminado

El caso vuelve a verde en 2.3 con la causa nombrada en el commit, o se separa el cuelgue real en su propio ticket si
lo hay.
