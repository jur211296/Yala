---
id: barrido-bugs-lote-a
status: done
priority: very-high
area: "bienvenida, modo-nube, panel"
created: 2026-11-14
updated: 2026-11-14
source: "barrido de QA en el iPhone 14 (14-nov), cards c8i9, x5tm, l4m0, 0f7h (wju5 queda en el PR de ajustes visuales)"
---

# Entrar a la cuenta y la bienvenida: Panel vacío, Dividir con amigos, cancelar la activación y botones fuera de pantalla

## Qué pasa hoy (para quien usa Yala)

1. **(c8i9)** Tras «¡Tu cuenta está lista!», «Empezar» devuelve a la bienvenida en el primer arranque tras instalar; con
   la app ya reabierta, lleva a un Panel en S/ 0 con «Crea tu primera cuenta» unos 20 s.
2. **(x5tm)** Quien entra por «Dividir gastos con amigos» no aterriza en Grupos: «Empezar» vuelve a la puerta de Grupos.
3. **(l4m0)** «Cancelar la activación» mientras comprueba los datos: el aviso no tiene «No», nombra «Ya tengo una
   cuenta» (ya no existe), y tras «Sí, cancelar» la barra se queda sin botón y termina en «¡Tu cuenta está lista!».
4. **(0f7h)** Cancelar y cerrar Yala antes de que aterrice: al reabrir retoma y entra igual.
5. **(wju5)** En el iPhone 14, con «Divide cualquier gasto» en la vitrina, «Entrar con mi iCloud» queda fuera de pantalla.

## Causas

- **3 y 4, una sola:** «Sí, cancelar» solo apuntaba el «sí» en memoria y esperaba a que terminara el intento del traspaso
  en vuelo. El efecto del adopt miraba el «sí» antes de cada intento, no durante: si ese intento salía bien, adoptaba. Y
  cerrar Yala antes del aterrizaje perdía el «sí».
- **5:** el botón de la puerta de Grupos va en su propia fila y la vitrina crece una fila entera solo en esa función. **No
  se arregla aquí:** la decisión de Jürgen del 13-nov (ajustes visuales de la bienvenida) lo saca de la vitrina y lo pone
  debajo de los tres botones, sin EJEMPLO, y está en el PR «Bienvenida 2.3: ajustes visuales, tres botones de entrada
  iguales y logo nítido», en cola de merge pero con el check `tests` en rojo. La build del barrido no lo traía. Un arreglo
  aquí contradecía ese diseño y chocaba al mergear; se probó y se retiró.
- **1, el Panel en S/ 0:** las páginas montadas bajo la bienvenida calcularon antes de entrar, y cerrar el cover no las
  recarga; la espera con esqueleto del 13-nov solo se decide al recargar.
- **1 y 2, «Empezar» vuelve a la bienvenida (medido con trazas en el iPhone 14):** el respaldo del `onDismiss` del cover
  de la bienvenida vuelve al elector si el onboarding no está completo, y leía ese dato de su `@Binding`, que se quedó con
  el valor de cuando se presentó el cover. En la primera entrada tras instalar, `onAdoptStarted` lo marca con el cover
  abierto: la traza dio `onb=false` en el respaldo con `true` en disco. Al reabrir no pasaba porque ya era `true` al
  presentar. La card de Grupos (x5tm) es la misma causa: su aterrizaje en Grupos ya existía, la bienvenida lo tapaba.

## Arreglo

- El efecto del adopt mira el «sí» en dos puntos seguros (antes del reconcile y antes de armar el modo nube) y sale con
  la cancelación y su marca; la bienvenida vuelve al inicio.
- El «sí» de la bienvenida se apunta también en disco con la marca de la entrada (`WelcomeAdoptInFlight`) y lo honra el
  arranque siguiente.
- El aviso es un `.alert` con las dos salidas; la última frase dice «desde el inicio» (16 idiomas) y bajo la barra sale
  «Cancelando…».
- El respaldo lee el onboarding de disco (`WelcomeCoverContentLogic.reopensChooserAfterCloudSignIn`).
- «Empezar» sube `dataVersion`: las pantallas recalculan ya en la nube.

## Probado en el iPhone 14 (14-nov, Yala Dev de esta rama, instalación nueva, Google jur211296)

- c8i9: antes, «Empezar» volvía a la bienvenida; después entra en el Panel con S/ 1353.
- x5tm: por «Dividir gastos con amigos» → «Entra aquí», «Empezar» aterriza en Grupos con los dos grupos.
- l4m0: el aviso trae «Sí, cancelar» y «Seguir pasando a mi cuenta de Yala»; tras confirmar, «Cancelando…» y vuelta a la
  bienvenida.
- 0f7h: «Sí, cancelar» y cerrar Yala en el acto; al reabrir, la bienvenida.
- wju5: reproducido (antes) en el iPhone; queda para el PR de ajustes visuales.

Evidencia: `~/Claude/entregas/2026-11-14-barrido-bugs-entrar-y-bienvenida/evidencia/`.

## Tests

`YalaTests/BarridoBugsLoteA/` (runner con el «sí» durante el intento y su control, la marca en disco, el respaldo que lee el onboarding de disco, cableado) y el scan
ajustado de `WelcomeAdoptExitTests`.
