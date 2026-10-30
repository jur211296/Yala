---
esfuerzo: medium
release: no
---
# Grupos: devolver el degradado del tema y poner en color de texto normal los montos en teal (en la rama del PR #700)

Cierre: **cierra-sola** → al terminar, `/cerrar-total`.
Slug: `pr700-grupos-numeros-texto-normal` · al cerrar → **S28tf** (`subida-testflight-2-2-5`, TestFlight 2.2 (5)).

## Contexto
El [PR #700](https://github.com/jur211296/Yala/pull/700) (rama `encargo/2026-10-30-grupos-blanco-graficas-welcome-centrado`) interpretó mal a Jürgen en Grupos: quitó el degradado/fondo del tema. Su auto-merge está DESACTIVADO; el PR sigue abierto.
Corrección de Jürgen (30-oct 14:20 Lima): «El punto de Grupos no me refería al degradado, eso es propio del tema. Me refería al celeste de los números del hero que está en teal y los números de “te deben” en cada grupo y eso.» Sobre el color: «El normal» = el color de texto normal/primario del tema (negro en claro, blanco en oscuro).
Card: `tablero ver tablero-grupos-devolver-el-degradado-del-tema-y-jmgh` (previa: `tablero-grupos-en-blanco-sin-hero-celeste-fondo-bvpn`).

## Qué se pide
Trabaja EN LA MISMA RAMA del PR #700. No abras PR nuevo.
1. Revertir el cambio que quitó el degradado/fondo del tema en Grupos (lista, detalle, Saldos, Estadísticas): Grupos vuelve a su fondo de tema como antes.
2. En todo Grupos, los montos que hoy salen en teal/celeste (número grande del hero/cabecera, «te deben» / «debes» de cada fila de grupo, saldos y similares) pasan al color de texto primario del tema, con el token/estilo existente (no un color nuevo). Busca dónde más en Grupos se usa ese teal para montos y aplícalo igual; anota en el PR y en la card la lista de lo que cambiaste.
3. Mantener lo demás del PR: fondo de las 4 tarjetas de Gráficas del Flujo de caja igual a Tendencias, y Welcome centrado como el onboarding.
4. Capturas antes/después de Grupos en claro y oscuro en `capturas/` del worktree; tests en verde; review adversarial del diff.
5. Haz un solo fetch y rebase sobre origin/2.2 antes de empujar al PR; no esperes el CI de otro PR. Push solo a la rama del PR, con `git push --force-with-lease` si hace falta.
6. Al final, REACTIVA el auto-merge del #700 (`gh pr merge 700 --auto --squash` o el método que ya usaba). Card a «in qa» de Jürgen con las capturas.

Pipeline serial de la Mini: limpiar, build con `xcodebuild -jobs 2` sin sim booteado, boot de 1 sim, tests, apagar y borrar el sim. Al lanzar y al cerrar, borra sin preguntar el DerivedData de esta sesión y las cachés de XcodeBuildMCP de worktrees que ya no existen. No toques las de un worktree vivo.

## Qué NO hay que tocar
- Colores semánticos fuera de Grupos. Ninguna otra rama ni PR; el PR #650 no se toca.
- Nada de funcionalidad nueva.

## Cómo se sabe que está bien
Grupos con su fondo de tema; montos que eran teal ahora en texto primario (claro y oscuro); gráficas y Welcome del #700 intactos; tests verdes; #700 rebasado y con auto-merge activo.

Termina con /cerrar-total.
