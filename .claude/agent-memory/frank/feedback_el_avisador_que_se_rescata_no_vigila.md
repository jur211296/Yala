---
name: el-avisador-que-se-rescata-no-vigila
description: Un mecanismo con canal de respaldo sale VERDE el día que su canal muere — si su trabajo es detectar esa muerte, el respaldo lo anula; y `always()` en un job de aviso lo dispara al cancelar el run A MANO
metadata:
  type: feedback
---

**Cuando añadas un canal de respaldo a un aviso, pregúntate si ese aviso existe para detectar que
el canal principal cayó. Si es que sí, el respaldo lo ciega: hay que desactivarlo ahí.**

**Why:** el 2026-09-09 escribí un `ping-avisador.yml` cuyo trabajo era comprobar a diario que el
webhook del CI respondía. Le puse el mismo respaldo que a los demás avisos —si el webhook falla,
el aviso queda en un issue y el paso sale con 0—. Resultado: **el ping salía VERDE justo el único
día que importaba**, y encima dejaba un comentario diario «NO requiere ninguna accion» en el issue
donde se acumulaban los avisos de verdad. Su propia cabecera decía «falla con su propio nombre», y
no fallaba. Un vigilante que se rescata a sí mismo no vigila nada.

Lo cazó una lente adversarial, no yo, y era el hallazgo que **anulaba el workflow entero**.

**How to apply:**

- Separa los dos papeles. Un aviso que **transporta contenido** (los tests fallaron, no hay
  cobertura) quiere respaldo: lo que entrega importa más que el canal. Un aviso cuyo **contenido
  es el estado del canal** no lo quiere: su rojo *es* la señal.
- Hazlo un interruptor explícito (`respaldo: false`), no una omisión. Un `github-token` vacío
  produce el mismo efecto por accidente y con un mensaje de error que acusa a la causa equivocada.
- El simulacro del respaldo necesita su **propia etiqueta**. El mío dejó abierto un issue titulado
  «PRUEBA … no es una incidencia» que a partir de ahí se comía los avisos reales, porque la
  deduplicación busca por etiqueta y el título lo fija el primero que llega.
- Y el título de un issue de respaldo describe **la incidencia**, no el asunto del primer aviso: en
  la lista de issues el título es lo único que se ve, y el primero que llega es casi siempre el más
  trivial. Ver [[un-gate-falla-abierto-por-su-entrada]].

## `always()` en un job de aviso dispara al cancelar el run A MANO

`always()` corre también cuando **el run entero se cancela**, no solo cuando algo falla. Si el
workflow no declara `concurrency`, las cancelaciones son manuales — y con un job largo, cancelar al
ver un typo es lo normal.

**Medido en producción el 2026-09-09, no razonado:** cancelé el run `34418566857` a mano y el aviso
salió con `HTTP 200` diciendo *«la suite NO llego a correr — el job murio antes de los tests»*. No
murió: lo cancelé yo. Con `!cancelled()`, el mismo gesto sobre `34419946276` dejó el job en
`cancelled` sin entregar nada. Dos runs, mismo gesto, resultado opuesto.

**How to apply:** en un job de aviso usa `!cancelled()`, no `always()`. Sigue cubriendo el caso que
sí hay que avisar —el **tope del job** agotado, que es una cancelación de ese job con el run vivo—
porque `cancelled()` mira si se canceló el RUN, no un `needs`. Y comprueba el operador que ya usan
los jobs de al lado: en `qa.yml` el job `tests` ya usaba `!cancelled()`.

Relacionado: [[mi-fix-hereda-la-forma-del-bug]] — los seis defectos que la review cazó eran del
ARREGLO, no del bug original.
