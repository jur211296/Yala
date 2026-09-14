---
name: el-tramo-sin-acotar-lo-cumple-el-vecino
description: Un source-scan que recorta desde un marcador hasta el FINAL del cuerpo se cumple con el case de al lado; el tramo se acota por su fin, y quien lo destapa es el mutante, no la lectura
metadata:
  type: feedback
---

Cuando un source-scan recorta «desde este `case` en adelante», **acótalo también por su FIN** — el `case`
siguiente, o el cierre del bloque. Un tramo abierto hasta `cuerpo.endIndex` lo satisface cualquier
hermano de más abajo.

**Why:** el 14-sep escribí `let ramaVuelve = String(cuerpo[vuelve.upperBound...])` para fijar que una
rama de un `switch` usaba el aviso de dos botones. El mutante que la cambiaba por el de un botón y dejaba
el de dos en un `case` de relleno debajo **salió VERDE**. La aserción decía «la rama que vuelve ofrece
reintentar» y medía «el token aparece en algún sitio de la propiedad». Es la misma familia que
[[feedback_el_source_scan_de_dos_literales_no_es_una_red]] y
[[feedback_la_asercion_que_no_puede_fallar]], pero por una vía distinta: no falla el literal, falla el
RANGO.

**How to apply:** al escribir el recorte, la pregunta es «¿qué otro código cae dentro de este tramo?».
Con `switch` el fin es `cuerpo.range(of: "\n        case ", range: desde..<fin)` y el `?? endIndex` solo
para el último. Y el mismo defecto tiene un gemelo por el otro lado: un `??` de respaldo que hace casar
un marcador que no existe —`range(of: rama) ?? range(of: "switch …")`— convierte el tramo en el cuerpo
entero sin que nadie se entere.

**Y el método:** esto no se ve leyendo el test. Lo destapó el mutante en la primera pasada. Un test nuevo
de source-scan **no está terminado hasta que un mutante lo pone en rojo** — y el mutante tiene que
COMPILAR: mi primer intento metía un `case` inexistente y el «TEST FAILED» era del compilador, que se lee
igual que un rojo de test y no prueba nada ([[feedback_mis_mediciones_fallan_por_el_filtro]]).
