# Reglas de Ejecución de Comandos

Este documento define qué comandos Claude puede ejecutar automáticamente y cuáles requieren instrucción explícita del usuario.

## Comandos que REQUIEREN instrucción explícita del usuario

Estos comandos NUNCA deben ejecutarse automáticamente. Claude debe sugerir que el usuario los ejecute, pero esperar la instrucción explícita:

### Verificación y Testing
- `/verify-ios` - Requiere instrucción explícita
- `/verify-quick` - Requiere instrucción explícita  
- `/test-ios` - Requiere instrucción explícita
- `/test-smart` - Requiere instrucción explícita
- `/uitest-ios` - Requiere instrucción explícita

**Por qué:** El usuario debe decidir cuándo verificar. Puede querer revisar el código primero, o hacer múltiples cambios antes de compilar.

### Commits
- `/commit-one` - Requiere instrucción explícita
- `/commit-checkpoint` - Requiere instrucción explícita

**Por qué:** Commitear es una decisión consciente que el usuario debe controlar.

### Gestión de Sesión
- `/session-start` - Requiere instrucción explícita
- `/session-end` - Requiere instrucción explícita
- `/checkpoint` - Requiere instrucción explícita

**Por qué:** El usuario controla cuándo inicia/termina sesiones.

### Planning y Navegación
- `/gsd:next` - Requiere instrucción explícita
- `/gsd:resume` - Requiere instrucción explícita
- `/review-parking-lot` - Requiere instrucción explícita

**Por qué:** Decisiones de qué trabajar son del usuario.

## Comandos que pueden ejecutarse automáticamente

Estos comandos Claude puede ejecutar cuando sea necesario sin pedir permiso:

### Lectura de contexto (MÁXIMO UNA VEZ por operación)
- `git log` para ver historial - EJECUTAR UNA SOLA VEZ
- `git status` para ver estado actual - EJECUTAR UNA SOLA VEZ
- `git diff` para analizar cambios - EJECUTAR UNA SOLA VEZ
- `view` sobre archivos del proyecto
- Lectura de CLAUDE.md, PROJECT.md, ROADMAP.md, STATE.md, UI-PATTERNS.md

**Por qué:** Son operaciones de solo lectura que no modifican nada.

**CRÍTICO:** Cada comando git de lectura debe ejecutarse UNA SOLA VEZ y su output guardarse para reutilización. NUNCA ejecutar el mismo comando múltiples veces en la misma operación.

### Ejecución de código
- Crear/modificar archivos cuando el usuario pidió "implementa X"
- `bash_tool` para operaciones de archivo necesarias para la implementación

**Por qué:** Cuando el usuario dice "implementa X", está autorizando los cambios necesarios.

## Patrón de "Implementar y Detener"

Cuando el usuario dice "Implementa Incremento N":

1. Claude implementa los cambios necesarios (crear/modificar archivos)
2. Claude muestra resumen de cambios realizados
3. Claude sugiere: "Ejecuta /verify-ios para validar el build"
4. **Claude se DETIENE y espera instrucción**

NO:
- ❌ Ejecutar /verify-ios automáticamente
- ❌ Ejecutar git status múltiples veces
- ❌ Intentar commitear sin instrucción
- ❌ Continuar con siguiente incremento sin confirmación

## Optimización de comandos Git

Cuando el usuario ejecuta cualquier comando que necesita información de git:

**PATRÓN OBLIGATORIO:**
```bash
# AL INICIO del comando, ejecutar UNA SOLA VEZ:
GIT_STATUS=$(git status --porcelain 2>&1)
GIT_DIFF=$(git diff 2>&1)
GIT_DIFF_STAT=$(git diff --stat 2>&1)
GIT_DIFF_NAMES=$(git diff --name-only 2>&1)
GIT_LOG=$(git log --oneline -10 2>&1)

# GUARDAR estos outputs y REUTILIZARLOS para todo el análisis
# NUNCA volver a ejecutar estos comandos durante la operación
```

**PROHIBIDO:**
- ❌ Ejecutar git status múltiples veces en la misma operación
- ❌ Ejecutar git diff múltiples veces en la misma operación
- ❌ Crear múltiples shells en background
- ❌ Ejecutar comandos git en paralelo
- ❌ Lanzar comandos sin esperar que terminen

## Prevención de Corrupción de Git Index

**NUNCA:**
- Ejecutar múltiples comandos git write simultáneamente
- Matar shells que están ejecutando comandos git
- Ejecutar git commands en background sin esperar resultado
- Lanzar nuevos git commands antes de que terminen los anteriores

**SIEMPRE:**
- Esperar que cada comando git termine completamente
- Ejecutar comandos git de forma secuencial, no paralela
- Usar timeouts razonables (10-30 segundos)
- Verificar que no existe .git/index.lock antes de operaciones write

## Resumen de Reglas

**Lectura = Automático pero UNA SOLA VEZ**
- view, git log (1 vez), git status (1 vez), git diff (1 vez)
- Guardar outputs y reutilizar

**Escritura = Esperar instrucción**
- Commits, verificaciones, tests, planning

**Después de implementar = Sugerir y detener**
- Implementar código → mostrar resumen → sugerir verify → DETENER

**Git operations = Secuencial, nunca paralelo**
- Un comando git a la vez
- Esperar que termine completamente
- Guardar output, reutilizar
