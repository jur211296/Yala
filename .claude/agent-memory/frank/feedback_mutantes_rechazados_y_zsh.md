---
name: mutantes-rechazados-y-zsh
description: Una orden de mutantes rechazada puede haber escrito ya el mutante, y en zsh `for f in $FILES` no parte la lista: la copia y la restauración fallan en silencio
metadata:
  type: feedback
---

Al mutar código para probar un test: (1) si la orden se rechaza o se corta, **comprueba el árbol con `git diff`** antes de seguir: el 2026-11-04 una orden rechazada ya había aplicado el mutante (`settleFreshInstallNeutralMount` sin arma) y la restauración del final nunca corrió; se compiló y se corrieron XCUITest encima. (2) **En zsh `for f in $FILES` itera UNA vez con la cadena entera**: la copia de seguridad falló, la restauración también, y los cuatro mutantes quedaron en el árbol hasta revertirlos a mano.

**Why:** dos sustos en la misma sesión (lote N1 de la 2.3); ningún error visible salvo un `cp: … No such file`.

**How to apply:** mutantes con un array (`files=(a b c); for f in "${files[@]}"`) o con un script python que guarde y restaure en `try/finally`; y tras cada tanda, `git diff --stat` contra el número de líneas esperado. Ver [[un-mutante-muere-y-el-termino-sobra]].
