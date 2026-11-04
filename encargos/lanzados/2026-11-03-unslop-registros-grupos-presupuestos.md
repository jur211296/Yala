# Unslop-design en Registros, Grupos y Presupuestos: antes y después por arreglo para que Jürgen elija

Base: origin/2.2 en jur211296/Yala. Una sola sesión a la vez. Haz lo mismo que en la prueba del PR #761, pero en Registros, Grupos (con la cabecera nueva) y Presupuestos, en modo claro y en oscuro. Instala el skill solo en el worktree y respeta el README de marca: nada de degradados ni glows. Cada arreglo va en un commit con su lámina de antes y después. Abre el PR como borrador, con una tabla de arreglos y tu recomendación, y no lo mergees: Jürgen elige. Card: «Unslop-design en Registros, Grupos y Presupuestos».

Termina con /cerrar-total.

## Paso 0

Decisiones resueltas antes de tocar código (sesión autónoma, sin nadie delante). Mismo método que la prueba del Panel y Estadísticas, ya mergeada.

1. **Skill:** copia de `marcosnovo/unslop-design` en `.claude/skills/unslop-design/` del worktree, sin `install.sh` (instala global). No se commitea y muere con el worktree.
2. **Claro y oscuro:** temas Claro (`userTheme 1`) y Oscuro (`userTheme 2`). El tema por defecto (navy) no se cubre.
3. **Datos:** semilla `ficha` + `-uitest-seed-marketing` (PEN, es-PE): trae registros, los grupos de casa y presupuestos. Se entra a cada pantalla con `-uitest-deeplink records|groups|budgets`.
4. **Grupos:** la lista con la cabecera nueva (neto, barra, debes / te deben) y el detalle de un grupo si se alcanza; Presupuestos: la lista y su detalle si se alcanza; Registros: la lista.
5. **El skill pide esperar el «sí» antes de implementar.** Manda el encargo: cada arreglo va implementado en su commit, con su lámina en el mismo commit, y el PR en borrador hace de propuesta.
6. **Revisores:** tres en paralelo, uno por pantalla.
7. **Filtro de marca:** nada que añada degradado, brillo o sombra de color; quitar uno sí vale. El glass y las tarjetas blancas se quedan; se adapta, no se rediseña. La cabecera nueva de Grupos la eligió Jürgen hoy: solo se tocan defectos claros, no su diseño.
8. **Merge:** no. PR en borrador, sin cola de auto-merge (el encargo lo prohíbe y manda sobre el modo cola). La card queda esperando la elección de Jürgen.
9. **Gate:** sobre el árbol final; cada estado intermedio compila antes de fotografiarse.
