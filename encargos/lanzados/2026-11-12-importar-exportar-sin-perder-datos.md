Yala
# Importar y exportar sin perder datos: miles, signo menos, CSV y campos que se pierden
---
card: tablero-una-comilla-suelta-se-traga-filas-y-el-c-6gh7
toca: Yala/App/Logic/, Yala/App/Views/Import/, Yala/App/Views/ExportWizard/, YalaTests/
esfuerzo: high
cierre: cierra-sola
---

Base: origin/2.3 en jur211296/Yala (2.2 está publicada: no se toca). Un solo PR a 2.3. Commits y PR sin firma de IA. No tocar producción, datos reales, marketing, trabajo de otras sesiones ni colas. Antes de actuar, revisa PRs mergeados y abiertos y el tablero: si algo ya está hecho, verifícalo y documéntalo sin duplicar. Justo antes del gate: git fetch y un solo rebase sobre origin/2.3. Simuladores: en la Max puedes usar un segundo simulador (además del de otra sesión) o el iPhone 14 por DeviceMCP; en la Mini, uno. Da siempre una descripción corta en español a cada comando Bash. Si te falta un acceso, credencial o decisión fuera de tu autoridad, no lo saltes ni lo inventes: márcalo con `BLOQUEANTE:` y sigue lo posible.

Dependencias: si otra sesión viva toca las mismas carpetas, ponte al día con origin/2.3 antes del gate y conserva el trabajo de las dos ramas; no reviertas lo de otra sesión.

## Contexto
Jürgen aprobó el 12-nov meter el lote de Importar en 2.3. Hoy el import lee mal números y archivos comunes, y exportar e importar pierde datos. Las fichas completas están en el repo; léelas, porque mandan sobre este resumen:
- `tickets/backlog/import-reads-thousands-as-decimals-and-drops-the-unicode-minus.md` (prioridad alta)
- `tickets/backlog/csv-import-silently-swallows-rows-and-only-reads-utf8.md`
- `tickets/backlog/export-import-lose-time-manual-rate-and-nature.md`
- `tickets/backlog/export-import-carry-record-kind-and-transfer-pair.md`: inclúyela solo si comparte el mismo cambio de formato y no agranda el lote; si no, déjala anotada para otro lote.

## Que se pide
1. Separadores de miles y decimales bien interpretados (1.234,56 y 1,234.56) y el signo menos Unicode reconocido.
2. Una comilla suelta no se traga filas; las filas que no se pueden leer se cuentan y se muestran, no desaparecen en silencio; se aceptan archivos que no son UTF-8 (por ejemplo Latin-1 o Windows-1252, típicos de bancos y Excel).
3. Exportar e importar conserva la hora, la tasa de cambio manual y la naturaleza del movimiento, con compatibilidad hacia atrás para archivos exportados antes.
- Textos en español neutro con «tú» (docs/planning/BRAND-VOICE.md), y en los demás idiomas de la app.
- Un test de regresión por punto que falle sin el arreglo. Review adversarial obligatoria. Gate del proyecto en verde.
- Haz tú el QA en el simulador o en el iPhone 14 con archivos de prueba reales (sin datos personales), con capturas antes y después en `capturas/` del worktree, y mueve las fichas y la card a done con evidencia.

Presupuesto de pruebas de interfaz:
  - Corre solo las pruebas que toca el cambio; la suite completa, una sola vez al final.
  - Si una prueba falla 2 veces por timeout, anótala como inestable en el cierre y sigue.
  - Tope total de 30 min en pruebas de interfaz; al llegar, checkpoint o pregunta según el modo.
  - Ninguna espera de más de 3 min sin escribir avance (qué corre, cuánto lleva); nada de bucles de 10 min ni comandos que se pasen del límite y queden en segundo plano a ciegas.
  - Antes de compilar en iOS mira la carga: si otra sesión compila con xcodebuild en la misma máquina y la carga pasa los núcleos, espera en tramos cortos con aviso, no en paralelo.

## Que NO hay que tocar
Grupos, modo nube y la Bienvenida. Nada de rediseñar la pantalla de importar: solo lo necesario para mostrar las filas no leídas.

## Como se sabe que esta bien
Los tres puntos con test que falla sin el arreglo, QA con evidencia, gate verde, PR mergeado a 2.3.

Cierre: cierre autónomo (cierra-sola) con `/cerrar-total` solo si el trabajo queda completo y el modo de la sesión lo permite. En modo nocturno, una decisión vital se preserva con checkpoint recuperable y card «Espera decisión» para Jürgen, sin mergear lo incompleto.

## Paso 0 (Frank, 2026-11-12 21:05, nocturno, decisiones auto-contestadas)

1. **Punto 1 (miles, decimales, «−») ya está en 2.3**: lo hizo el PR de «montos por archivo» (#692, 30-oct; `ImportAmountParser`). La ficha quedó en backlog porque la auditoría entró después. No se rehace: se verifica con sus tests, se añade el test de regresión que falte y la ficha pasa a done con esa evidencia.
2. **Ficha 4 (`kind` + `transfer_id`) fuera**: no comparte el cambio de formato (saldo inicial que fija la cuenta, emparejar entre monedas). Queda anotada para otro lote.
3. **Comillas**: una `"` solo abre al principio del campo, también al partir filas (mismo criterio que `splitCSVFields`). Una comilla de apertura sin cierre hasta el final del archivo no se traga el resto: esa fila se lee sola y sale como no leída.
4. **Filas no leídas**: una línea con texto y sin separador ya no se salta: sale en «filas que no entraron» con su número (error nuevo). El número de fila es la línea física del archivo (las líneas en blanco ya no lo desplazan).
5. **Codificación**: UTF-8 → UTF-16 con BOM → Windows-1252 → ISO Latin-1. **Separador**: `,` `;` o tabulador, el que más aparezca en la cabecera.
6. **Columnas nuevas del export, al final** (las de siempre conservan su posición), activas por defecto: `time` (HH:mm:ss, hora local), `exchange_rate` + `rate_currency` (solo si la moneda ≠ la preferida y la tasa no es provisional), `need` (solo si la persona cambió la naturaleza del registro; `essential`/`priority`/`optional`/`unclassified`).
7. **Import**: las tres opcionales. `time` (o la hora dentro de la celda de fecha) fija la hora local; sin hora, mediodía UTC como siempre. `exchange_rate` se respeta como tasa fija si `rate_currency` (o, sin ella, nada) es la moneda preferida del teléfono; si es otra, se convierte como siempre. `need` acepta los códigos ingleses, los valores internos y el nombre en el idioma de la app. Un valor que no se entiende deja la fila fuera con su motivo (no se pierde en silencio).
8. **Textos**: 4 errores nuevos + 6 de columnas del asistente, en los 16 idiomas (es y pt por copia de su base).
