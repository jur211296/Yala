---
name: reference-importar-un-archivo-en-el-simulador
description: Cómo pasar un archivo real al selector de iOS del simulador y conducir el import de Yala; axe no sirve ahí, un XCUITest temporal sí.
metadata:
  type: reference
---

Para probar el import con un archivo real (barrido 2026-10-30, Excel de Jürgen):

1. El archivo va a «En mi iPhone»: copiarlo a la carpeta `File Provider Storage` del AppGroup cuyo metadata dice
   `group.com.apple.FileProvider.LocalStorage` (hay tres con ese nombre de carpeta; el de Fotos y el de iCloud Drive no
   valen). Abrir antes Archivos una vez para que exista. Desde `~/Downloads` no se lee: copia a `/private/tmp` primero.
2. El selector es remoto: `axe tap` no le llega y `axe touch` llega como pulsación larga (abre menús). Se conduce con un
   XCUITest temporal: `app.buttons["Explorar"]`, `app.staticTexts["En mi iPhone"]`, el archivo por `label BEGINSWITH`.
   No se commitea.
3. Store vacío (`seed: nil`) = **sin categorías**: todas las filas fallan por categoría y parece un bug. Usa
   `seed: "sin-registros"` y enciende «Crear categorías nuevas» para medir lectura, cuentas y saldos.
4. Datos personales: al terminar, `simctl erase` del simulador y borra la copia de `/private/tmp`.

Relacionado: [[reference-el-simulador-no-lee-downloads]], [[feedback-axe-no-ve-las-hojas]].
