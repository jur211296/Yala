---
description: Modo autónomo - implementa todos los incrementos sin esperar validaciones intermedias
argument-hint: "[objetivo o 'continuar' si ya hay plan]"
---

Ejecuta todos los incrementos de forma autónoma sin esperar validaciones intermedias.

## CONTEXTO DE USO

Útil cuando:
- Estás fuera y no puedes validar manualmente cada paso
- Confías en el plan y quieres que avance todo
- Prefieres revisar todo al final en lugar de paso a paso

## MODO DE OPERACIÓN

### SI HAY PLAN DEFINIDO (viene de /next o Plan Mode):

1. **CONFIRMAR ALCANCE**
   ```
   Modo YOLO activado.

   Plan detectado con [N] incrementos:
   1. [Incremento 1]
   2. [Incremento 2]
   ...

   Ejecutaré TODO sin pausas. ¿Confirmas? (sí/no)
   ```

2. **EJECUTAR CICLO COMPLETO POR INCREMENTO**

   Para cada incremento, SIN PAUSAS:
   ```
   [Incremento N]
   → Implementar código
   → /verify-ios (si falla, intentar fix automático hasta 2 veces)
   → /test-smart (si falla, intentar fix automático hasta 2 veces)
   → /commit-one (incluye: swift-audit + test gate + state update)
   → Siguiente incremento
   ```

   Nota: /commit-one ya incluye el test gate con generación de tests para fix:/feat:.
   El flag tests-passed se crea con /test-smart y se limpia después de cada commit.

3. **REPORTE FINAL**
   ```
   ## YOLO completado

   Incrementos: [N] completados
   Commits: [lista con hashes]
   Build: ✓/✗
   Tests: [N] tests, ✓/✗

   ### Validación manual pendiente
   1. [ ] [Escenario de prueba 1]
   2. [ ] [Escenario de prueba 2]

   ### Archivos clave modificados
   - path/to/file1.swift
   - path/to/file2.swift

   ¿Todo OK? Sí → listo para push | No → dime qué ajustar
   ```

### SI NO HAY PLAN:

Preguntar:
```
No detecto un plan previo.

1. Describe qué quieres y creo el plan + ejecuto todo
2. Usa /next primero para elegir tarea y planificar
```

## MANEJO DE ERRORES

**Si el build falla:**
- Intentar fix automático (máximo 2 intentos)
- Si persiste: PAUSAR y reportar el error

**Si los tests fallan:**
- Intentar fix automático (máximo 2 intentos)
- Si persiste: PAUSAR y reportar

**Si hay error crítico:**
- DETENER inmediatamente
- NO hacer más commits
- Reportar estado y qué se completó

## REGLAS
- NUNCA hacer push automático (solo commits locales)
- SIEMPRE verificar build antes de cada commit
- SIEMPRE ejecutar tests relevantes (via /test-smart o test gate en commit-one)
- SIEMPRE generar lista de validación manual al final
- Si algo falla 2 veces, PARAR y preguntar
- Los commits deben ser atómicos y descriptivos
