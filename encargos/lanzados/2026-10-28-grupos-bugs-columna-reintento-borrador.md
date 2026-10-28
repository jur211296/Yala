# Grupos bugs: columna / reintento / borrador / siempre un admin

Cierre: **cierra-sola** → al terminar, `/cerrar-total`.
Versión **2.2**. Base `origin/2.2`. Esfuerzo: high.
Slug: `grupos-bugs-columna-reintento-borrador` · Sesión cola **S13** · al cerrar → **S14**.

## Encargo
Cumple **íntegramente** el brief de la sesión:

`~/Claude/tmp-frank/sesion-S13-grupos-bugs.md`

Léelo y ejecútalo tal cual, con sus cuatro briefs per-card (u8cl, y1ru, ouka, y1cd).

## Qué NO tocar
Lo que diga el brief. Además: no lanzar otras sesiones Yala; no tocar marketing/ ni Web/.

## Cómo se sabe que está bien
El criterio del brief + PR a 2.2 en auto-merge.

## Pie pipeline
- Base: `origin/2.2`. Una sesión Yala a la vez. Rebase único antes del PR.
- Pipeline serial Yala: (1) limpiar sims muertos, DerivedData y cachés XcodeBuildMCP de worktrees cerrados; (2) build `xcodebuild -jobs 2` sin sim booteado; (3) bootear 1 sim; (4) tests; (5) apagar y limpiar.
- Al cerrar: Frank publica digest y lanza la siguiente según `~/Claude/tmp-frank/siguiente-activo.txt` y `~/Claude/tmp-frank/cola-2-2-orden-activo.txt`.

## Paso 0

Decisiones tomadas sin preguntar (MODO cierra-sola), cada una con su porqué:

- **ouka**: el molde de 9o4n en los DOS caminos que borraban con la hoja montada (borrador de cuenta y puntero de
  subcategoría), no solo en el del brief: el segundo es la misma clase de bug. El enlace «¿Ya lo apuntaste?» con el gasto
  ausente también retira al cerrar.
- **y1ru**: reusar la zona solo con el MISMO nombre (recortado como el servidor) y la MISMA sesión; con el nombre cambiado,
  zona nueva (decisión recomendada del brief). `yala_group_exists` solo es éxito sobre una zona reusada.
- **u8cl**: las cuatro piezas, ninguna como «FALTA». La re-bajada de la subida pone a 0 solo el cursor de los grupos con
  fila local y corre antes del push: así no reabre la barrera del cursor tras «Empezar de cero» ni la pisa una página en
  vuelo (la regla del cursor de Grupos prohíbe el reset externo por esas dos vías). Sin apunte previo, el nivel de antes es
  2: ningún teléfono de hoy vuelve a bajar nada.
- **y1cd**: la causa del caso de Pia era el CLIENTE (`isOwner` local que el pull no corregía); el servidor ya la había hecho
  dueña y admin. Arreglo: `owned_groups` en el pull + `reconcileOwnership`. En servidor, `groups_forget_user` promueve
  heredero donde quien se borra era el último admin con cuenta (g25_01). No se re-engancha la membresía del borrado
  automáticamente: deshacería el borrado de privacidad; la salida es «el dueño invita sin fricción» (el brief la admite).
  SQL y Worker los despliega Jürgen; la app tolera el Worker viejo.
