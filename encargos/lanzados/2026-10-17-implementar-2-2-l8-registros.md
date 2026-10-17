# Implementar lo ya decidido de la Auditoría UX 2.2 · lote 8 (registros: ver, editar, buscar y filtrar)

Base y PR: **2.2**. `lanzar-sesion` te deja sobre origin/2.1: antes del primer commit haz `git fetch origin && git switch -C encargo-tmp origin/2.2` (o rebasa tu rama sobre origin/2.2) y comprueba que `git log origin/2.2..HEAD` sale vacío. PR contra 2.2.

## Qué implementar
Las cards de Yala versión 2.2 en **backlog** cuyo título empieza por «UI 2.2 · L8-» o «UX 2.2 · L8-» (y los «Bug 2.2» de esos mismos lotes): `tablero listar --proyecto yala --version 2.2 --estado backlog --json` y filtra. Implementa todas: con la decisión de Jürgen si está escrita en la card (contexto, nota o siguiente paso), y si no, con la opción recomendada (ver abajo).
- Fuente de cada decisión: la card, el informe del lote en ~/Claude/entregas/Yala--auditoria-ux-2-2-lote-*/informe.md, el HTML ~/Claude/propuestas/auditoria-ux-2.2/auditoria-ux-2.2.html y los «Criterios UX/UI permanentes de Jürgen» del brief madre ~/Claude/tmp-frank/auditoria-ux-flujos-2-2.md (léelos: sin degradados, etc.).
- Mueve cada card a in progress al empezar y a done al cerrar (`--agente frank`). Textos nuevos en los 16 idiomas.
- AUTONOMÍA FIN DE SEMANA (Jürgen 16-oct 22:25): Jürgen ya respondió las dudas de estos lotes y no estará en el escritorio. Si al implementar sale una duda (o una card del lote sin decisión explícita), elige TÚ la opción recomendada del informe/HTML (o la que mejor cumpla los Criterios UX/UI permanentes), impleméntala y anótala en la card («Decidido por la sesión: opción recomendada X, porque…») y en el informe. No dejes nada en espera decisión salvo que sea irreversible (borrar datos, esquema de iCloud, cobros): eso sí queda para Jürgen.
- Prueba según /barrido-qa en el simulador. Antes y después en capturas para el cierre.

## Reglas
- Sin esperar el CI de nadie; `git fetch && git rebase origin/2.2` justo antes de abrir tu PR.
- 1 simulador a la vez; apágalo y borra tu DerivedData al terminar. Mira `df -h /` antes de compilar.
- En `~/Yala` (árbol principal) no toques los `.ckdb` sin commitear, `Yala.xcscheme` ni `encargos/pendientes/`. No toques tmux `salud--*`, `sat-lab--*`, `clinicas-dentales-bi--*`.
- Todo ticket nuevo lleva su card.
- Cierra con /cerrar-total.

## Paso 0 (sesión, 2026-10-17)

- **Base:** rama `encargo/2026-10-17-implementar-2-2-l8-registros` recreada sobre `origin/2.2` (474a7b553); `git log origin/2.2..HEAD` vacío al empezar. PR contra 2.2.
- **Cards:** 17 (L8-1 … L8-17). No hay «Bug 2.2» del lote 8 en backlog: los siete bugs del lote (B1–B7) ya se arreglaron en el PR #499.
- **Decisiones escritas por Jürgen (15-oct):** L8-9 a L8-17 (en `siguientePaso`). Solo L8-16 trae nota: «deduplicar con la otra card de Filtros». Medido: en el tablero de 2.2 no hay otra card de Filtros (la de L20-2 es el resumen de Exportar), así que no hay con qué fusionar.
- **Sin decisión escrita → opción recomendada del informe** (regla de autonomía del fin de semana): L8-1 B, L8-2 B, L8-3 B (variante 1), L8-4 B (variante 1), L8-5 B, L8-6 B, L8-7 B, L8-8 B, L8-12 B (variante 1). Las elecciones de `variantes-L8.html` solo vivían en el `localStorage` del navegador de Jürgen y el artifact no tiene comentarios: no hay elección recuperable.
- **L8-8 depende de L2-5** («al guardar, el aviso breve de L2-5»): L2-5 sigue en backlog. Aquí se cambian el título y el aviso del duplicado; el guardado del duplicado heredará lo que haga L2-5 cuando aterrice, sin tocar la pantalla de éxito desde este lote.
- **Ninguna card es irreversible** (no borra datos sin preguntar, no toca esquema de iCloud ni cobros). «Quitar repetidos» (L8-11) borra registros, pero solo tras confirmar, como cualquier borrado.
- **Reparto:** dos agentes en worktree propio, que solo compilan: B = L8-10, L8-11, L8-13 (calendario, duplicados, editar varios); C = L8-14 a L8-17 (buscar y filtros). La sesión hace L8-1 a L8-9 y L8-12, integra, prueba en el único simulador y pasa el gate. Los textos de los agentes llegan como JSON y se aplican a los 16 idiomas con un script (sin merge de `.strings`).
- **Capturas «antes»:** las de la auditoría del lote 8 (14-oct, misma base 2.2), copiadas a `capturas/antes-*.png`; las «después», del simulador tras el gate.

## Resultado (2026-10-17)

- Las 17 cards implementadas en un solo PR contra 2.2. Cada «Decidido por la sesión» está en la nota de su card y en el informe del lote (`~/Claude/entregas/Yala--auditoria-ux-2-2-lote-8-registros/informe.md`, sección «Implementación en 2.2»).
- Review adversarial con dos lentes (borrados y cifras). Cambió el código en cinco puntos: la cuenta entra en la firma de duplicado; «Quitar repetidos» se limita a lo visible y vuelve a medir al confirmar; Deshacer no pisa cambios ajenos; editar varios es todo o nada también ante un fallo del store; un saldo inicial de grupo no se presenta como «Tu parte».
- El barrido en el simulador cazó seis defectos que los tests no veían. Todos se arreglaron:
  - la hoja de Buscar salía vacía;
  - el aviso de la copia quedaba bajo el teclado;
  - la barra de selección se transparentaba y cortaba sus textos;
  - el contorno rojo de la cápsula no se veía;
  - el aviso de grupo se montaba sobre la última fila;
  - Duplicar y Eliminar tenían alturas distintas.
- Hallazgos fuera de alcance, con ticket y card: `regional-variants-show-the-plural-form-for-one`, `hidden-single-currency-still-filters-the-amount-in-it`, `duplicates-mode-rows-dont-say-their-date`.
