---
description: Verificación rápida de sintaxis Swift en archivos modificados (sin build completo)
allowed-tools: Bash(git:*), Bash(swiftc:*), Bash(xcrun:*), Read
---

Verificación rápida de sintaxis en archivos .swift modificados. NO compila el proyecto completo.

PASOS:

1. IDENTIFICAR ARCHIVOS MODIFICADOS:
```bash
MODIFIED_SWIFT=$(comm -23 \
  <(sort -u <(git diff --name-only HEAD 2>/dev/null; git diff --name-only 2>/dev/null; git diff --name-only --cached 2>/dev/null)) \
  <(echo "") | grep '\.swift$')
```

2. PARA CADA ARCHIVO, verificar sintaxis básica:
   - Leer el archivo con Read
   - Buscar errores obvios:
     * Llaves/paréntesis desbalanceados
     * `func` sin body
     * `if`/`guard` sin body
     * Imports duplicados
     * Trailing commas en último parámetro
   - NO intentar compilar con swiftc (no resuelve dependencias del proyecto)

3. REPORTAR:
```
## Quick Check — [N] archivos

[✓ Sintaxis OK | ✗ Errores encontrados]
[Lista de errores si hay]

Nota: esto NO reemplaza /verify-ios. Solo detecta errores de sintaxis evidentes.
```

CUÁNDO USAR:
- Cambios muy pequeños donde no quieres esperar un build completo
- Verificación rápida antes de hacer más cambios
- SIEMPRE ejecutar /verify-ios antes de commitear
