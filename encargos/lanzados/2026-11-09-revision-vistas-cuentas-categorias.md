---
esfuerzo: high
toca: docs/ux/revision-vistas-2.3/39-cuentas-categorias/
release: no
---

# Revisión por vistas 2.3 · Cuentas, tarjetas, categorías, etiquetas y divisas

## Contexto
Viene de la cola del 7-nov-2026 que Jürgen pausó ese día a las 12:42 Lima; el 9-nov-2026 la confirmó en la nueva cola oficial («las revisiones y la consolidación de revisiones»). Las revisiones por vistas 2.3 de las otras zonas ya están mergeadas en 2.3 (PR #846, #847, #848, #852, #853, #856, #859, #860; revisión del usuario nuevo PR #837). Esta sesión no ve nada más que este encargo.

Rama base: origin/2.3 en jur211296/Yala. Un solo PR de documentación a 2.3 y un solo cierre: termina con `/cerrar-total`. Cierre autónomo (cierra-sola). Commits y PR sin firma de IA. NO cambies código de la app, tests, gateway, auth, producción, marketing/, colas ni sesiones: es revisión y prototipo de UX, sin cambios funcionales ni merge de funcionalidad. Sin publicación pública, hosting nuevo ni compras. Da siempre una descripción corta en español a cada comando Bash. Dudas no vitales: resuélvelas con la opción recomendada y anótalas con alternativas en el cierre; nada de seguridad o producto crítico sin Jürgen. Justo antes del PR: `git fetch` y un solo rebase sobre origin/2.3.

Simuladores: puedes y debes usarlos para capturas actuales con datos ficticios. En la Mini, tope 1; en la Max, tope 2 (puedes abrir un segundo aunque otra sesión de otro proyecto use uno) o el iPhone 14 por DeviceMCP. Build `xcodebuild -jobs 2` sin sim encendido, luego bootear, capturar, apagar y borrar solo lo que encendiste (simuladores, DerivedData propio, temporales). No toques recursos de otras sesiones.

## Qué se pide
### Vistas y estados a revisar (lista cerrada)
AccountFormView, AdjustmentModeSelectorView, AccountsSettingsListView, CategoriesSettingsListView, CategoryDetailView, SubcategoryDetailView, SubcategoryNeedSelectorView, TagsSettingsListView, TagFormView, CurrencySettingsView.
Caso guía: Ajustar el saldo de una cuenta, archivar una tarjeta, reordenar y renombrar categorías, crear una etiqueta, cambiar la divisa preferida.

### Método (igual en todas las revisiones por vistas)
1. Lee el estado actual en origin/2.3 de cada vista listada (lectura focalizada, sin auditoría general) y la revisión del PR 837 (`docs/ux/revision-usuario-nuevo-2026-11/`): reutiliza sus fricciones si aplican a esta zona, sin duplicar la guía visual del usuario nuevo. Lee el mapa de cobertura `/Users/jur/Claude/flota/cobertura-vistas-yala-2.3.md` y revisa SOLO tu zona.
2. Capturas actuales en simulador (iPhone; iPad y texto grande donde aplique) de cada vista y estado: vacío, con datos, cargando, error, sin permisos/sin conexión, según la vista.
3. Revisión adversarial con los siete perfiles SIMULADOS del PR 837 como lentes (no entrevistas): ¿se entiende?, ¿es clara?, terminología, jerarquía, encontrabilidad, carga cognitiva, cantidad de pasos, errores, accesibilidad (VoiceOver, texto grande), iPad.
4. Eficiencia técnica: recomputaciones, cargas, scroll y rendimiento. Separa medido (con cómo se midió) de hipótesis. Ninguna cifra inventada, ningún refactor.
5. Para cada problema prioritario: 3-5 alternativas con MAQUETAS DE PANTALLA de iPhone con el estilo de Yala, distinguibles, con el mismo caso y datos ficticios rotulados; secuencias de 2-4 pantallas si es conducta. Nada de tablas o texto disfrazados de maqueta. Recomendación justificada con tradeoffs; decide Jürgen.
6. Entrega en `docs/ux/revision-vistas-2.3/<tu-subdir>/`: HTML ligero portable (imágenes livianas, sin un único archivo gigante) + PDF VISUAL de respaldo + `ficha.md` corta (vistas cubiertas, problemas, recomendación, decisiones para Jürgen). NO edites ningún índice común.
7. Verifica visualmente el HTML a tamaño teléfono y escritorio en un navegador (Playwright o Chrome) y corrige legibilidad, imágenes y controles.
8. Cierre: rutas absolutas de HTML/PDF, capturas del artefacto probado, link del PR, «Saltado o asumido sin preguntar» y decisiones pendientes. Card a `in qa`.

## Qué NO hay que tocar
- Código de la app, tests, gateway, auth, producción, marketing/, colas ni sesiones: es revisión y prototipo de UX, sin cambios funcionales.
- Ningún índice común de `docs/ux/revision-vistas-2.3/`: solo tu subcarpeta.
- Sin publicación pública, hosting nuevo ni compras; nada de datos reales (solo datos ficticios en simulador).
- Commits y PR sin firma de IA (nada de «Generated with Claude Code», «Co-Authored-By» ni enlaces de sesión).

## Cómo se sabe que está bien
Cada vista listada tiene capturas actuales, problemas priorizados y, para los prioritarios, 3-5 maquetas comparables; HTML+PDF verificados en teléfono y escritorio; un PR de documentación en 2.3; card en in qa; `/cerrar-total`.

## Paso 0 — decisiones

> Resueltas en semiautónomo por Frank: las recomendaciones se dan por buenas. Se discuten en el PR.

**D1 · ¿Sobre qué base?** → La rama del encargo se recreó desde `origin/2.3` (había nacido de `2.2`, sin commits propios).
Por qué: el encargo pide revisar 2.3 y abrir el PR a 2.3. Alternativa descartada: rebasar al final, que habría revisado código de 2.2.

**D2 · ¿Dónde se entrega?** → `docs/ux/revision-vistas-2.3/39-cuentas-categorias/`, sin tocar el `README.md` común.
Por qué: el número y el nombre salen del mapa de cobertura. Alternativa descartada: ampliar el índice común, que el encargo prohíbe.

**D3 · ¿Con qué herramienta se generan HTML, maquetas y PDF?** → El generador de la zona 38 (`fuente/build.py`, `ui.py`, `problemas_*.py`) copiado y adaptado a esta zona.
Por qué: mismo estilo y misma navegación que las otras nueve zonas, y ya probado en móvil y escritorio. Alternativa descartada: un generador nuevo, que haría la zona 39 distinta de las demás.

**D4 · ¿Cómo se sacan las capturas?** → Un conductor XCUITest temporal (`Revision39CapturasUITests`), que no se commitea en `YalaUITests/`: va como `.txt` en `fuente/`. Semillas que ya existen (`tarjeta-dos-lineas`, `sin-registros`, `realista`, `sin-categorias`); sin parche de semilla.
Por qué: el encargo prohíbe tocar tests y código; las semillas existentes cubren cuentas con tarjeta en dos monedas, categorías, etiquetas y vacíos. Alternativa descartada: parchear la semilla, que solo añadiría nombres más bonitos.

**D5 · ¿Qué simuladores?** → Uno propio a la vez (Mini: tope 1): un iPhone 17 Pro y luego un iPad Pro 13 creados para esta sesión, y borrados al cerrar. El iPhone 17 Pro compartido y «Yala Ficha iPad Pro 13» no se tocan.
Por qué: el encargo pide borrar solo lo que se encendió. Alternativa descartada: usar los existentes, que son de otras sesiones o de marketing.

**D6 · ¿Qué caso y qué persona?** → Lucía (ficticia), con una cuenta de ahorros, una tarjeta Visa en soles con línea en dólares, las 11 categorías sembradas, 5 etiquetas y soles como moneda principal. Mismo caso en todas las maquetas, rotulado como ficticio.
Por qué: el caso guía del encargo (ajustar saldo, archivar tarjeta, reordenar y renombrar categorías, crear etiqueta, cambiar divisa) cabe entero en esos datos.

**D7 · ¿Hallazgos que son bugs?** → Van como «secundarios» en la ficha, con su línea de código; no se abren tickets ni cards nuevas.
Por qué: el encargo limita la escritura a la subcarpeta. Alternativa descartada: un PR de tickets aparte, como hizo la zona 38, que Jürgen puede pedir después.

**D8 · ¿Las decisiones de cola pendientes de incorporar (ADR-082)?** → No aplican a este repo: son de la cola de Frank, no de producto ni de código. Se dice en el cierre; no se borran.
