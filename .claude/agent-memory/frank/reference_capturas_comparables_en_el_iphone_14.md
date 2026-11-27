---
name: capturas-comparables-en-el-iphone-14
description: Cómo sacar capturas antes/después del iPhone 14 que paren en el mismo sitio (deeplink de pruebas + scroll por distancia); lo que no funciona.
metadata:
  type: reference
---

Para comparar al píxel dos builds en el iPhone 14 (26-nov, lote 5 de eficiencia):

- Abrir con `devicectl device process launch --terminate-existing <bundle> -- -uitest -uitest-skip-onboarding …`: los
  argumentos van **detrás de `--`**; sin él, devicectl toma `-uitest` como opción suya y no lanza.
- La pantalla, por `-uitest-deeplink records|panel|planning…`, no tocando la barra.
- Bajar con `device-mcp-cli scroll down --distance N` (sin inercia). `swipe --no-momentum` a veces no entra o arrastra de
  más, y `tap --text Registros` tocó el chip «Registros» de un widget y abrió su hoja.
- Esperar ~30 s tras abrir con 16 k movimientos; con 18 s el primer gesto se perdía.
- `screenshot -o` no sobrescribe: borra antes. `device-mcp-cli apps launch` relanza SIN los argumentos de prueba.
- Aun así el scroll no para siempre en la misma fila: compara al píxel lo que paró igual y a ojo lo demás.

Guion: `docs/qa/rendimiento-iphone14-2026-11-26/despues-eficiencia-5-render-del-scroll/scripts/capturas.sh`.
Relacionado: [[conducir-el-iphone-real-con-device-mcp]].
