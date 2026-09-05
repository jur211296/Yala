# Meter Secrets.xcconfig en .claude/worktree-enlaces

## MODO AUTÓNOMO HASTA TERMINAR
Gate, commit, docs/board si aplica, merge a 2.1 y /cerrar sin preguntar. Solo parar ante decisión/acceso real de Jürgen.

## Contexto
Los worktrees de `lanzar-sesion` no reciben Secrets.xcconfig (gitignore), así que Claude hace `cp`/`ln` a mano antes del primer build. Eso genera ruido en el hook de avisos («Antes había fallado: cp»). Jürgen OK 2026-09-05: el archivo debe enlazarse como `.planning`. Casa arregla launcher/hook por su lado; esto es solo Yala.

El árbol principal ya está al día con `origin/2.1`. Arranca desde ahí; si el worktree nace desfasado, rebase/merge a `origin/2.1` antes del gate.

Secrets.xcconfig / secrets gitignored viven en el árbol principal — tras el cambio de enlaces, los worktrees nuevos los reciben solos. Enlázalos si hace falta para verificar el build en ESTE worktree.

## Que se pide
1. Añadir `Secrets.xcconfig` (una línea) a `.claude/worktree-enlaces`, junto a `.planning`, con un comentario corto de por qué (build Xcode / no versionado).
2. Verificar que el formato del fichero sigue siendo «una ruta relativa por línea» y que no rompe el script que lee los enlaces.
3. Si el launcher/enlazador se puede ejercitar sin side effects raros, confirma que un worktree nuevo recibiría el enlace; si no, documenta en el PR cómo se valida.
4. PR a `2.1`, merge cuando el gate esté verde, /cerrar.

## Que NO hay que tocar
- No subir Secrets.xcconfig al git ni pegar secretos en el PR.
- No tocar marketing/, Casa, ni el script `lanzar-sesion` (eso es Casa/Dan).
- No cambiar lógica de producto de la app.

## Como se sabe que esta bien
- `.claude/worktree-enlaces` lista `Secrets.xcconfig`.
- PR mergeado a 2.1.
- Ticket/encargo cerrado con /cerrar y resumen corto en lenguaje de usuario.

## Avisos al bot dueño (Frank)
POSTea al webhook local de la Mini (URL y key en fichero local, no en git) cuando: (1) decisión de producto/acceso; (2) PR o preview listo; (3) terminaste y /cerrar — resumen de qué se hizo; (4) idle mid-ticket una vez. NO avises por test rojo a reclasificar, build a reintentar, ni ruido de setup (`cp`/`cd`/`ln`/`mkdir` de Secrets o worktree). URL/key solo en la Mini.
