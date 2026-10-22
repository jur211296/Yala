---
name: lentes-adversariales-se-contradicen
description: Dos lentes de una misma review pueden afirmar lo contrario sobre un hecho verificable, y la CORRECCIÓN de una lente también puede venir incompleta. El desempate es medirlo yo, siempre.
metadata:
  type: feedback
---

**Cuando dos lentes de la misma review adversarial se contradicen sobre un HECHO, no elijas: mídelo.**

**Why:** el 2026-09-06, en el KPI de Balance de Distribución, lancé tres lentes. La lente de UI
afirmó que `calculateData()` corre «por cada tecla del buscador, sin debounce» y lo listó como
defecto de gravedad media-alta. La lente de rendimiento afirmó lo contrario —«no se dispara por
tecla»— y **trajo la prueba**: el campo es un `@State private var localSearchText` de
`RecordsFiltersView` con un `TextField` encima, y solo se vuelca al ViewModel en
`commitToViewModel()`, que cuelga del botón «Aplicar».

Las dos eran verosímiles y las dos citaban líneas. Un grep de dos comandos zanjó el asunto: la de
rendimiento tenía razón. Si me quedo con la de UI —era la más alarmante, y la alarma convence—
habría escrito un debounce que no hacía falta, y habría dejado en el código un comentario que
describe mal la app. De hecho **ya lo había escrito**: mi propio comentario decía «evita una pasada
O(N) por tecla del buscador», heredado de la misma suposición. Lo corregí midiendo.

Y la lente de rendimiento se equivocó en otra cosa el mismo día: dio por bueno que el bug del PR #77
no se había reproducido —cierto— pero eso no la hacía fiable en todo lo demás. **Una lente que
acierta en su hallazgo principal puede fallar en los secundarios.**

**How to apply:**

- Al leer los informes, **separa lo verificable de lo interpretativo**. «`searchText` se escribe por
  tecla» es verificable con un grep. «El hero queda incoherente con el pie» es un juicio, y ahí sí
  vale la lente. La contradicción entre lentes casi siempre está en la primera categoría, que es la
  barata de resolver.
- **La gravedad que declara una lente no es evidencia.** Un hallazgo etiquetado ALTA con una premisa
  falsa sigue siendo falso; uno etiquetado MEDIA con una medición detrás manda.
- Cuando una lente aporta la **prueba** y la otra solo la afirmación, empieza por comprobar la
  prueba — pero compruébala, no la creas. En este caso resultó correcta; el coste de mirar fue un
  `grep -n localSearchText`.
- **Y revisa tus propios comentarios contra lo medido.** El error no llegó de la lente: ya estaba en
  mi código, y la lente solo lo repitió. Un comentario con una premisa falsa es peor que ninguno,
  porque el siguiente que lo lea lo dará por medido.

**Y hay un modo de fallo que no es la contradicción entre dos, sino la CORRECCIÓN INCOMPLETA de una
sola. Medido el 2026-09-08 en `bulk-update-account-leaves-converted-amount-stale`.** Yo había escrito
que `.amount =` lo tienen también «`SplitExpense`, `InboxDraft`, `ScheduledPayment`, `Budget`,
`CashFlowLine`, `Account`, `SplitGroup`». Una lente me corrigió con evidencia —cuatro de esos siete no
declaran `amount`, usan `limitAmount` / `manualAmount` / `budgetLimitAmount`— y hasta ahí tenía razón.
Pero su lista de reemplazo («solo `InboxDraft`, `SplitExpense` y `ScheduledPayment`») **también estaba
incompleta**: un `grep -ln "var amount:" Yala/Models/*.swift` da **siete** modelos, con
`CashFlowOverride`, `FavoritePayment`, `SplitSettlement` y `SplitShare` que ninguna de las dos listas
mencionaba.

⇒ **Una corrección que llega con evidencia se siente terminada, y ese es justo el momento de medirla.**
La lente había demostrado que yo estaba mal; de ahí no se sigue que ella esté bien. El coste de
comprobarlo fue un `grep` — el mismo que habría evitado mi error original. **Al aceptar una corrección
numérica, ejecuta el comando que la produce, no la copies.**

Lo que sí vale sin discusión de las tres lentes: cazaron **seis defectos que yo introducía** y que
mis propios tests en verde no veían — un `> 0` heredado que escondía el hero con saldo negativo, un
«0» pintado a quien sí tiene saldo, un flag sin observador, la rama de los dos chips, y un
`adjustment` que no viajaba. Relacionado: [[review-adversarial-caza-lo-mio]],
[[mis-mediciones-fallan-por-el-filtro]].
