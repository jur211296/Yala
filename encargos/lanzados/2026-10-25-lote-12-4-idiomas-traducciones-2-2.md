# Cola 2.2 · lote 12.4 Idiomas y traducciones (10 cards)

## Contexto
Jürgen (24-oct): seguir la cola 2.2 por lotes 12.x hasta cerrar todas las cards de 2.2; el barrido de QA estricto es el cierre final de 2.2. Ya cerraron 12.1 Grupos (PR #623), el Duo cerrado opción 2 (PR #624), 12.2 Nube e iCloud (PR #625) y 12.3 Accesibilidad, contraste y diseño (PR #626, en cola de merge a 2.2). Esta es la sesión **12.4 · Idiomas y traducciones**. Base: `origin/2.2`, PR contra 2.2.

Son diez cards en «lista para lanzar», versión 2.2. Léelas enteras con `tablero ver <id>` antes de tocar código (traen contexto, siguiente paso y hecha-cuando):

1. `tablero-bug-2-2-en-es-es-es-ar-en-gb-y-pt-pt-los-onyo` — En es-ES, es-AR, en-GB y pt-PT los recuentos de uno salen en plural
2. `tablero-en-es-419-los-nombres-de-categorias-usan-fuu8` — En es-419, los nombres de categorías usan palabras peruanas
3. `tablero-las-fechas-cortas-salen-13-oct-tambien-e-78ac` — Las fechas cortas salen «13 Oct» también en inglés de EE. UU.
4. `tablero-las-sugerencias-del-saludo-de-yala-ia-es-43yd` — Las sugerencias del saludo de Yala IA escriben los comercios en mayúsculas
5. `tablero-los-textos-de-categorias-en-pt-br-siguen-yg5z` — Los textos de categorías en pt-BR siguen con «Eliminar» y sin acentos
6. `tablero-por-dentro-el-excel-sigue-diciendo-trans-g1p8` — Por dentro, el Excel sigue diciendo «Transacciones» y el archivo de grupos lleva la hora en cifras
7. `tablero-pt-pt-su-bloque-de-respaldo-quedo-con-el-j1be` — pt-PT: su bloque de respaldo quedó con el pt-BR viejo
8. `tablero-revision-de-traducciones-con-sonnet-ante-681y` — Revisión de traducciones con Sonnet antes de cada release (16 idiomas)
9. `tablero-un-error-de-la-foto-todavia-nombra-al-pr-t6et` — Un error de la foto todavía nombra al proveedor de IA (en inglés)
10. `tablero-unas-260-cadenas-antiguas-en-frances-sal-ih44` — Unas 260 cadenas antiguas en francés salen sin tildes

## Qué se pide
1. Al empezar: mueve las diez a «in progress» con `--agente frank`.
2. Arregla cada una según su «hecha cuando». Preferible tests (unit / XCUITest) que fijen la regresión (plurales, formato de fecha por locale, textos sin nombre del proveedor). Criterio estricto de barrido: solo deja en «in qa» a jurgen (con guion corto) lo grave que el simulador no valida; lo demás a done.
3. Traducciones: corrige en los catálogos de cadenas (`.xcstrings` / respaldo), no en cada vista. Revisa que el español sea neutro latinoamericano en es-419.
4. Revisión con Sonnet (card 8): si toca dejar un proceso o script repetible, déjalo documentado y ejecútalo una vez sobre los 16 idiomas en este lote; si necesita una clave o un gasto que no esté en el Llavero, déjalo listo y la card en «espera decisión» a jurgen con lo que falta.
5. Dudas reversibles: toma la opción recomendada y anótala en la card. Solo lo irreversible queda en «espera decisión» a jurgen.
6. Tickets nuevos de lo que encuentres, con su card.
7. Si hay cambio visible, capturas antes/después en `capturas/` del worktree y listarlas en el cierre.

## Qué NO hay que tocar
- marketing/ y Web/ (los lleva Lola).
- Ningún despliegue de esquema CloudKit a producción ni cambios en Supabase de producción.
- No desactivar tests ni saltarse protecciones de rama.

## Cómo se sabe que está bien
Las diez cards cumplen su «hecha cuando» (o quedan en in qa / espera decisión con motivo), suite unit en verde, PR a 2.2 en auto-merge, `/cerrar-total`.

## Gate después del CI del PR anterior
Arranca ya sobre `origin/2.2`. Justo antes del gate, si #626 (u otro PR de la cola) sigue en CI, espera a que entre y rebasea una sola vez con el simulador apagado. Si 2.2 no se movió, sigue. Si ese CI falla, no esperes: rebasea con lo que haya y sigue. Build y simulador después de ese rebase, una sola vez.

## Mini
Pipeline serial Yala: limpiar sims muertos / DerivedData de sesiones cerradas / cachés de XcodeBuildMCP de worktrees que ya no existen (sin preguntar); build con `xcodebuild -jobs 2` sin sim booteado; un solo simulador iPhone para tests; al cerrar apagar y borrar ese sim y el DerivedData de esta sesión. Disco: hay ~29 GB libres, por debajo del umbral APRETADO de 32 GB: limpia sin preguntar antes del build.

## Ritmo
Después de esta sesión entra una sesión interactiva con Jürgen que espera a que esta cierre. Ve directo: no alargues el lote con trabajo fuera de estas diez cards.

## Paso 0 — decisiones

> Resueltas en autónomo (bypass): las recomendaciones se dan por buenas. Se discuten en el PR.

**D1 · ¿Con qué se corre la revisión con Sonnet (card 8)?** → Con el CLI de Claude Code (`claude -p --model sonnet`), sin hooks (`--setting-sources project` desde una carpeta vacía) y sin herramientas.
Por qué: va con la suscripción, no necesita clave ni gasto de API y se repite igual antes de cada release. Alternativa descartada: la API con `~/Secrets/yala-ai-bench/anthropic.key` — es la clave del banco de IA, no consta que sean los créditos Startups, y costaría ~15-30 USD por corrida completa; el script la admite como `--backend api` para cuando Jürgen lo decida.

**D2 · ¿Qué revisa el LLM en cada idioma?** → Completo en es-419, en, de, fr, it, nl, pl, pt-BR, pt-PT, ja y zh-Hans; en en-GB, es-ES y es-AR solo sus overrides (lo que difiere del padre); es y pt solo la comprobación determinista de ser copia de su base.
Por qué: el respaldo de las variantes es copia del padre y revisarlo entero sería pagar dos veces lo mismo; pt-PT va entero porque su respaldo es el pt-BR viejo (card 7). Antes de cada release, `--since <tag>` revisa solo lo que cambió.

**D3 · ¿Qué claves no se tocan aunque la revisión proponga otra cosa?** → Las que la app empareja por texto con lo guardado (`qa/l10n-review/claves-protegidas.txt`: `category.other`, `subcategory.balanceAdjustment`, `subcategory.unassigned`, las de sistema de Grupos, los textos por defecto de avisos, `devseed.*`).
Por qué: cambiar su valor duplica categorías o deja de reconocer el texto por defecto. Los nombres de la siembra que solo se escriben una vez (p. ej. `subcategory.supermarkets`) SÍ se corrigen: el deduplicador funde por icono y color, no por nombre, así que no duplican; el usuario existente conserva el nombre que ya tiene.

**D4 · ¿Se aplican todas las propuestas del LLM?** → No. Se aplican automáticamente solo las de gravedad alta/media con placeholders idénticos y fuera de las protegidas; las de «significado» y «terminología» se miran por muestreo antes de aplicarlas en bloque. El resto queda en el informe.
Por qué: el LLM también se equivoca; un catálogo de 5.658 claves × 14 idiomas no se lee entero a ojo en un lote.

**D5 · Plurales de las variantes (card 1)** → Cada variante recibe su `.stringsdict` ENTERO (es-ES copia de es-419; es-AR con voseo, en-GB y pt-PT adaptados) y se quitan sus 80 líneas planas de plural. `variants_doNotCreateOwnStringsdict` (M4) se sustituye por el contrato inverso: la variante tiene todas las formas del padre.
Por qué: M4 evitaba duplicar los plurales suponiendo que la variante hereda del padre, y la regla de l10n mide que con la variante como idioma del sistema no hereda: la línea plana daba «1 seleccionados». Además las planas estaban viejas («transacciones» donde el padre ya dice «registros»). Alternativa descartada: conservar las planas y aceptar el plural para uno.

**D6 · es-419 (card 2)** → «Supermercados y bodegas» pasa a «Supermercados y tiendas»; «Alquiler o hipoteca» se queda. Perú no tiene variante propia, así que también ve el neutro.
Por qué: BRAND-VOICE §9 pide neutro latinoamericano y «bodega» es peruano; «alquiler» se entiende en toda Latinoamérica y «renta» se lee como impuesto en varios países. Alternativa descartada: una variante es-MX (§9.4: un cambio léxico no la justifica).

**D7 · Fechas cortas (card 3)** → Los `dateFormat` fijos de día-mes pasan a `setLocalizedDateFormatFromTemplate`; «MMMM yyyy» también. Donde la fecha vaya a un nombre de archivo o a un formato máquina, no se toca.
Por qué: la plantilla da el orden y las preposiciones de cada idioma.

**D8 · Sugerencias de Yala IA (card 4)** → Se manda al prompt el nombre visible del comercio con mayúscula inicial (misma regla que el chat), en vez del canónico en mayúsculas.
Por qué: arreglarlo en el dato no depende de que el modelo obedezca una instrucción más.

**D9 · Card 9, error de la foto** → `errorDescription` localizado y sin nombrar al proveedor («El servicio de IA no está configurado»).

**D10 · Qué queda para Jürgen** → Nada irreversible en este lote. La pasada nativa de pt-PT la hace Sonnet; si el informe deja dudas de vocabulario, van como card de visto bueno, no como bloqueo.
