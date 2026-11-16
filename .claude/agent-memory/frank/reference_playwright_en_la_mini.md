---
name: playwright-en-la-mini
description: Capturas de Yala web en staging con los usuarios de prueba: Playwright corre en la Mini (allí viven las credenciales), pero su descarga de Chromium se atasca; copiar el de la Max.
metadata:
  type: reference
---

Medido el 2026-11-14 (lote 2 de Yala web, sesión en la Max). `npx playwright install chromium` en la Mini se quedó en
624 KB tras 18 min (y `npm install` tardó ~10 min). Lo que funcionó: `rsync -a ~/Library/Caches/ms-playwright/chromium_headless_shell-1243 mini:Library/Caches/ms-playwright/`
desde la Max y `npm install playwright@1.63.0` (la versión que casa con la build 1243) en `~/tmp/yala-web-lote2-shots`
de la Mini. El guion entra con `context.request.post('/auth/password', {form, headers:{Origin}})` usando
`USER_A_*` de `test-users.env`, sin sacar las credenciales de la Mini.

**How to apply:** para capturas o e2e de navegador contra staging, reutiliza esa carpeta de la Mini. A y B no tienen
movimientos con cuenta (Estadísticas sale en cero); para enseñar cifras, `page.route` con un ejemplo calculado por el
núcleo real, y dilo en la entrega. Relacionado: [[secretos-de-staging-en-la-mini]].
