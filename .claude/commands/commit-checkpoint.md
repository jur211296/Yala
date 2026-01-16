Guarda progreso intermedio de trabajo sin hacer commit permanente.

CONTEXTO:
Este comando es para cuando estás en medio de un incremento grande y quieres guardar progreso sin completar el commit atómico real. Es tu safety net.

PASOS OBLIGATORIOS:
1. Ejecuta git status para ver cambios actuales
2. Revisa git log --oneline -5 para ver si ya hay commits wip: previos
3. Stage TODOS los cambios actuales con: git add -A
4. Crea commit con formato: "wip: [descripción breve del progreso]"
5. Ejemplo: "wip: CategoryListView structure complete, pending data binding"
6. Informa al usuario que este commit es temporal y puede reescribirse después

REGLAS:
- SIEMPRE usa prefijo "wip:" para distinguir de commits reales
- NO ejecutes verificaciones (build/test) antes de este commit
- Estos commits están diseñados para ser reescritos o squasheados después
- Cuando completes el incremento real, puedes usar: git reset --soft HEAD~N para combinar commits wip en uno final
- Documenta en el mensaje qué está completo y qué falta

CUÁNDO USAR ESTO:
- Estás en medio de un incremento que tomará más de 30 minutos
- Quieres cambiar de contexto pero volver después
- Te acercas al límite de tokens pero el incremento no está completo
- Necesitas probar algo destructivo y quieres poder revertir fácilmente
