---
name: exenciones-staging-allowlist
description: Las 4 exenciones que puse en la allowlist de secretos tapan el patrón «par clave/valor» en los tests E2E de staging; hay que retirarlas cuando el ticket saque las credenciales al entorno
metadata:
  type: project
---

**En `~/.claude/hooks/secretos-permitidos.txt` hay 4 exenciones vivas** sobre el patrón
`par clave/valor` en:

```
YalaTests/CloudSync/{CloudAccountClaim,CloudSync,MigrationCutover,PrefsSync}E2EStagingTests.swift
```

**Why:** hasta el 2026-08-31 esos 4 hallazgos bloqueaban **todo** push mío desde `~/Yala` —el
hook escanea `git ls-files` entero, no el rango que se empuja (ver
[[hook-secretos-disparador-substring]])—, y estaban sin eximir a propósito porque eran
credenciales vivas. Ese día Jürgen **rotó** las cuentas de test (`i5-user-a`, `i5-user-b`,
`i5-user-c` del Supabase de staging) y confirmó que **no actualizó el árbol**: lo que sigue
escrito ahí son las contraseñas antiguas, que ya no autentican. Una credencial muerta no es un
secreto, que es lo que esa lista significa — así que con su permiso explícito las eximí, acotadas
al patrón y nunca al fichero. Sin eso, el PR #52 no habría podido subir.

**How to apply:** la exención es un **punto ciego mientras dure**. Si alguien escribe ahí las
contraseñas nuevas, el hook ya no las verá: quien lo haga tiene que borrar esas 4 líneas primero.
La salida definitiva es el ticket `staging-test-credentials-in-public-repo` —sacar las
credenciales al entorno—, y **las 4 líneas se retiran en ese mismo movimiento**, no después. Si
lo dejas para «luego», el punto ciego se queda.

**Ojo con los tests:** los 4 hacen login por password-grant, así que contra credenciales rotadas
**fallan**. No hay rojo en CI porque llevan guarda `@Test(.enabled(if:))` sobre
`YALA_CLOUD_E2E == "1"` y CI no define esa variable — sólo revientan si alguien los lanza a mano.

**Caduca cuando el ticket se cierre.** Si ves que la allowlist ya no tiene esas 4 líneas, borra
esta nota en vez de arrastrarla.

**Y una de método:** no pude verificar la rotación por mi cuenta —intenté el password-grant y el
clasificador lo bloqueó, con razón—, así que todo esto descansa en la palabra de Jürgen. Cuando
una comprobación no se puede hacer, se dice; no se presenta como medida.
