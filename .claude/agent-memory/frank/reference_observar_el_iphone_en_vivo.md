---
name: reference-observar-el-iphone-en-vivo
description: Cómo observar el iPhone 14 mientras Jürgen lo usa, sin tocarlo — vigía por árbol de accesibilidad, capturas al cambiar, telemetría por la Mini y store por devicectl
metadata:
  type: reference
---

Para una sesión de «mira lo que hago en el iPhone» (25-nov-2026, primera vez):

- **Espejo:** si `list_devices` dice «Another app is mirroring», lo tiene la Mini (Device MCP/DeviceHub). `reconnect_device` lo trae a la Max sin tocar el teléfono.
- **Vigía:** `device-mcp-cli elements --device <UDID> --json` cada 2 s (~1,3 s por lectura) y `screenshot` solo cuando cambia la firma del árbol, más una cada 30 s. La firma debe ignorar el carrusel de la Bienvenida (`welcome_showcase*`) o dispara cada segundo. Un Monitor sobre el `timeline.jsonl`, deduplicando por las primeras etiquetas, despierta la sesión en cada pantalla nueva.
- **Log del sistema: no hay.** `log collect --device-udid` pide root y `devicectl … --console` relanza la app. Declarar el hueco.
- **Telemetría:** el token de Analytics Engine vive solo en la Mini (`~/Secrets/yala-cloudflare/analytics-read.token`): consultar por `ssh mini`.
- **Datos:** el store de Yala Dev se copia en solo lectura con devicectl desde el App Group ([[reference-contar-el-store-del-iphone-con-devicectl]]); sirvió para medir que una cuenta de dos monedas son dos filas.
- **Horas:** sacar «actualizado» y las marcas del reloj (`TZ=America/Lima date`), nunca a ojo: en esta sesión las escribí adelantadas y hubo que corregir.

**Why:** Jürgen reporta en vivo y quiere respuesta con evidencia en minutos; sin vigía, las capturas a mano llegan tarde.
**How to apply:** encargo de observación del iPhone: montar vigía + Monitor en los primeros 5 min y avisarle «listo» antes de que empiece. Si pide probar un gesto, Device MCP tiene su permiso; captura justo después del toque para separarlo del avance automático.
