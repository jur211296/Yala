---
name: generar-y-persistir-credenciales
description: Al guiar una rotación de credenciales, generar y guardar deben ser un solo paso; nunca dejar el valor viviendo solo en pantalla
metadata:
  type: feedback
---

En un paso a paso que genere una credencial, **generar y persistir van en el mismo
gesto**, antes de cualquier paso manual. Nunca dar "genera" como paso 1 y "guarda"
como paso 4: entre medias hay trabajo en una UI, y el valor vive solo en el
scrollback de una terminal.

**Why:** el 2026-08-31, rotando las cuentas de test del Supabase de staging, le di a
Jürgen ese orden. Generó las tres contraseñas, las pegó en el panel de Supabase y
las perdió antes de llegar al paso de guardarlas. Supabase solo guarda el hash, así
que no eran recuperables y hubo que re-rotar. La rotación en sí fue correcta —
verificado que las tres viejas ya no autentican— pero el acceso se perdió.

**How to apply:** escribe la credencial directamente a su fichero de destino (con
sus permisos ya puestos) y que el usuario la lea de ahí para pegarla donde haga
falta. Si el valor tiene que existir antes de que haya dónde guardarlo, crea el
destino primero. Y nunca la imprimas en el chat ni la leas de su terminal: se
genera a disco, y él la consulta.

Corolario útil: antes de asumir que una rotación fallida hay que rehacerla,
**verifica si se aplicó** — probar la credencial vieja contra el servicio distingue
"no se rotó" (puerta abierta, urgente) de "se rotó y perdimos el valor" (solo
acceso, sin prisa). Son dos problemas distintos y solo uno corre.
