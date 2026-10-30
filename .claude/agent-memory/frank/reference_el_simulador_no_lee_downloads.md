---
name: el-simulador-no-lee-downloads
description: Un test en el simulador que lee ~/Downloads se queda colgado al 0 % de CPU (permiso de macOS), sin error; copia el archivo a /private/tmp antes
metadata:
  type: reference

---

Medido el 2026-10-29 (S27m): un test de `YalaTests` que copiaba un archivo de `/Users/jur/Downloads` se quedó
colgado más de 8 minutos con la app al **0 % de CPU** y sin ninguna línea de error: macOS pide permiso para leer
Descargas y nadie lo concede. Con el archivo copiado antes a `/private/tmp/claude-501/<carpeta>/`, el mismo test
pasó en 9,5 s.

**How to apply:** para probar en local un archivo real del usuario, cópialo desde el shell a `/private/tmp/…`, apunta
el test temporal ahí (sin commitearlo) y borra la copia al acabar. Un test colgado al 0 % no es lentitud: mira
qué ruta lee. Relacionado: [[instrumentar-gana-a-razonar]].
