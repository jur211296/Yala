---
name: alcance-minimo-salvo-incoherencia
description: Jürgen escoge el alcance mínimo en cada decisión, pero amplía cuando el propio cambio dejaría una incoherencia visible al usuario
metadata:
  type: feedback
---

Al registrar el ticket de los predeterminados del Panel (2026-09-04) le puse cuatro decisiones
juntas. Escogió lo mínimo en tres —solo instalaciones nuevas, no re-sembrar a quien ya tiene la
app, dejar Cuentas plegada como está, aceptar un efecto colateral en usuarios actuales con tal de
no acoplar código nuevo— y **amplió** en la única donde el cambio se contradecía a sí mismo: que
«Restablecer» pasara a devolver los nuevos predeterminados en vez de encenderlo todo.

**Why:** su criterio no es «poco trabajo», es «que no queden dos verdades». Un residual heredado lo
tolera y lo deja anotado; una incoherencia que introduce *este* cambio, no — porque el usuario la
vería y no sabría a qué atenerse.

**How to apply:** al ofrecer decisiones de alcance, separa siempre las dos familias y dilo:
«esto ya estaba roto antes» vs «esto lo rompe este cambio». Propón el mínimo para lo primero y la
ampliación para lo segundo; acertarás casi siempre y él solo tendrá que confirmar. Y ofrécele las
decisiones **agrupadas tras medir**, no de una en una mientras investigas — ver
[[jurgen-levanta-sus-reglas]] y [[creo-que-no-es-aprobacion]].

## El corolario que me falta a MÍ, no a él (2026-09-05, PR #64)

La ficha de arriba está escrita para ofrecerle decisiones. Esta mitad es sobre las que tomo yo sin
preguntar, en una sesión autónoma.

El ticket enumeraba **trece** consumidores. Alineé **quince**: añadí dos por mi cuenta porque
«salían gratis» al estar al lado. Uno de los dos era el ÚNICO con potencial destructivo de todo el
cambio —el cleanup de «me expulsaron», que borra el grupo con sus gastos y emite tombstones— y la
review adversarial lo cazó a punto de poder nukear un grupo al que el usuario acabara de re-unirse.
Lo revertí.

**Why:** el criterio de la ficha —«¿lo rompe este cambio o ya estaba roto?»— **no basta cuando soy
yo quien elige el alcance**, porque un consumidor que no estaba en la lista no está roto por mi
cambio: está roto desde antes, y tocarlo es estrictamente ampliar. La pregunta que me faltó es la
otra: **¿qué pasa si me equivoco AQUÍ?** Los trece del ticket eran cosméticos, de prefill o de
dinero recuperable. Ése borraba datos. El coste de equivocarse no es uniforme dentro de un cambio
que parece homogéneo.

**How to apply:**
- **Lo que el ticket no lista, no entra** — aunque el patrón sea idéntico y el diff de una línea.
  Va al ticket de residuales, que para eso existe.
- **La excepción sigue siendo la incoherencia interna** (dos líneas de la misma función
  contradiciéndose ante el usuario), no la proximidad ni el «ya que estoy».
- **Antes de añadir un consumidor de tu cosecha, pregunta qué destruye si te equivocas.** Si la
  respuesta incluye un `delete`, un `save()` que viaja o un flag persistente que nadie re-enciende,
  no lo toques sin que te lo pidan: documenta y sigue.
- Cuando revierta uno así, **el motivo va escrito en la línea y declarado en el allowlist del
  escáner** — si no, el siguiente lo vuelve a alinear con la mejor intención.

## La otra cara, el mismo día (PR #66) — y el criterio que las separa

Horas después del caso de arriba amplié dos veces, y creo que las dos bien. **No lo ha confirmado
todavía: si Jürgen dice lo contrario, manda él y esta sección se corrige.**

1. La decisión decía «el escritor de `OnboardingView` y los TRES lectores de `AppBootstrapper`».
   Medidos: tres escritores y siete lectores. **Bajé los diez.**
2. La decisión decía «las DOS keys legacy se custodian». Medido: el registro sellado se pierde
   igual cuando el dueño no tiene sesión viva. **Custodié las tres.**

**Por qué esto no es el error del PR #64, que es la pregunta que importa.** Allí amplié a *otros
objetos* que el ticket no listaba (consumidores distintos, uno destructivo). Aquí amplié al **resto
del mismo objeto que la decisión nombra**: la misma key, la misma frontera. La diferencia práctica:

- ampliar a otro objeto es **añadir superficie** ⇒ pregunta «¿qué destruyo si me equivoco?»;
- completar el objeto nombrado es **no dejarlo a medias** ⇒ la pregunta es la contraria: «¿qué pasa
  si me quedo en la letra?». En los dos casos, la respuesta era **el mismo defecto que la decisión
  viene a cerrar, vivo en la otra mitad** — un par escritor/lector partido, un dueño sin su registro.

**How to apply:** cuando la cifra de una decisión del owner no case con lo medido, la cifra es del
ticket y el ticket ya se equivocó otras veces; lo que manda es **el hecho que la decisión describe**.
Amplía hasta cubrirlo entero, escribe en el commit que la cifra no casaba y por qué, y **deja fuera
todo lo que sea otro objeto** aunque el patrón se parezca. Y si al ampliar el alcance crece de verdad
—otro fichero, otra frontera—, eso ya no es completar: es el caso de arriba.
