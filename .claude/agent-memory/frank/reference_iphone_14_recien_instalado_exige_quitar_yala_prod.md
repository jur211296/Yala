---
name: iphone-14-recien-instalado-exige-quitar-yala-prod
description: Desinstalar Yala Dev no la deja recién instalada si Yala (prod) sigue en el iPhone: comparten App Group y el store sobrevive.
metadata:
  type: reference
---

Medido el 2026-11-13 en el iPhone 14 con logs de consola (`fileExists=true` tras `devicectl uninstall`): `Yala-Release.entitlements`
declara también `group.com.jurgenschmidt.yala.dev`, así que con Yala de producción instalada el App Group de Yala Dev no se borra
y su store personal sobrevive a la desinstalación.

**Cómo aplicar:** para probar algo «desde cero» (bienvenida, entrada con Google, montaje neutro) en el iPhone 14, desinstala
Yala Dev **y** Yala, y reinstala solo Yala Dev. Jürgen lo aprobó ese día. Si no, el arranque monta con el espejo de iCloud
(`iCloudMirror`/`localNoMirror`), la entrada pide «reabre Yala» y, tras reabrir, el import tardío sin linaje frena el motor:
artefactos que parecen bugs. Reinstalar Yala Dev vuelve a encender su interruptor de iCloud en Ajustes.
Ver [[conducir-el-iphone-real-con-device-mcp]].
