# Cola 2.2 · lote 12.3 Accesibilidad, contraste y diseño (8 cards)

## Contexto
Jürgen (24-oct): seguir la cola 2.2 por lotes 12.x hasta cerrar todas las cards de 2.2; el barrido de QA estricto es el cierre final de 2.2. Ya cerraron 12.1 Grupos (PR #623), el Duo cerrado opción 2 (PR #624) y 12.2 Nube e iCloud (PR #625, en cola de merge a 2.2). Esta es la sesión **12.3 · Accesibilidad, contraste y diseño**. Base: `origin/2.2`, PR contra 2.2.

Son ocho cards en «lista para lanzar», versión 2.2. Léelas enteras con `tablero ver <id>` antes de tocar código (traen contexto, siguiente paso y hecha-cuando):

1. `tablero-apuntar-pago-y-el-guardar-del-saldo-inic-rhgi` — «Apuntar pago» y el «Guardar» del saldo inicial se apagan sin decir qué falta
2. `tablero-con-el-texto-muy-grande-en-un-iphone-se-rrpx` — Con el texto muy grande en un iPhone SE, la Bandeja no deja ver ni aprobar los borradores
3. `tablero-el-indigo-de-marca-como-texto-pequeno-no-1c9w` — El índigo de marca como texto pequeño no llega a AA sobre los temas oscuros
4. `tablero-en-los-temas-rosa-teal-y-minimalista-el-lbcr` — En los temas Rosa, Teal y Minimalista el texto blanco de los botones no llega a AA
5. `tablero-en-modo-oscuro-los-importes-de-ingresos-elwl` — En modo oscuro, los importes de ingresos se leen mal: el turquesa no llega al contraste mínimo
6. `tablero-entrada-a-yala-las-pantallas-se-cierran-4gfj` — Entrada a Yala: las pantallas se cierran y se abren enteras; buscar una transición más bonita
7. `tablero-ux-2-2-onboarding-control-de-8-pasos-a-6-u4uz` — UX 2.2 · L1-9 · onboarding «control»: de 8 pasos a 6
8. `tablero-voiceover-lee-un-gasto-en-divisa-extranj-cvlu` — VoiceOver lee un gasto en divisa extranjera con el símbolo de la divisa preferida

La card del README de marca (`...-cisf`) es de Lola: NO la toques.

## Qué se pide
1. Al empezar: mueve las ocho a «in progress» con `--agente frank`.
2. Arregla cada una según su «hecha cuando». Preferible tests (unit / XCUITest) que cubran la regresión. Criterio estricto de barrido: solo deja en «in qa» a jurgen (con guion corto) lo grave que el simulador no valida; lo demás a done.
3. Contraste: corrige en los tokens del tema (no color por color en cada vista) y comprueba AA con números en el cierre.
4. Diseño sin decidir (la transición de la entrada a Yala y, si hace falta, la fusión de pasos del onboarding): no lo inventes. Deja 2-3 propuestas con capturas o video corto, con tu recomendación, y la card en «espera decisión» a jurgen. El resto del lote sigue.
5. Dudas reversibles: toma la opción recomendada y anótala en la card. Solo lo irreversible queda en «espera decisión» a jurgen.
6. Tickets nuevos de lo que encuentres, con su card.
7. Si hay cambio visible, capturas antes/después en `capturas/` del worktree y listarlas en el cierre.

## Qué NO hay que tocar
- marketing/ y Web/, ni el README de marca (lo lleva Lola).
- Ningún despliegue de esquema CloudKit a producción ni cambios en Supabase de producción.
- No desactivar tests ni saltarse protecciones de rama.

## Cómo se sabe que está bien
Las ocho cards cumplen su «hecha cuando» (o quedan en in qa / espera decisión con motivo), suite unit en verde, PR a 2.2 en auto-merge, `/cerrar-total`.

## Gate después del CI del PR anterior
Arranca ya sobre `origin/2.2`. Justo antes del gate, si #625 (u otro PR de la cola) sigue en CI, espera a que entre y rebasea una sola vez con el simulador apagado. Si 2.2 no se movió, sigue. Si ese CI falla, no esperes: rebasea con lo que haya y sigue. Build y simulador después de ese rebase, una sola vez.

## Mini
Pipeline serial Yala: limpiar sims muertos / DerivedData de sesiones cerradas / cachés de XcodeBuildMCP de worktrees que ya no existen (sin preguntar); build con `xcodebuild -jobs 2` sin sim booteado; un solo simulador iPhone para tests (un iPhone SE para la card del texto grande, de a uno); al cerrar apagar y borrar ese sim y el DerivedData de esta sesión. Disco: hay ~30 GB libres, por debajo del umbral APRETADO de 32 GB: limpia sin preguntar antes del build.

## Paso 0 — decisiones

> Resueltas en autónomo (bypass): las recomendaciones se dan por buenas. Se discuten en el PR.

**D1 · rhgi: ¿mismo trato que L13-9 en «Apuntar pago» y el «Guardar» del saldo inicial?** → Sí: botones siempre activos; al tocarlos con algo pendiente, marca el campo, una línea dice qué falta y VoiceOver lo anuncia.
Por qué: el ticket lo plantea como la misma pieza y la decisión B de Jürgen (18-oct) ya eligió ese patrón. Alternativa descartada: dejarlo apagado (es justo lo que reporta la card).

**D2 · rhgi: textos.** → Se reusa «Falta el monto» del gasto; tres claves nuevas para el saldo inicial (quién debe, a quién, dos personas distintas), en los 16 idiomas.
Por qué: el importe dice lo mismo en los tres formularios. Alternativa descartada: componer con las etiquetas «Quién debe»/«A quién» (frase rota en varios idiomas).

**D3 · 1c9w: ¿token de texto índigo para temas oscuros?** → Sí, la opción recomendada: token `accentText` en `YalaTheme` (#818CF8 en los temas índigo oscuros); el relleno de botones sigue con `accent`. Todo primer plano en el color del tema (texto e iconos) pasa al token.
Por qué: un solo color no puede dar AA al blanco encima y al texto encima del fondo oscuro (medido en el ticket); el encargo pide corregir en los tokens. Alternativa descartada: dejarlo (no cumple el «hecha cuando»).

**D4 · 1c9w: ¿el token cubre también Rosa?** → Sí, `accentText` rosa = #FF4DA6 en los temas rosa.
Por qué: `hotPink` como texto da 4,48 sobre la tarjeta de Rosa; el token existe por tema y definirlo por debajo de AA sería dejar el mismo bug. Teal y Minimalista ya pasan con su acento.

**D5 · lbcr: ¿qué color lleva el texto sobre el acento?** → Token `onAccent` por tema, elegido por contraste: blanco en los índigo, negro en Teal, Minimalista y Rosa.
Por qué: es la opción recomendada del ticket (negro sobre #00C2CB 9,6:1, sobre gris 11,4:1, sobre #FF0080 5,6:1) y no toca el color de ningún tema. Alternativa descartada para Rosa: relleno más profundo #D6006B (cambia el color del botón, que es identidad del tema). Reversible: cambiar el valor del token.

**D6 · elwl: ¿qué turquesa para el ingreso en oscuro?** → `incomeAmount` pasa a adaptativo: #0F7A80 en claro (como hoy) y #00C2CB (`priorityNeed`, el de marca) en oscuro: ≥ 6,3:1 en todas las tarjetas oscuras.
Por qué: es el mismo matiz de marca y ya se usa para rellenos; no hace falta un hex nuevo. Alternativa descartada: un hex intermedio nuevo (otro color más en la paleta).

**D7 · rrpx: ¿cómo deja sitio la Bandeja a texto grande?** → A tamaños de accesibilidad (AX1–AX5) la cabecera entra en la lista y se desplaza con ella; a tamaño normal no cambia nada.
Por qué: el ticket pide «al menos a tamaños de accesibilidad» y que a tamaño normal no cambie nada visible. Alternativa descartada: moverla siempre (cambia cómo se comporta la pantalla para todos).

**D8 · cvlu: el arreglo ya está en 2.2 (lote 8, 47aa34f6c).** → Queda lo que pide el ticket y no estaba: un test de verdad con un registro en divisa extranjera (hoy hay un escaneo de dos literales) y el barrido del mismo patrón en otras filas.

**D9 · u4uz: el onboarding ya está en 7 pasos (PR #485, decisión parcial de Jürgen del 13-oct).** → No se reabre: se verifica en el simulador (7 puntos, «¿Dónde está tu dinero?» con «Todo junto») y la card va a done. La opción B (6 pasos, saldo opcional) ya la descartó Jürgen.

**D10 · 4gfj: la transición de la entrada a Yala es diseño sin decidir.** → No se implementa: se prototipan 3 propuestas detrás de un argumento de depuración, con vídeo, y la card queda en «espera decisión» a Jürgen con la recomendada.

**D11 · Capturas y QA.** → Antes/después en `capturas/`; a «in qa» de Jürgen solo lo grave que el simulador no valida (previsto: nada de este lote; contraste y tamaños se miden aquí).
