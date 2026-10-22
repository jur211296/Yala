---
MODO AUTÓNOMO HASTA TERMINAR: sí
---
# Un intent superseding en la vuelta al neutro puede dejar el coordinador del cierre de sesión trabado

## Contexto
Cola A real-risk (Jürgen 2026-09-25): sync/sesión. Ticket: un intent superseding en la vuelta al neutro puede strandear el coordinador del sign-out — Ajustes mudo / sesión a medio soltar. Relanzado tras Frames CLI (prioridad Jürgen vía Lola); la corrida anterior ~21:36 se mató por paralelismo con marketing.

Base fresca desde origin/2.1. Alternancia: tras esta Cola A toca adaptive otra vez.

## Qué se pide
Cierra el ticket de backlog/qa correspondiente al slug: el coordinador de sign-out no puede quedar trabado cuando un intent superseding ocurre en la transición a neutro. Gate, mutantes, PR en modo cola auto-merge (ADR-054: `gh pr merge --auto --merge`, no esperar CI), `/cerrar-total` modo cola.

## Qué NO hay que tocar
Marketing, Remotion, runner propio, deploy prod. No paralelo con otras Yala.

## Cómo se sabe que está bien
Repro del strand cerrado con tests; PR en cola; ticket a qa si aplica device-QA.

## Paso 0 — decisiones (resueltas en autónomo, bypass)

1. **¿Sigue vivo el ticket?** Medido: la mitad `.working` la cerró por accidente `signOutWorking` (2026-09-14), sin test.
   La mitad `.blocked` seguía abierta: con el «espera agotada» en pantalla el Welcome era derribable. → Se arregla `.blocked`
   y se fija `.working` con un test.
2. **¿Qué vía de las dos del ticket?** Término `isSignOutBlocked` que no es blocker y solo impide el derribo. Descartado
   que el desmontaje reconozca el bloqueo: `acknowledgeBlocked` borra `blockedExit` y pierde el punto de retorno.
3. **¿Y la invitación retenida?** Re-peek de la cola en cada cambio de fase con el shell tapado (patrón de `dismissSplash`).
4. **Asumido:** un `.blocked` de otro dueño o huérfano también retiene la invitación tras el Welcome; reabrir lo cura.
5. **Tests:** matriz pura + cableado por source-scan + mutantes. **Device-QA:** guion en el ticket, que va a `qa`.
6. **Entrega:** PR en cola de auto-merge (ADR-054).
