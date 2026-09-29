---
name: feedback-carril-espera-a-cola-a
description: En el carril adaptativo no se corre nada en el simulador mientras Cola A esté viva, aunque haya lock y simuladores propios; al terminar Cola A, se valida que limpió sus simuladores.
metadata:
  type: feedback
---

Con Cola A viva, el carril adaptativo **no lanza corridas de simulador**, aunque use sus propios
`YalaLane-Adapt-*` por UDID y haga cola con `sim-lock.sh`. Se espera a que Cola A termine (su sesión
de tmux desaparece) y entonces se comprueba que dejó sus simuladores limpios: nada arrancado, sin
clones en `XCTestDevices`, sin runners ni `xcodebuild` vivos y la cola libre.

**Why:** Jürgen, 2026-09-28, a media sesión del paso 3: «no corras nada hasta que la cola A termine,
sino se cruzan». Ese día la cola no era FIFO: Cola A se llevó el turno ~1 h seguida y mis cadenas
esperaban encoladas, intercaladas con las suyas.

**How to apply:** antes de la primera corrida de una sesión del carril, `tmux has-session -t
=Yala--<slug de Cola A>`; si existe, se trabaja en lo que no toca el simulador (código, tickets,
evidencia) y se deja un vigía que avise al terminar. Relacionado: [[dos-corridas-un-simulador]].
