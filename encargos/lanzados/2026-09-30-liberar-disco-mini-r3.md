# Liberar disco en la Mini (Data ~14 GB / bajo piso 15 GB) sin tumbar Claude ni sims de producto

## Contexto
Data volume ~93% / ~14 GB libres (piso CI 15 GB). Jürgen pide liberar disco ahora. Usuario `ci` tiene ~/DerivedData ~3.4G + actions-runner ~436M + _work ~767M. Runner mini-ci aparcado. Cola A/adaptive PAUSADAS — esta sesión es SOLO limpieza de disco.
Trabajar EN EL ÁRBOL PRINCIPAL (`--sin-worktree`): no hace falta PR/worktree para borrar caches. Las sesiones previas con worktree murieron al arrancar con «cwd was deleted».

## Que se pide
1. Inventario de lo que más come Data (DerivedData jur+ci, CoreSimulator caches, Xcode caches, worktrees Claude viejos ya mergeados, Logs, Trash, Docker si hay, etc.) sin borrar a ciegas.
2. Liberar con seguridad ≥15 GB libres en Data (mejor margen). Prioridad: DerivedData de `ci` y caches regenerables; worktrees/encargos EN CURSO muertos tras merge; caches Xcode seguros.
3. NUNCA: `simctl erase all` / `shutdown all` / `killall Simulator`; no borrar sims YalaLane-Adapt-* ni datos de Jürgen; no tocar repos con trabajo sin merge; no sudo destructivo sin AskUserQuestion (salvo el paso FINAL ya aprobado abajo).
4. Si hace falta actuar como `ci` o sudo fuera del paso FINAL, AskUserQuestion / Necesita de ti con el comando exacto.
5. Al cerrar: reportar GB liberados y `df` final; nota corta en docs/memory si aplica. Si no hay cambios de repo que merezcan PR, cierra sin inventar commits de producto.

## Paso FINAL (aprobado por Jürgen 30-sep) — unload + borrar usuario `ci`
Jürgen CONFIRMÓ: unload del runner mini-ci / LaunchAgent Y borrar el usuario macOS `ci`. La borrada del usuario está aprobada; AskUserQuestion SOLO si hace falta sudo/contraseña de admin (pegar el comando exacto).
Orden:
1. Parar/unload con seguridad el LaunchAgent del runner (usuario `ci`) y cualquier servicio mini-ci residual. No dejar jobs colgados.
2. Inventariar `/Users/ci` (DerivedData, actions-runner, _work, Library) y liberar lo que se pueda antes de borrar.
3. Borrar el usuario macOS `ci` (sysadminctl / dscl según playbook de la casa). Si pide admin password → AskUserQuestion con el comando exacto; no inventar sudo interactive.
4. Verificar que `/Users/ci` ya no existe (o home archivado) y reportar GB recuperados de ese paso.

## Que NO hay que tocar
Cola A, adaptive, producto, marketing, prod Supabase, secrets en chat. No auto-merge en esta sesión.

## Como se sabe que esta bien
Data con ≥15 GB libres (o máximo seguro documentado); lista de qué se borró; usuario `ci` eliminado (o pendiente de password de Jürgen documentado); sin tumbar la Mini; /cerrar-total (o cierre limpio sin PR si no hubo cambios de código).
