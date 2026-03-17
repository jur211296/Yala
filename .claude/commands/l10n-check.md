---
description: Auditoría de localización — keys faltantes, strings vacíos, placeholders inconsistentes
allowed-tools: Grep, Glob, Read, Bash(wc:*), Bash(diff:*), Bash(sort:*), Bash(comm:*)
argument-hint: "[idioma específico o vacío para todos]"
---

Auditoría completa de localización en los 6 idiomas del proyecto.

## IDIOMAS

| Código | Idioma |
|--------|--------|
| es | Español (base) |
| en | English |
| fr | Français |
| pt-BR | Português |
| de | Deutsch |
| it | Italiano |

## PASO 1: ENCONTRAR ARCHIVOS DE LOCALIZACIÓN

```
Glob: **/*.strings
Glob: **/Localizable.strings
Glob: **/InfoPlist.strings
```

Identificar todos los archivos .strings por idioma.

## PASO 2: KEYS FALTANTES ENTRE IDIOMAS

Para cada par de idiomas (base es vs otros):

1. Extraer keys de cada archivo:
   ```
   Grep: ^"[^"]*" en cada Localizable.strings
   ```

2. Comparar keys del español (base) con cada idioma:
   - Keys en es que NO están en en → FALTANTE en inglés
   - Keys en en que NO están en es → KEY HUÉRFANA en inglés
   - Repetir para fr, pt-BR, de, it

## PASO 3: STRINGS VACÍOS

```
Grep: = "";$ en cada archivo .strings
Grep: = " ";$ (solo espacios)
```

Listar strings vacíos por idioma — probablemente no traducidos.

## PASO 4: PLACEHOLDERS INCONSISTENTES

Para cada key que existe en todos los idiomas:
- Contar %@ , %d, %lld, %f en cada traducción
- Si el count difiere entre idiomas → INCONSISTENTE (crash potencial)
- Verificar que el orden de placeholders numerados (%1$@, %2$@) sea consistente

## PASO 5: STRINGS SIN LOCALIZAR EN CÓDIGO

```
Grep: Text\("[A-Z] en archivos .swift de Yala/ (excluir Tests/)
```

Detectar Text() con strings literales que deberían usar L10n.
- IGNORAR: SF Symbols, formatos numéricos, debug text
- IGNORAR: Archivos en Widgets/ (usan sus propios strings)

## PASO 6: LONGITUD EXCESIVA

Para cada key, comparar longitud entre idiomas.
Si una traducción es >2x la longitud del español → puede truncarse en UI.
Idiomas que típicamente son más largos: alemán, francés.

## REPORTE

```
## L10n Check — [N] keys, 6 idiomas

### Resumen
| Idioma | Keys | Vacíos | Faltantes | Huérfanas |
|--------|------|--------|-----------|-----------|
| es | N | 0 | — | N |
| en | N | N | N | N |
| fr | N | N | N | N |
| pt-BR | N | N | N | N |
| de | N | N | N | N |
| it | N | N | N | N |

### Keys faltantes (por idioma)
[Lista de keys que faltan en cada idioma]

### Placeholders inconsistentes
| Key | es | en | fr | ... | Problema |
|-----|----|----|----| ... |----------|
| key.name | %@ %d | %@ | %@ %d | ... | en: falta %d |

### Strings sin L10n en código
- [archivo:línea] Text("literal")

### Longitud excesiva (>2x base)
| Key | es (len) | Idioma | Traducción (len) |
|-----|----------|--------|------------------|

### Veredicto: LIMPIO | N ISSUES
```

## REGLAS
- El español (es) es el idioma BASE de referencia
- Keys faltantes en cualquier idioma son BLOQUEANTES para release
- Strings vacíos son BLOQUEANTES (UI mostrará vacío)
- Placeholders inconsistentes son CRÍTICOS (crash en runtime)
- Strings sin L10n en código son WARNING (no bloquean pero acumulan deuda)
