---
description: Ejecuta una verificación rápida del proyecto sin compilación completa.
---

Ejecuta una verificación rápida del proyecto sin compilación completa.

PASOS OBLIGATORIOS:
1. Navega al directorio raíz del proyecto
2. Ejecuta: swift build --dry-run 2>&1 | grep -E "(error|warning)"
3. Si hay errores de sintaxis, identifícalos y propón fix mínimo
4. Si no hay errores, confirma "Quick check passed"

REGLAS:
- Este comando NO reemplaza /verify-ios, solo detecta errores obvios antes de compilar
- Úsalo para cambios pequeños donde solo quieres validar sintaxis
- Si pasa este check, aún debes ejecutar /verify-ios antes de commitear
