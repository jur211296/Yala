---
name: bugfix
description: Ciclo disciplinado para corregir un bug de Yala — causa raíz, fix mínimo, verificación y commit. Úsalo cuando llegue un bug reportado, unas notas de QA o un fallo reproducible, y el objetivo sea arreglarlo sin arrastrar cambios adyacentes.
---

# Ciclo de corrección de bugs

1. **Leer el reporte completo** — el ticket de `$VAULT/Bugs/`, las notas de QA o la descripción. Si hay guion de reproducción, seguirlo antes de tocar código.
2. **Causa raíz, no síntoma.** Buscar *todas* las instancias del mismo patrón antes de dar el fix por cerrado: en este repo los bugs suelen estar replicados en varios sitios — el de `DateInterval` cerrado en cuatro archivos independientes es el caso de manual.
3. **Proponer el fix mínimo y esperar aprobación.** Nada de refactors adyacentes ni mejoras no pedidas.
4. **Implementar.** Leer los archivos de localización antes de editarlos.
5. **Verificar**: `/gate`.
6. **Test de regresión**: un `fix:` sin test que reproduzca el bug vuelve. Convenciones en `.claude/rules/testing.md`.
7. **Resumir en lenguaje de usuario** y preguntar si quiere QA visual (`/qa`).
8. **Commitear** con `/commit-one` cuando dé el visto bueno.
