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

   Ejecutaré TODO sin pausas. Al terminar tendrás:
   - Todos los cambios implementados
   - Build verificado
   - Tests ejecutados
   - Análisis de impacto
   - Lista de puntos para validación manual

   ¿Confirmas ejecución autónoma? (sí/no)
   ```

2. **EJECUTAR CICLO COMPLETO POR INCREMENTO**

   Para cada incremento, SIN PAUSAS:
   ```
   [Incremento N]
   → Implementar código
   → /verify-ios (si falla, intentar fix automático hasta 2 veces)
   → /test-smart (si falla, intentar fix automático hasta 2 veces)
   → Commit automático con mensaje descriptivo
   → Siguiente incremento
   ```

3. **AL TERMINAR TODOS LOS INCREMENTOS**

   Ejecutar automáticamente:
   - `/pre-deploy-check` completo
   - Análisis de impacto de todos los cambios
   - Generar reporte de validación

4. **PRESENTAR REPORTE FINAL**
   ```
   ╔═══════════════════════════════════════════════════════════════╗
   ║                    EJECUCIÓN YOLO COMPLETADA                  ║
   ╠═══════════════════════════════════════════════════════════════╣
   ║                                                               ║
   ║  INCREMENTOS: [N] completados                                 ║
   ║                                                               ║
   ║  COMMITS REALIZADOS:                                          ║
   ║  - [hash1] [mensaje1]                                         ║
   ║  - [hash2] [mensaje2]                                         ║
   ║  ...                                                          ║
   ║                                                               ║
   ║  BUILD: ✓ Pasó                                                ║
   ║  TESTS: ✓ [N] tests, todos pasaron                            ║
   ║                                                               ║
   ║  PRE-DEPLOY CHECK:                                            ║
   ║  - [✓/✗] Manejo de errores                                    ║
   ║  - [✓/✗] Force unwraps                                        ║
   ║  - [✓/✗] Prints producción                                    ║
   ║                                                               ║
   ╠═══════════════════════════════════════════════════════════════╣
   ║  VALIDACIÓN MANUAL PENDIENTE                                  ║
   ╠═══════════════════════════════════════════════════════════════╣
   ║                                                               ║
   ║  Por favor valida en el simulador:                            ║
   ║                                                               ║
   ║  1. [ ] [Escenario de prueba 1]                               ║
   ║  2. [ ] [Escenario de prueba 2]                               ║
   ║  3. [ ] [Escenario de prueba 3]                               ║
   ║                                                               ║
   ║  Archivos clave modificados:                                  ║
   ║  - path/to/file1.swift (líneas X-Y)                           ║
   ║  - path/to/file2.swift (líneas A-B)                           ║
   ║                                                               ║
   ╚═══════════════════════════════════════════════════════════════╝

   ¿Todo OK?
   - Sí → Listo, puedes hacer push
   - No → Dime qué ajustar
   ```

### SI NO HAY PLAN (ejecución directa):

Preguntar:
```
No detecto un plan previo.

Opciones:
1. Describe qué quieres implementar y creo el plan + ejecuto todo
2. Usa /next primero para elegir tarea y planificar
```

Si el usuario describe la tarea:
- Generar plan internamente
- Mostrar plan resumido
- Pedir confirmación
- Ejecutar todo

## MANEJO DE ERRORES

**Si el build falla:**
- Intentar fix automático (máximo 2 intentos)
- Si persiste: PAUSAR y reportar el error
- No continuar con incrementos rotos

**Si los tests fallan:**
- Intentar fix automático (máximo 2 intentos)
- Si persiste: PAUSAR y reportar
- Documentar qué tests fallaron

**Si hay error crítico:**
- DETENER inmediatamente
- NO hacer más commits
- Reportar estado y qué se completó

## REGLAS

- NUNCA hacer push automático (solo commits locales)
- SIEMPRE verificar build antes de cada commit
- SIEMPRE ejecutar tests relevantes
- SIEMPRE generar lista de validación manual al final
- Si algo falla 2 veces, PARAR y preguntar
- Los commits deben ser atómicos y descriptivos
