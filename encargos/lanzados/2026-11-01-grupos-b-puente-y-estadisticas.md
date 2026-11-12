---
esfuerzo: high
release: no
---
# Grupos B: el puente crea tus registros desde las líneas, y Estadísticas, Yala IA y el conector no cuentan la recarga

Cards: tablero-grupos-b-2-el-puente-crea-tus-registros-i108, tablero-grupos-b-3-estadisticas-yala-ia-y-el-con-otj4

## Contexto
Manda la opción B que Jürgen acordó el 1-nov: `docs/disenos/grupos-tu-parte-en-lineas/README.md`, sección «Versión final acordada», y el diseño técnico en `tickets/in-progress/grupos-tu-parte-en-lineas.md` (PR #733).

## Qué hacer
### Card 2: El puente crea tus registros desde las líneas (gasto o recarga)
- Implementar el diseño técnico del ticket: el puente deriva las patas de la receta en cada pasada (Caso A y B), la recarga es un par de transferencia, partitionVirtualTxs no las borra, y si el monto del gasto cambia y no cuadra vuelve un borrador a la Bandeja. Sesión solo-grupos y puente apagado: nada cambia. Review adversarial (puente).
- Desbloqueo: Card 1 (campo splitLinesRaw) mergeada.
- Hecha cuando: Tests del puente para Caso A/B con y sin líneas, recarga, cambio de monto y borrado; el caso Pía (500 recarga + 10 comisión) deja Sip +500, Grupos −510 y gasto 10.

### Card 3: Estadísticas, Yala IA y el conector con líneas: la recarga no cuenta
- GroupBridgeStatsAdjustment netea el préstamo contra la pata de gasto e ignora las de transferencia; mismo cambio en el port mcp/src/logic/groups.ts y en FullFinancialContextBuilder. Review adversarial (cálculo).
- Desbloqueo: Card 2 mergeada.
- Hecha cuando: Caso Pía: Estadísticas muestra 10 de Comisiones y nada de la recarga; caso súper: Supermercado 80 + Hogar 20; tests Swift y vitest de mcp/ en verde.

## Orden
1. Card 2, el puente.
2. Card 3, el cálculo: va en la misma sesión, porque la desbloquea la card 2.

Haz una review adversarial del puente y otra del cálculo. Corre los tests Swift y los vitest de `mcp/`.

## Reglas
- Lo que toque el servidor (Worker o Supabase) se prueba en staging antes de producción.
- Si algo no cabe, crea su card en 2.2 antes del barrido QA (S36).

Termina con /cerrar-total.

## Paso 0

Auto-contestado (MODO AUTÓNOMO, sesión lanzada). Manda el diseño técnico del ticket `grupos-tu-parte-en-lineas`
(D1-D8); estas son las decisiones que el ticket dejaba abiertas o que el código obligó a concretar.

1. **Línea ancla.** La pata conservada representa la PRIMERA LÍNEA DE GASTO (o la primera si no hay ninguna de gasto),
   no la línea 1 a secas. En el Caso B así la pata que el usuario clasifica sigue siendo un gasto siempre que haya uno;
   el caso Pía da lo mismo (Grupos −510, Sip +500, gasto 10). En el Caso A sin líneas de gasto no hay ancla: la real
   netea a 0, como dice D3.
2. **Patas derivadas: preserve+update por línea**, delete+recreate solo si están duplicadas o cambian de forma. La
   identidad de la línea viaja en la marca y el `transferPairID` de una recarga ES el id de la línea (determinista: dos
   aparatos crean el mismo par). La entrada en la cuenta destino lleva la marca: se encuentra aunque llegue antes que su
   salida o aunque `TransferPairReconcileService` le quite el par.
3. **Cuándo se aplica la receta:** puente activo, sesión privada, receta legible de esta versión, sin problemas, cuadra
   con tu parte, todas las cuentas destino existen y tienen la divisa del gasto, y (Caso A) hay pata real. Si no, tu
   parte en una línea, como hoy, y las derivadas se borran; la receta se conserva siempre.
4. **Borrador por «no cuadra» (D6):** solo cuando la receta es legible y válida pero no suma tu parte. Es un
   `.groupExpense` con su motivo (`splitLinesMismatch`) que pide subcategoría y no se aprueba deslizando: abre la hoja
   de hoy («clasificar tu parte») con un aviso de por qué volvió. Aprobarlo deja tu parte en una línea con esa
   categoría y retira la receta. «Partir» desde esa hoja es la card 5. Una cuenta destino que falta o cambió de divisa
   no crea borrador (puede ser una ventana de sync): vuelve a una línea y se recupera sola.
5. **Recetas que se pierden, aceptado:** un cambio de pagador (Caso A ↔ B) o de divisa del gasto borra la pata que la
   llevaba, como hoy. Queda escrito como residual.
6. **Card 3:** con D1 el ajuste ya da 80 + 20 en el súper y 10 en Pía sin cambiar la fórmula. El cambio es defensivo y
   es el que pide la card: una pata de transferencia no cuenta como pata real, de préstamo ni de costo. Mismo cambio en
   `mcp/src/logic/groups.ts`. `FullFinancialContextBuilder` ya filtra transferencias; se comprueba con test.
7. **Fuera de alcance, a card:** la hoja con «Partir» (card 5), editar una derivada abre «Partir» (card 6). Aquí las
   derivadas y la entrada solo se bloquean como cualquier pata del puente.
8. **Etiquetas (salió en la review del cálculo):** las líneas derivadas de gasto heredan las etiquetas de la pata
   conservada. Tu parte entera lleva tus etiquetas: un «Viaje» en el súper da 100, no 80. Las recargas no las llevan
   (no cuentan en ninguna cifra).
