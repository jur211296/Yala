---
name: el-barrido-qa-rinde-por-lotes
description: Cómo drenar tickets/qa/ sin quemar la sesión — agrupar por estado compartido, no por ticket; comparar números SIEMPRE dentro del mismo lanzamiento; y preferir el testigo aritmético a la captura
metadata:
  type: feedback
---

**Un barrido de `/qa` se organiza por ESTADO DE SIMULADOR compartido, no ticket a ticket. Y todo
número que compares tiene que salir del MISMO lanzamiento.**

**Why:** medido en el barrido del 2026-09-08 (10 tickets cerrados). Dos razones distintas:

1. **El relanzamiento es el coste dominante.** Cada `stop` + `launch` + siembra son ~40 s, y el
   ticket en sí suele resolverse en 3 taps. Agrupando por args, una sola pantalla de Ajustes de
   grupo cerró **tres** tickets (`groups-owner-debt-no-heir-dead-end`, `groups-shareable-summary`,
   `groups-budget`), y un solo arranque con `-uitest-force-update` dio el banner **y** la card de
   P&L cambiario, que era de otro ticket y de otra familia.
2. **Con `-uitest-reset` el corpus se REGENERA en cada arranque.** Estuve a punto de dar PASS a
   `distribution-balance-kpi-skips-fx` comparando el KPI del Panel de un lanzamiento con el hero de
   Distribución de otro. Coincidían —73.526,45 las dos veces— y aun así la comparación no valía
   nada: eran dos corpus. Es la misma familia que [[la-asercion-que-no-puede-fallar]], pero por el
   lado de los datos en vez del de la aserción.

**How to apply:**

- **Antes de empezar, agrupa los tickets por `-uitest-seed` + flags.** Los perfiles de grupos
  (`grupos`, `grupos-pendiente`, `grupos-saldado`, `grupos-sin-flag`, `grupos-invitado`) son
  excluyentes entre sí, así que ahí el lote lo marca el perfil; los de Panel/Estadísticas/Registros
  comparten `realista` y se recorren sin relanzar, cambiando de pestaña.
- **Dos números que se comparan se leen sin relanzar en medio.** Y si el ticket habla de períodos
  («Este mes» y «Mes pasado»), recórrelos los dos: el régimen del cálculo puede cambiar entre un
  período que cubre hoy y uno cerrado, y con «Todo el tiempo» esa diferencia no se ve.
- **Prefiere el testigo que solo puede salir si el arreglo está puesto.** Lo mejor del barrido no
  fueron las capturas sino tres cuentas: `8.132,00 ÷ 31 = 262,32` (con el bug daría 271,07);
  `2.000 × (3,66 − 3,70) = −80,00`; y los netos del resumen de grupo cuadrando con la cabecera. Una
  captura demuestra que algo se pintó; una cifra que solo cuadra con el denominador correcto
  demuestra **cuál** de las dos ramas corrió.
- **La ausencia en el árbol de accesibilidad es una aserción de primera.** «Eliminar grupo» aparece
  como texto y **no** como botón ⇒ está deshabilitado. Tras tocar una tarjeta bloqueada,
  `group_members_button` **no existe** ⇒ el detalle no se montó. El cover de forzado **no expone**
  ningún botón de cierre ⇒ es terminal. Eso es más fuerte que mirar un pixel, y sale gratis del
  `snapshot_ui` que ya tienes.
- **La automatización no puede con todo, y hay que distinguirlo de un bug.** Los `NavigationLink`
  del formulario de cuenta (`AccountFormView.swift:250`) no responden al tap sintético. Lo separé de
  un fallo de la app con dos controles: el campo de texto de la misma pantalla **sí** acepta
  escritura, y el **otro** `NavigationLink` del mismo formulario tampoco abre. Cuando eso pase, no
  lo persigas: anótalo, abre ticket con lo que bloquea, y sigue por otro camino.

**Y el residuo del barrido vale tanto como los PASS.** Lo que Jürgen usa no es la lista de cerrados
sino **la cola que le queda**, agrupada por lo que de verdad la bloquea (APNs real, sign-in real,
RPC de producción, dos teléfonos) y separada de lo que solo *parecía* necesitar un teléfono. Ver
[[la-premisa-del-encargo-tambien-se-mide]] y [[cierre-board-tickets-y-hallazgos]].
