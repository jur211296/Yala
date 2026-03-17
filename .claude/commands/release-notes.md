---
description: Genera release notes desde commits — App Store (6 idiomas) + changelog técnico
allowed-tools: Bash(git:*), Read, Write, Grep, Glob
argument-hint: "[tag_anterior — default: último tag]"
---

Genera release notes automáticas desde el historial de commits.

## PASO 1: IDENTIFICAR RANGO

Si hay argumento ($ARGUMENTS):
- Usar como tag anterior: `git log $ARGUMENTS..HEAD`

Si no hay argumento:
- Encontrar último tag: `git describe --tags --abbrev=0`
- Listar commits desde ese tag: `git log [tag]..HEAD --oneline --no-merges`

Guardar lista de commits.

## PASO 2: CLASIFICAR COMMITS

Agrupar por prefijo:

| Prefijo | Categoría App Store | Emoji |
|---------|-------------------|-------|
| feat: | Nuevas funcionalidades | ✨ |
| fix: | Correcciones | 🐛 |
| refactor: | Mejoras internas | ⚡ |
| test: | (omitir de App Store) | — |
| docs: | (omitir de App Store) | — |
| chore: | (omitir de App Store) | — |

Ignorar commits de merge, docs, test, chore para las notas de App Store.

## PASO 3: LEER CONTEXTO

Para cada commit feat: y fix: significativo:
- Leer el mensaje completo: `git log --format=%B -1 [hash]`
- Si el mensaje menciona un BUG-N, leer el contexto en STATE.md
- Entender el impacto real para el usuario (no el técnico)

## PASO 4: GENERAR NOTAS APP STORE (6 idiomas)

Las notas de App Store deben ser:
- Máximo 4000 caracteres por idioma
- Escritas para USUARIOS, no desarrolladores
- Tono cercano (brand voice Yala: "tú", positivo, simple)
- Sin jerga técnica
- Destacar beneficios, no implementación

### Formato por idioma:

```
## [idioma] — Release Notes V[versión]

[Título atractivo de 1 línea]

[2-5 bullets con las novedades más importantes]
[1-2 bullets con correcciones si son relevantes para el usuario]

[Frase de cierre invitando feedback]
```

### Generar en este orden:
1. **es** (Español — idioma base, escribir primero)
2. **en** (English)
3. **fr** (Français)
4. **pt-BR** (Português brasileiro)
5. **de** (Deutsch)
6. **it** (Italiano)

### Reglas por idioma:
- es: Tono cercano, "tú", español neutro (no regional)
- en: Professional but friendly, "you"
- fr: Vouvoiement ("vous"), ton professionnel
- pt-BR: Informal, "você", português brasileiro
- de: Siezen ("Sie"), professioneller Ton
- it: Dare del "tu", tono amichevole

## PASO 5: GENERAR CHANGELOG TÉCNICO

Para el equipo de desarrollo (no público):

```
## Changelog V[versión]

### Features
- [hash] [descripción técnica]

### Bug Fixes
- [hash] [descripción técnica] (BUG-N si aplica)

### Refactors
- [hash] [descripción técnica]

### Tests
- [N] tests nuevos ([suites añadidas])

### Stats
- Commits: [N] (feat: X, fix: Y, refactor: Z, test: W)
- Archivos modificados: [N]
- Tests total: [N] en [M] suites
```

## PASO 6: GUARDAR

Preguntar al usuario:
```
Release notes generadas.

¿Dónde las guardo?
1. .planning/appstore/release-notes-v[VERSION].md (todas juntas)
2. Mostrar aquí sin guardar
3. Copiar al clipboard
```

## EJEMPLO DE OUTPUT (es)

```
¡Yala se actualiza! 🎉

✨ Smart Insights: Ahora puedes ver análisis inteligentes de tus gastos
   directamente en el Panel y en Estadísticas.
✨ Onboarding mejorado: Configurar tu cuenta es más rápido y claro.
✨ Gráficas interactivas: Arrastra sobre las barras de presupuesto
   para ver el detalle de cada período.

🐛 Corregimos un problema con las notificaciones que llegaban
   fuera de horario.
🐛 Los filtros ahora funcionan correctamente al cambiar de pestaña.

¿Te gusta Yala? Déjanos una reseña en la App Store 💛
```

## REGLAS
- NUNCA incluir detalles técnicos en notas de App Store
- NUNCA mencionar nombres de archivos, clases o bugs internos
- Agrupar fixes similares en un solo bullet ("Corregimos varios problemas de estabilidad")
- Si hay >5 features, priorizar las 3-4 más impactantes para el usuario
- El tono debe ser consistente con BRAND-VOICE.md
- Cada idioma es una TRADUCCIÓN ADAPTADA, no una traducción literal
