# Implementar lo ya decidido de la Auditoría UX 2.2 · lotes 5, 6 y 7 (primeros días; datos previos y nube; cuentas y categorías)

Base y PR: **2.2**. `lanzar-sesion` te deja sobre origin/2.1: antes del primer commit haz `git fetch origin && git switch -C encargo-tmp origin/2.2` (o rebasa tu rama sobre origin/2.2) y comprueba que `git log origin/2.2..HEAD` sale vacío. PR contra 2.2.

## Qué implementar
Las cards de Yala versión 2.2 en **backlog** cuyo título empieza por «UI/UX 2.2 · L5-», «L6-» o «L7-» (y los «Bug 2.2» de esos mismos lotes): `tablero listar --proyecto yala --version 2.2 --estado backlog --json` y filtra. Implementa todas: con la decisión de Jürgen si está escrita en la card (contexto, nota o siguiente paso), y si no, con la opción recomendada (ver abajo).
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

## Paso 0 — decisiones

> Resueltas en autónomo (bypass, fin de semana): las recomendaciones se dan por buenas. Se discuten en el PR.

**Medido al abrir:** 46 cards en backlog (15 de L5, 13 de L6, 18 de L7). Las 46 traen la decisión de Jürgen en «siguiente paso» (L5 según el informe; L6 y L7 «B» o la variante; L7-7 «C»). No hay ningún «Bug 2.2» de estos lotes en backlog: los bugs de la auditoría ya se arreglaron en #494, #495 y #496.

**D1 · Cómo se reparte el trabajo** → tres agentes en paralelo, uno por lote (L5, L6, L7 sin L7-18), cada uno en su propio worktree y **solo compilando**. Yo integro las tres ramas, hago L7-18 encima, y corro tests, gate, QA y capturas en un único simulador.
Por qué: son 46 cards, y en paralelo no se rompe la regla de un simulador a la vez. Alternativa descartada: los tres lotes en serie en esta sesión, que agota el contexto antes del lote 7.

**D2 · Las capturas del «antes»** → son las de la auditoría (14-oct, sobre 2.2), copiadas a `capturas/antes-*.png`. Se saca una nueva solo donde el PR #537 cambió la pantalla después de esa fecha.
Por qué: retratan la app sin estos cambios, y otra tanda cuesta horas y ~12 GB. Alternativa descartada: rehacer el «antes» desde la base, que sale igual que el de la auditoría.

**D3 · Textos en los 16 idiomas** → cada agente añade sus claves al final de los `.strings` (los 16, variantes incluidas) y los `.strings` se integran con merge `union`. Los `.stringsdict` se integran a mano.
Por qué: así tres ramas pueden añadir claves sin pisarse. `noDuplicateKeys` caza cualquier duplicado que deje el union.

**D4 · L5-15: qué Novedades lleva 2.2** → monto el mecanismo (sale solo al actualizar, nunca en una instalación nueva, más la fila «Novedades» en Ajustes › Ayuda) y una entrada de 2.2 con lo que ya está mergeado en 2.2. Abro ticket y card para revisar el texto antes de publicar.
Por qué: la regla es no inventar funciones, y 2.2 aún recibe lotes. Alternativa descartada: dejar 2.2 sin contenido, porque entonces la hoja no sale nunca, que es justo el bug.

**D5 · L7-18: alcance** → «registro» y «moneda» en todo el texto que ve la persona, en los 16 idiomas, incluidos los nombres de pantalla («Divisa y cambio» pasa a «Moneda y tipo de cambio»). Hay dos excepciones: una card de 2.2 que ya fijó otro nombre manda, y las claves que se comparan con datos guardados (`subcategory.balanceAdjustment`, columnas del CSV) no cambian.
Por qué: un término por cosa, como pide la regla de estilo. Que una pantalla siga diciendo «divisa» es la mezcla que la card quiere quitar.

**D6 · Qué queda para Jürgen** → solo un cambio de esquema SwiftData o de iCloud. Si una card lo necesitara, se para esa pieza y se anota. «Mover sus registros» (L7-10) e importar parcialmente (L7-17) son acciones que la persona confirma, sin cambio de esquema: se implementan.
Por qué: el encargo reserva para Jürgen lo irreversible: borrar datos, el esquema de iCloud y los cobros.

**D7 · Review adversarial** → una lente con refutación por cada zona cara: el arranque del almacenamiento (L6-2), el progreso de la entrada a la nube (L6-13), mover registros (L7-10), importar (L7-15/17) y las calculadoras de saldo y de conversión (L7-6, L7-7). Los textos y el polish visual no la llevan.

**D8 · Tablero** → cada card pasa a `in progress` cuando su agente la empieza, y a `done` cuando el PR queda en cola de auto-merge, con la nota de lo decidido. Lo que pida el iPhone va en el guion de device-QA del PR.

## Resultado (2026-10-17)

- **Implementadas las 46 cards** (L5-1…15, L6-1…13, L7-1…18), cada una con lo decidido en su nota. Tres agentes en paralelo (uno por lote) y un cuarto para L7-18, integrados con un merge de textos clave a clave. El merge `union` de la D3 no servía, porque los lotes también borraban y cambiaban claves en mitad del fichero.
- **Desvíos de lo decidido**, con su porqué en la card:
  - L6-13: la pantalla enseña el porcentaje, porque las cifras en vivo no suben mientras conecta.
  - L6-11: el diálogo es una alerta y no una hoja.
  - L7-8: el aviso usa códigos de moneda.
  - L5-15: lleva también una entrada de 2.2, más una card nueva para revisarla antes de publicar.
- **Review adversarial** (D7, tres lentes): 11 hallazgos reales, arreglados con tests en `UXAudit22ReviewFixesTests`. Los dos más serios eran el presupuesto que pasaba a contar todo el gasto al mover registros, y «Otros» e «Ingresos», que se podían mover con sus ajustes de saldo y transferencias. La confirmación de mover ahora dice que los presupuestos pasan a contar el destino.
- **Encontrado al probar:** la fila «Moneda» del formulario de cuenta no respondía al centro. Es anterior al PR y ahora tiene XCUITest.
- **Verificación:**
  - 10.318 tests unitarios en verde.
  - XCUITest de las 79 suites de las áreas tocadas, 260 casos, con el centinela solo. Dos rojos por contrato viejo («Conservar» y una aserción con `exists` bajo una hoja), corregidos y en verde.
  - Simulador: el recorrido de L5 y L7 y las pantallas de L6 con la maqueta local. Capturas en `/Users/jur/Claude/worktrees/_capturas/2026-10-17-implementar-2-2-l5-l6-l7/`.
