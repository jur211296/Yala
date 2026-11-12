---
id: welcome-to-cloud-entry-closes-and-reopens-whole-screens
status: done
priority: high
area: "welcome, onboarding, nube"
created: 2026-10-25
updated: 2026-10-25
source: "tablero 4gfj (lote 12.3, propuesta «Entrada a Yala»), decisión de Jürgen 2026-10-25 07:30 Lima: A · Fundido"
---

# Del Welcome a «Entra a tu cuenta»: una pantalla se cerraba y otra se abría entera

## Qué pasaba

Al pasar de «¡Hola de nuevo!» o «Es mi primera vez» a la entrada con la cuenta de Yala, el Welcome bajaba entero, la
pantalla se quedaba en negro algo más de medio segundo y «Entra a tu cuenta» subía desde abajo. Al volver, lo mismo al
revés. Causa: el Welcome y la entrada eran dos `fullScreenCover` del mismo anchor (`WelcomeFlowModifier`), y cambiar de
uno a otro es cerrar una presentación y abrir otra.

## Qué se decidió

A · Fundido (propuesta del lote 12.3, `~/Claude/entregas/Yala--lote-12-3-accesibilidad-contraste/transicion-welcome/`):
el fondo morado no se mueve y el contenido se funde en 0,35 s, como entre los pasos del Welcome. Con «Reducir
movimiento», igual: un fundido no desplaza nada.

## Qué se hizo

- Un solo cover para los pasos del Welcome y la entrada a la cuenta; su contenido cambia con `.transition(.opacity)` sobre
  el degradado del Welcome, que va debajo de las dos pantallas. Lo que se pinta lo decide `WelcomeCoverContentLogic`.
- Los dos flags (`showWelcomeFlow`, `showWelcomeCloudSignIn`) no cambian: la matriz de readiness y los productores siguen
  igual.
- Lo que hacía el `onDismiss` de la entrada (reponer «abrir en el consentimiento» y el origen) corre también al volver al
  Welcome sin cerrar el cover; el respaldo «reabrir el elector» solo si lo último que enseñó el cover fue la entrada.
- Los cuatro saltos: «Ya tengo una cuenta» → entrada · faro de «Es mi primera vez» → entrada · «Crear otra cuenta» ·
  «Volver». Funden también, por ser el mismo salto, el alta en la nube desde «Es mi primera vez» y la vuelta a la puerta
  de Grupos desde la entrada.

## Fuera

Restaurar desde iCloud y la recuperación de una invitación siguen siendo covers propios: su salto desde el Welcome sigue
cerrando y abriendo pantallas enteras.

## Verificación

- `WelcomeCoverContentLogicTests` (lógica pura + cableado) y `YalaTests` entero en verde.
- XCUITest del Welcome, onboarding, entrada a la nube y matriz de presentaciones en verde.
- Vídeo del después: `~/Claude/entregas/Yala--transicion-entrada-fundido/capturas/`.
