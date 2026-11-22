---
id: 2026-11-21-ia-ampliada-produccion-navegadores-publicada
status: qa
priority: high
area: ai
created: 2026-11-22
updated: 2026-11-22
source: encargo 2026-11-22-ia-ampliada-produccion-navegadores-publicada (OK de producción de Jürgen, 21-nov 08:39; decisiones 14, 42, 51 y 64 de la auditoría del 21-nov)
qa-status: needs-testing
qa-date: 2026-11-22
qa-notes: IA ampliada medida en staging y encendida en producción por escalones; navegadores conectados con test unitario; falta el despliegue del conector (Dan) y ver la fila en la 2.3 publicada
---
# Yala IA ampliada en producción, conector en mcp.yala-app.pe y navegadores conectados en la app publicada

Tres decisiones de la auditoría del 21-nov que esperaban a la 2.2 publicada o a un dominio:

- **14** — Yala IA ampliada (la IA lee lo que necesita de tu cuenta de Yala para contestar): encenderla en producción.
- **64** — El conector MCP sale a producción en `mcp.yala-app.pe`; el de pruebas pasa a otro nombre; despliega Dan.
- **42 y 51** — Yala web es un dispositivo más en modo nube: «Navegadores conectados» deja de ser solo de Yala Dev.

Las decisiones del encargo (Paso 0) están en `encargos/lanzados/2026-11-22-ia-ampliada-produccion-navegadores-publicada.md`.

## Qué cambia para quien usa Yala

- **Con los datos en tu cuenta de Yala**, Yala IA ya puede leer lo que necesita para contestar (movimientos, cuentas,
  categorías) en vez de quedarse con el resumen. Pasa al aceptar el aviso de Yala IA ampliada, como en 2.2. No hace
  falta actualizar la app: lo enciende el servidor.
- **Desde la 2.3**, Ajustes › Tu cuenta de Yala › «Navegadores conectados» aparece en la app de la App Store: ver y
  cerrar las sesiones de `app.yala-app.pe` y vincular un navegador con su código o su QR.
- **El conector para tu IA** tendrá su dirección de producción, `https://mcp.yala-app.pe/mcp`, cuando Dan lo despliegue.

## Hecho

1. **Marcha atrás probada en staging** antes de tocar producción: la variable a 0 se vio en `/config` en menos de 10 s
   y volvió a 100, sin tocar código ni secretos (34 bindings intactos).
2. **Medición real de `chat.explore` en staging** (usuario de prueba A, tres preguntas): 3/3 con 200, 3,4–6,2 s por
   pregunta, ~3.750 tokens de entrada (2.200 de caché) y ~60 de salida, ≈ 0,0002 USD por pregunta, 0 errores. Leyó
   las cuentas reales del usuario de prueba.
3. **Producción por escalones 1 → 10 → 50 → 100** cambiando solo la variable sobre la versión que corre (`86849564`),
   con `/config`, humo y errores del Worker entre cada escalón. Detalle y valores: el artifact del cierre y
   `gateway/RUNBOOK.md`, «Yala IA ampliada». `gateway/wrangler.toml` y `test/config.test.ts` dicen 100.
4. **Conector**: KV de producción creado, `mcp/wrangler.toml` de producción con `mcp.yala-app.pe`, `mcp.yala-app.pe`
   soltado del Worker de staging y el de pruebas en `mcp-staging.yala-app.pe`. Runbook al día.
5. **Navegadores conectados**: `ConnectedBrowsersConfig.baseURL` apunta a `app.yala-app.pe` fuera de Yala Dev.
   Test `YalaTests/NavegadoresConectadosProduccion/` contra `webapp/wrangler.toml` (dirección y Supabase de cada web).
6. **Face ID en la app de producción**: la clave `NSFaceIDUsageDescription` solo estaba en Debug-Dev y Release-Dev, y
   «Vincular un navegador» la pide (`LAContext`). Sin ella, iOS cierra la app al vincular. Se añadió a Debug y Release
   (las traducciones ya estaban en los 16 `InfoPlist.strings`); el test de arriba fija las cuatro configuraciones
   (mutante sin la clave en Debug: rojo). Medido en el `.app`: `NSFaceIDUsageDescription` presente.

## Falta (no es de esta sesión)

- **Dan: desplegar el conector** siguiendo `mcp/RUNBOOK-produccion.md` (pasos 1 y 3 a 10: cliente OAuth, rol y hook en
  Supabase producción, Auth, `deploy:production`, e2e). Este encargo no toca Supabase de producción.
- **Jürgen: probar «Navegadores conectados» con la 2.3** (TestFlight de producción, cuenta en la nube; la primera
  vez que se vincula, iOS pide permiso de Face ID con el texto nuevo):
  1. Ajustes › Tu cuenta de Yala › «Navegadores conectados»: la fila sale.
  2. En un ordenador, abrir `https://app.yala-app.pe`, pedir el código y en el iPhone «Vincular un navegador» →
     escribirlo o escanear el QR → Face ID. La web entra.
  3. De vuelta en «Navegadores conectados», el navegador sale en la lista; «Cerrar» lo saca de la web en menos de un
     minuto.
- **Medición de dos semanas de la IA ampliada** (hechaCuando de su card, decisión 3A): revisar la cuota y el coste
  de `chat.explore` en `yala_ai_usage` hacia el 2026-12-06.
