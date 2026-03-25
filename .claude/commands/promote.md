---
description: Promueve una Idea a Feature en el Backlog con template completo.
---

Convierte una idea en un feature spec en el Backlog.

## PASO 1: IDENTIFICAR LA IDEA

Si el usuario pasa un nombre como argumento (ej: `/promote modo-offline`), buscar:
```
.planning/Ideas/*modo-offline*
```

Si no pasa argumento, listar archivos en `.planning/Ideas/` y preguntar cual promover.

## PASO 2: LEER LA IDEA

Leer el contenido completo del archivo de la idea.
Extraer: la idea, por que importa, notas.

## PASO 3: CREAR FEATURE EN BACKLOG

Crear un nuevo archivo en `.planning/Backlog/` con el mismo nombre, usando este formato:

```markdown
---
status: backlog
priority: [inferir de la idea o preguntar]
area: [inferir del contenido]
tags: [feature]
created: [fecha de hoy YYYY-MM-DD]
updated: [fecha de hoy YYYY-MM-DD]
promoted_from: Ideas/[nombre original]
---

# [Titulo descriptivo]

## Problema
> [Expandir desde "por que importa" de la idea original]

## Solucion
> [Expandir desde "la idea" original]

## Acceptance Criteria
- [ ] [criterio derivado de la idea]
- [ ] [criterio derivado de la idea]
- [ ] [criterio derivado de la idea]

## Notas originales
[contenido original de la idea]

## Diseno
![[]]

## Notas Tecnicas
-
```

## PASO 4: CONFIRMAR

```
Idea promovida a Backlog:
  Ideas/[nombre].md → Backlog/[nombre].md
  Status: backlog
  Prioridad: [X]

Siguiente paso: /spec [nombre] para desarrollar el plan tecnico
```

## REGLAS
- NO borrar la idea original (queda como referencia)
- Expandir el contenido, no solo copiar — agregar valor
- Si la idea es muy vaga, preguntar al usuario antes de crear el feature
