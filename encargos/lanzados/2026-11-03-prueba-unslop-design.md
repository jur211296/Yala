# Prueba de unslop-design: revisión de diseño de Panel y Estadísticas con capturas de antes y después, sin mergear

Base: origin/2.2 en jur211296/Yala. Una sola sesión a la vez.

1. Instala el skill https://github.com/marcosnovo/unslop-design solo dentro del worktree de esta sesión. No lo instales de forma global.
2. Córrelo en modo revisión sobre el Panel y Estadísticas, en modo claro y en modo oscuro.
3. Por cada arreglo que proponga, aplícalo en un commit separado y saca una captura de antes y otra de después en el simulador.
4. Respeta el README de marca: nada de degradados ni glows. Si un arreglo choca con él, anótalo y no lo apliques.
5. Abre el PR en draft con una tabla que tenga el arreglo, las dos capturas y tu recomendación. No lo mergees. Jürgen elige qué arreglos entran.
6. Card: «Prueba unslop-design: revisión de Panel y Estadísticas con antes y después, sin mergear».

Termina con /cerrar-total.

## Paso 0

Decisiones resueltas antes de tocar código (sesión en MODO cola, sin nadie delante):

1. **Instalación del skill:** copia en `.claude/skills/unslop-design/` del worktree, sin `install.sh` (ese script instala en `~/.agents` y enlaza en `~/.claude`, que es global). No se commitea: el PR es de diseño, y meter el skill en `.claude/` cambiaría cómo trabaja todo el mundo. Muere con el worktree.
2. **«Modo claro y oscuro»:** los temas Claro (`userTheme 1`) y Oscuro (`userTheme 2`) de la app. El tema por defecto («Liquid Glass», navy) no se cubre: el encargo pide claro/oscuro.
3. **Datos:** semilla `ficha` + `-uitest-seed-marketing` (dos años, PEN, es-PE). Capturas del «antes» con la base compilada sin tocar.
4. **El skill pide publicar la propuesta y esperar el «sí» antes de implementar.** Aquí manda el encargo: cada arreglo se implementa en su commit y el PR en draft hace de propuesta; Jürgen elige cuáles entran.
5. **Revisores:** dos en paralelo (Panel, Estadísticas) en vez de 3-4: son dos pantallas.
6. **Filtro de marca:** nada que añada degradado, brillo o sombra de color. Quitar un degradado sí vale. Además, criterio ya dado por Jürgen: el glass y las tarjetas blancas se quedan; se adapta, no se rediseña.
7. **Merge:** no. PR en draft y sin cola de auto-merge (el encargo lo prohíbe expresamente; manda sobre ADR-054). La card queda en `qa`/espera de decisión.
8. **Gate:** un `/gate` sobre el conjunto antes del primer push; cada commit separado compila por sí solo (se verifica con build incremental por commit).
