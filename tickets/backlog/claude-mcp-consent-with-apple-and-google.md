---
id: claude-mcp-consent-with-apple-and-google
status: backlog
priority: medium
area: cloud
created: 2026-09-26
updated: 2026-09-26
source: encargo 2026-09-26-plugin-claude-mcp-fase0-spike (residual, fase 1)
---

# Conectar Claude iniciando sesión con Apple o Google

## Qué cambia para el usuario

Al conectar Yala en Claude, la pantalla de permiso le pide iniciar sesión con la misma cuenta que usa en la app:
Apple o Google. Hoy (fase 0, staging) solo acepta email y contraseña, que es lo que tienen las cuentas de prueba.

## Qué hace falta

- **Acceso de Jürgen:** un Services ID de Sign in with Apple con el dominio del conector, y un cliente OAuth web
  de Google en el proyecto `yala-502622`. Los IDs que existen son de iOS (inferido; verificarlo en los dos
  dashboards).
- Activar esos proveedores para web en Supabase Auth, con la URL de vuelta del Worker.
- En `mcp/src/consent.ts`, sustituir el formulario de contraseña por los dos botones. La sesión web sigue
  cerrándose al decidir, como hoy.
- Probarlo con una cuenta real de nube en staging.
