# Barrido de QA de la 2.3 antes de la build 7 — 23-nov-2026

Lo mergeado en 2.3 desde la build 6 (37 PR, del de la política con Sentry al de Conecta tu IA), recorrido en el iPhone 14
real por Device MCP y en simulador. La clasificación de las 61 cards y los 64 tickets en QA está en
[`clasificacion.md`](clasificacion.md); la tanda para el iPhone de Jürgen, en
[`../tanda-qa-jurgen-2.3-barrido-antes-build-7.md`](../tanda-qa-jurgen-2.3-barrido-antes-build-7.md).

**Build probada:** Yala Dev desde `origin/2.3` con Salud financiera (PR 1138) y, desde las 13:05, con Conecta tu IA
(PR 1139). Instalada por cable/Wi-Fi en el iPhone 14 (iOS 27.2.1, en español de España) y en simuladores iOS 27.2:
iPhone SE (3.ª gen.) e iPad Pro 11 (M5). Datos sembrados con `-uitest-seed realista` y `tarjeta-limite-dos-monedas`.

**Evidencia:** `~/Claude/entregas/2026-11-23-barrido-qa-2-3-antes-build-7/evidencia/` (`iphone14/`, `se/`, `ipad/`).

## Lo nuevo desde la build 6, recorrido

| Qué | Dónde | Resultado | Qué se vio | Evidencia |
|---|---|---|---|---|
| Pantalla de éxito al guardar, siempre | iPhone 14 | Pasó | Cuatro guardados seguidos (del primero al cuarto): «Gasto guardado» con Editar, Favorito, Recurrente, Registrar otro y Aceptar en los cuatro. Los botones de abajo aparecen con un fundido de 0,3 s, a propósito | `iphone14/03-exito-1.png`, `04-exito-cuarto-guardado.png` |
| Favoritos en Nuevo registro («Ver todos» junto al rótulo) | iPhone 14 | Pasó | Guardar como favorito desde el éxito y usarlo en «Registrar otro»: el chip rellena todo | `iphone14/04-…` |
| Límite de la tarjeta y uso de línea en dos monedas | iPhone 14 | Pasó | Visa QA con S/ 1626.50 y $ 80: «38 % usado · S/ 3080.70 disponible de S/ 5000.00» (5000 − 1919.30). Cambiar el límite a 4000 en Editar cuenta lo pasa al momento a «48 % · S/ 2080.70 de S/ 4000». Igual en tema claro | `iphone14/11-…`, `13-…` |
| Salud financiera: hoja, nota y negrita | iPhone 14, SE, iPad | Pasó | Tres secciones con el estilo del Panel, cápsulas con fondo de tarjeta, «Lo que te queda» en la nota. La nota da 99 con un presupuesto pasado un 23 %: es la curva acordada («no desanimar», resta 4 a ese presupuesto) | `iphone14/02-…`, `se/02-…`, `ipad/02-…`, `03-…` |
| «Esto entendí» con la tarjeta B1 | iPhone 14 (seam de voz) | Pasó | Un registro incompleto: «Elige categoría» en naranja, «Guardar» apagado hasta elegirla; al guardar, «Guardado en Cuenta Principal» y el saldo baja S/ 25 | `iphone14/15-…`, `16-…` |
| Conecta tu IA: Ajustes › Tu IA | iPhone 14, SE, iPad | Pasó | En iCloud, la puerta «Primero, pasa tus datos a tu cuenta de Yala» con los pasos atenuados. Con la demo: Claude y ChatGPT conectados; «Desconectar» pregunta y quita a Claude. Yala Dev apunta al conector de staging y Yala a `mcp.yala-app.pe`, que responde 200 | `iphone14/17-…`, `se/05-…` a `08-…`, `ipad/05-…` |
| Cifras: Panel, Estadísticas, Flujo de caja y widget | iPhone 14 | Pasó | Sin plan: «Al 30 de noviembre tendrías S/ 59,459.43» en el Panel y en Tendencias. Con plan: «Terminas con ≈ S/ 59,273.47» en Flujo de caja y lo mismo en el Panel. Widget de Saldo: S/ 61,162 y ↑ S/ 5997, como el Panel; tras otro gasto, S/ 61,149 al volver al inicio | `iphone14/06-…` a `10-…` |
| «Lo que te falta pagar» y Compromisos | iPhone 14, iPad | Pasó | S/ 270 en el Panel, la hoja y Planificación | `iphone14/05-…`, `ipad/03-…` |
| Vaciar mis datos tocando el centro (card lplc) | iPhone 14 | Pasó | 3 de 3: abre «¿Vaciar tus datos?», nunca Exportar | `iphone14/23-…` |
| iCloud privado: «Eliminar mi cuenta» (card s591) | iPhone 14 | Pasó | Guion entero del ticket: entra en iCloud privado, cuenta y gasto, «Eliminar mi cuenta» › «Ya casi está» › reabrir: bienvenida; volver a entrar con el mismo Apple ID no ofrece restaurar nada y pregunta el nombre de cero | `iphone14/18-…` a `22-…` |

## Hallazgos

| Qué | Gravedad | Destino |
|---|---|---|
| «Te faltan pagar S/ 270.00 este mes» en la hoja de Salud financiera (español y español latino) | Texto | **Arreglado en este PR**: «Te falta pagar», como ya decía el argentino |
| Al entrar con iCloud privado tras reinstalar, la tarjeta del alta dice «En tu cuenta de Yala» (lee una sesión vieja del llavero) | Baja: solo el texto, pocos usuarios | Card nueva, media |
| Título «Presupues-tos» partido en el SE; signo del saldo «S/ -1626.50» y «-S/ 1626.50»; «Favorito» sin marcar al guardar desde un favorito; «S/» suelto al final de línea en «Tu mes en pocas palabras» | Detalles | Card nueva, baja |
| Con texto al máximo, la tarjeta de Salud financiera del Panel parte palabras («finan-ciera») | Accesibilidad (criterio de Jürgen: se confía en el código) | En la card de detalles |
| «Revisando qué hay en tu iCloud» tardó ~70 s en el iPhone 14 | Ya tiene ticket abierto | Sin cambio |

Descartados al medir: «A revisar» y «se ha pasado este periodo» son la traducción de España (el iPhone 14 está en es-ES);
«vs Oct 2026» es el «oct» español con mayúscula (decisión de la 2.2); el widget con datos del 20-nov era el widget recién
añadido, no la app; la nota de «Esto entendí» queda dentro del desplazamiento de la hoja.

## Lo que no se pudo recorrer

- **iPhone Duo:** el simulador del Duo no se puede crear en la Mini (su sistema no está instalado aquí; vive en la Max).
- **iPhone 14 girado:** tiene la rotación bloqueada en el Centro de control. El giro lo cubren `IPhoneLandscapeUITests`.
- **Device MCP gratis refleja un aparato**: el SE y el iPad se condujeron con `axe`, que en el SE no abrió Nuevo registro
  por etiqueta. Ese flujo quedó recorrido en el iPhone 14.

## Pruebas de interfaz

Ver la sección del mismo nombre en la tanda.
