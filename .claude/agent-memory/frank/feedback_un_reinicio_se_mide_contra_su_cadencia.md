---
name: un-reinicio-se-mide-contra-su-cadencia
description: Elegí «racha consecutiva» sobre «acumulado» sin contar cada cuánto llega el evento que reinicia — con el re-kick de 30 s, el techo de 15 min se volvía inalcanzable y el desenlace pasaba a 72 h.
metadata:
  type: feedback
---

Cuando un contador **se reinicia** con algún evento, el diseño no está decidido hasta que cuentas **cada cuánto llega
ese evento** en la realidad. Un reinicio barato puede volver el umbral inalcanzable sin que ninguna línea de código
parezca mal.

**Why:** el 2026-09-22, implementando el reloj por causa del techo previo al montaje, elegí una **racha consecutiva**
—cualquier observación con otra causa, o sin causa, la reinicia— porque era un campo menos de schema y porque
«reinicia hacia más reintentos» sonaba conservador. La review midió lo que yo no medí: la pantalla de Almacenamiento
re-kickea **cada 30 s** (`StorageSettingsView`, `if tick % 30 == 0`), así que con una cuenta suspendida y cobertura
intermitente basta **un** timeout de red cada quince minutos para que los 900 s no lleguen nunca. El techo corto se
volvía inalcanzable y el desenlace pasaba de 15 min a **72 h** — y era *peor cuanto más miraba la persona la
pantalla*, porque más observaciones significan más oportunidades de intercalar un hueco.

La salida fue un **acumulado con pausa** (tres campos: causa, inicio del tramo abierto, acumulado en tramos cerrados):
una observación sin causa CIERRA el tramo y conserva lo acumulado. Un hueco no prueba que el motivo se fuera, solo que
no se pudo preguntar, así que no cuenta ni a favor ni en contra.

**Y la decisión de Jürgen ya lo decía.** Su encargo era «el techo corto solo cuenta **tiempo acumulado** bajo ESA
causa». «Acumulado» es literalmente el acumulador; yo lo leí como «consecutivo» porque era lo barato. Es la familia
de [[feedback_la_premisa_del_encargo_tambien_se_mide]], pero al revés: aquí el encargo acertaba y **mi Paso 0 lo
interpretó a la baja**.

**How to apply:** ante cualquier ventana, racha, contador con reinicio o debounce, antes de elegir el reinicio:

1. **Cuenta la cadencia del productor.** ¿Cada cuánto se observa? Aquí, `MigrationForegroundRekick` cada 30 s, más
   boot y tap. Grepea el timer, no lo supongas.
2. **Divide el umbral por la cadencia**: 900 / 30 = **30 observaciones seguidas** sin un solo hueco. Escrito así, se
   ve solo que es una condición fuerte, no una formalidad.
3. **Pregunta quién puede intercalar un hueco**, y si eso es frecuente en el mundo real. Un timeout de red lo es.
4. Si la respuesta incomoda, **pausa en vez de reiniciar**: es un campo más de schema y compra que el mecanismo
   funcione en condiciones normales, no solo en el laboratorio.

Y el corolario que vale para toda esta familia: **un umbral que nunca se alcanza no falla en rojo**. La app se
comporta «bien» —espera—, ningún test de lógica lo ve y el síntoma es una espera larga que se atribuye a otra cosa.
Es el modo de fallo silencioso de [[feedback_el_techo_que_se_resetea_no_es_un_techo]], con un disparador corriente.

Relacionado: [[feedback_antes_de_poner_techo_mide_que_la_espera_existe]], [[feedback_una_ventana_dura_lo_que_su_reintento]],
[[feedback_el_estado_compartido_no_es_testigo_de_su_rama]].
