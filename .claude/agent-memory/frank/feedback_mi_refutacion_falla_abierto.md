---
name: mi-refutacion-falla-abierto
description: Un hallazgo cuyos refutadores mueren se queda con cero votos, y una condición del tipo "refutan < 2" lo descarta como si lo hubieran refutado — el filtro de la review adversarial falla ABIERTO
metadata:
  type: feedback
---

En un workflow de review adversarial, la condición que decide si un hallazgo sobrevive **no puede
mirar solo cuántos votos lo refutan**. Si los refutadores mueren —límite de sesión, error de API—,
`votos` queda vacío, `refutan` vale 0, y `refutan < 2` da `true`… pero con `ok.length > 0 &&` delante
el hallazgo se descarta en silencio. Un hallazgo que nadie juzgó se archiva como si lo hubieran
declarado falso.

**Why:** me pasó el 2026-09-12 en la review del PR #149. Las 6 lentes terminaron y produjeron 45
hallazgos; la fase de refutación se cortó por límite de sesión con **41 de 141 agentes completados**.
El resultado del workflow dijo «6 confirmados, 39 refutados» — pero solo ~6 se refutaron de verdad.
**33 hallazgos nunca se juzgaron y salieron etiquetados como refutados.** Entre ellos estaban los que
atacaban la premisa central del PR (el flag compilado de M1 seguía en `true`, no en `false` como yo
afirmaba), que solo aparecieron al recuperarlos del `journal.jsonl` a mano.

Es mi propia regla aplicada a mi propio código: [[feedback_un_gate_falla_abierto_por_su_entrada]] —
lista vacía por error = «no hay». La escribí para el código de Yala y la repetí en el andamio.

**How to apply:**

1. **Tres estados, no dos.** `sobrevive` · `refutado` · `SIN JUZGAR`. Lo tercero se devuelve aparte y
   se cuenta en el `log()`, nunca se funde con lo refutado.
2. Condición correcta: `const juzgado = ok.length >= 2; sobrevive = !juzgado || refutan < 2`. Un
   hallazgo sin quórum **sobrevive** y lo reviso yo.
3. **El `return` del workflow lleva siempre `en_bruto` y la suma de las tres categorías.** Si
   `confirmados + refutados != en_bruto`, hay hallazgos perdidos y el número lo canta solo.
4. **Cuando un workflow reporte `agents_error > 0`, no te fíes de su resultado: lee
   `journal.jsonl`.** Cada línea `{"type":"result"}` trae el valor real que devolvió cada agente, y
   de ahí se recuperan los hallazgos íntegros.
5. Y dimensiona antes de lanzar: 45 hallazgos × 3 refutadores = 135 agentes. Con ~15 lentes ya vas a
   tres cifras. Si el fan-out de la segunda fase depende del resultado de la primera, **acota**
   (los graves y medios primero) o parte en dos invocaciones.

Relacionado: [[feedback_review_adversarial_caza_lo_mio]] · [[feedback_la_review_y_los_mutantes_no_comparten_arbol]]
