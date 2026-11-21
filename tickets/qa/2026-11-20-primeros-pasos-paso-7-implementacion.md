---
id: 2026-11-20-primeros-pasos-paso-7-implementacion
status: qa
priority: high
area: "onboarding, primeros-pasos, pro"
created: 2026-11-20
updated: 2026-11-20
source: "encargo 2026-11-20-primeros-pasos-paso-7-hoja-coach-tips-y-oferta-pro; Jürgen eligió B en los cuatro temas (20-nov, 06:05)"
---

# Primeros pasos: paso 7 como historias, progreso en el mazo, sin coach tips de Ajustes y oferta Pro tras el paso 2

Especificación: las maquetas `docs/maquetas/primeros-pasos-paso-7-y-prueba/index.html` (opción B de los cuatro temas) y
su ticket `tickets/done/2026-11-19-primeros-pasos-paso-7-y-prueba-maquetas.md`. Las decisiones menores (D1-D10) están en
el Paso 0 del encargo y viajan al PR.

## Qué cambia para quien usa la app

1. **Paso 7 como historias.** Una por manera de anotar sin abrir Yala, con el ejemplo y el beneficio, «Tutorial · N de
   M» arriba y un solo botón suave, «Enséñame cómo», que abre el mini tutorial.
2. **Sin hoja «Ver los 7 pasos».** El progreso va en el mazo: segmentos en la carta y la fila de los siete pasos debajo,
   que distingue hechos, para después y pendientes. «Seguir donde iba» va junto al paso actual.
3. **Sin tour de Ajustes ni tour Pro.** Lo de Pro se enseña en «¡Listo! Tienes Pro» con tres accesos que abren la
   función.
4. **La oferta del mes de Pro sale al terminar «Aprender a registrar»**, después de «¿Borramos los de prueba?», con el
   botón de empezar solo y fijo abajo.

## Pruebas

- `YalaTests/PrimerosPasosPaso7/PrimerosPasosPaso7Tests` (23 tests) y `YalaTests` entero en el gate.
- `YalaUITests/PrimerosPasosPaso7/PrimerosPasosPaso7UITests` (oferta tras el paso 2), `Bienvenida23FinalUITests` (historias,
  ✕ que conserva la historia, correo, oferta del final con «Ahora no», «Pruébalo ahora») y `Bienvenida23BaseUITests`
  (fila de pasos del mazo).

## Guion de device-QA (iPhone 14, Yala Dev, cuenta de Sandbox sin prueba usada)

El simulador no prueba la compra real ni Siri. Datos dev: se pueden borrar.

1. Ajustes › Vaciar mis datos y empezar con «Es mi primera vez» hasta el Panel con el mazo.
2. Paso 2: probar la voz gratis una vez (dictar «almuerzo 18») y terminar el tutorial. Contestar «¿Borramos los de
   prueba?» y cerrar la guía de la Bandeja. **Esperado:** sube la oferta «Lo que acabas de probar, un mes gratis» con
   «Dictaste un gasto…», el botón de empezar visible sin bajar y «Ahora no» arriba.
3. Tocar «Empezar mi mes gratis» y confirmar en la hoja de Apple. **Esperado:** «¡Listo! Tienes Pro» con «Pruébalo
   ahora». Tocar «Dicta un gasto»: se cierra y se abre la voz en el Panel. Repetir con «Pregúntale a Yala IA» si se
   quiere (abre Yala IA).
4. Abrir Ajustes. **Esperado:** sin tour (ni oscurecido ni tarjetas).
5. Seguir el mazo hasta el paso 7. **Esperado:** la fila de pasos distingue hechos y para después; el paso 7 son
   historias que no avanzan solas; «Enséñame cómo» abre el mini tutorial; en Siri, decir «Oye Siri, nuevo registro en
   Yala» abre Nuevo registro. «Terminar» completa el mazo **sin** volver a ofrecer el mes.
6. Si en el paso 3 se cerró la oferta con «Ahora no»: el final del paso 7 tampoco la ofrece.
