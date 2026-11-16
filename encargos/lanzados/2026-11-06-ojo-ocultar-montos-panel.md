# Ojo para ocultar montos en el Panel
toca: Panel (ocultar montos)

Rama base: origin/2.3. Un solo PR contra 2.3, un solo cierre. Máquina: la libre. Simulador OK. Cierre autónomo. Termina con `/cerrar-total`.

## Contexto
Card: «Ojo para ocultar montos en el Panel» (tablero-ojo-para-ocultar-montos-en-el-panel-kzvm). Relacionada con «Ocultar montos con un botón» — no dupliques; un solo control en Panel.

## Qué se pide
Botón/ojo en Panel que oculte/muestre montos; persiste en la sesión o preferencia local según el patrón ya usado en la app. Capturas. `tablero` → in qa. `preguntar-bot` si hay dos cards hermanas en conflicto.

## Qué NO hay que tocar
marketing/.

## Hecha cuando
Card in qa; gate verde; `/cerrar-total`.

## Paso 0 — decisiones

> Resueltas en autónomo (bypass): las recomendaciones se dan por buenas. Se discuten en el PR.

**D1 · ¿Las dos cards («Ojo para ocultar montos en el Panel» y «Ocultar montos con un botón») chocan?** → No: piden lo mismo. Un solo control en el Panel cierra las dos; las dos pasan a QA.
Por qué: la segunda nace del análisis de competencia como «ocultar montos, quick win», sin pantalla; la primera la concreta en el Panel. Alternativa descartada: preguntar al bot (no hay conflicto que decidir).

**D2 · ¿Dónde va el ojo?** → A la derecha de la cifra grande del Panel (como en las apps de banco).
Por qué: está al lado de lo que oculta y no suma un botón más a una barra que en el Duo ya desborda. Alternativas descartadas: botón en la barra de arriba (ya lleva bandeja, filtros, configurar y avatar) y junto al rótulo «Balance del período» (probado en el simulador: en un iPhone 17 Pro apartaba «Ver detalle»).

**D3 · ¿Persiste?** → Sí, preferencia local del teléfono en `AppPreferences` (`panelAmountsHidden`, no sincronizada).
Por qué: quien oculta montos para usar la app en público espera encontrarlos ocultos al volver a abrirla; es el patrón de las preferencias persistentes. No se sincroniza: es privacidad de un aparato concreto. Alternativa descartada: solo en la sesión (se perdería al cerrar la app).

**D4 · ¿Qué se oculta?** → Toda cifra de dinero del contenido del Panel: hero, píldoras, cuentas, widgets, ejes y etiquetas de gráficas. Se queda: forma de las gráficas, porcentajes, variaciones en %, conteos.
Por qué: un porcentaje no dice cuánto hay. Alternativa descartada: ocultar también porcentajes (el Panel quedaría vacío de lectura).

**D5 · ¿Las hojas que se abren desde el Panel (detalle de cuenta, de registro…) también ocultan?** → No.
Por qué: abrir el detalle es pedir verlo, y el alcance pedido es el Panel. Alternativa descartada: propagarlo a toda la app (eso sería otra card: Registros, Estadísticas, formularios).

**D6 · ¿Cómo se ve un monto oculto?** → El símbolo de la moneda y `•••••`, siempre del mismo largo; VoiceOver dice «Monto oculto».
Por qué: el ancho no delata la magnitud, y el símbolo sigue diciendo en qué moneda está. Alternativa descartada: la redacción gris del sistema (`privacySensitive`), que conserva el ancho de cada cifra.
