---
id: 2026-11-19-primeros-pasos-pulido
status: done
priority: high
area: "onboarding, primeros-pasos, design-system"
created: 2026-11-19
updated: 2026-11-20
card: tablero-primeros-pasos-intros-como-historias-cam-sj4c
source: "Jürgen, 19-nov 22:06, build 2.3 (5): notas al probar Primeros pasos; encargo del 2026-11-20"
---

# Primeros pasos: intros como historias, campos legibles, «No deseo crear…» y textos nuevos

Jürgen probó los Primeros pasos en la build 2.3 (5) y dejó doce ajustes, todos decididos. Este ticket los cierra en un PR.

## Qué cambia para quien usa la app

1. **Las intros son historias.** Sin «Omitir»: tocar la mitad derecha avanza, la izquierda vuelve y mantener el dedo
   pausa la barra (al soltar sigue con lo que le quedaba). Es la pieza común `TutorialStoryPage`, con el reloj y la regla
   de mitades del Welcome. El paso 7 hereda los gestos y conserva su pie (va a maqueta aparte).
2. **El nombre de la cuenta llega escrito** con el del tipo («Efectivo», «Tarjeta de crédito»…) y se cambia ahí mismo.
3. **Los campos se leen.** La build 2.3 (5) (17:31 del 19-nov) salió antes del arreglo de temas de las 22:31: con el tema
   Claro y el iPhone en oscuro, el texto escrito salía blanco sobre la tarjeta blanca. Ese arreglo ya lo cura; además,
   el estilo común `yalaFieldText()` ata el texto al tema (AA 4,5:1 en los diez temas, medido en test) y el aviso de
   ejemplo pasa de terciario a secundario. Lo llevan todos los campos de Primeros pasos y de los asistentes de cuenta,
   presupuesto y pago.
4. **Cards vecinas del mismo alto** («No lo sé» / «Prefiero no decirlo», y las fichas de una fila de tipos y categorías).
5. **«Día» y su número** (y el símbolo y el monto) en la misma línea base y letra, con aire entre ellos.
6. **Volver un paso conserva lo escrito**: nombre, saldo y días se rellenan con lo ya contestado.
7. **«No deseo crear ningún presupuesto / pago planificado»** en la primera pregunta de los pasos 3 y 4, arriba de las
   respuestas (nunca debajo de otro botón). Da el paso por omitido, como antes «Omitir este paso».
8. **Paso 4**: «Elige un pago que hagas cada cierto tiempo» y «También identificaremos automáticamente tus pagos fijos a
   los 3 meses» (la detección existe: Pagos que se repiten, S1, 3 cobros mensuales).
9. **Final del presupuesto**: «Puedes crear hasta 3 presupuestos gratis…» (el 3 sale de `ProFeature.budgets.freeLimit`)
   y «Crear otro» al lado de «Ver mi Panel», si el límite lo deja.
10. **Final del pago**: los pagos planificados no tienen tope en el plan gratis, así que el texto dice «todos los que
    quieras» en vez de inventar un número; «Anotar otro pago» al lado de «Ver mi Panel».
11. **Guía tras los pasos 3 y 4**: la tarjeta de un solo momento dice «Entendido» (cierra) en vez de «Omitir», y la flecha
    vuelve a medir la pestaña «Más» hasta que la barra queda quieta.
12. **Paso 6**: abre «Más» solo y la guía enseña Estadísticas con «Entendido»; el mazo pasa al 7.

## Decisiones menores (tomadas sin consultar)

- El texto del final del pago no lleva número porque no hay límite en el código.
- «Crear otro» (presupuesto) en vez de «Crear otro presupuesto»: lado a lado con «Ver mi Panel» el largo no cabía.
- En es-AR y es-ES, «No quiero crear…»; en es-419, el texto de Jürgen.
- El paso 2 también pierde «Omitir» en su intro; se sale con el «‹» y cada manera se puede omitir dentro.

## Pruebas

- `YalaTests/PrimerosPasosPulido/PrimerosPasosPulidoTests` (5 suites): historias, nombre y volver, contraste de campos en
  los diez temas, textos en 16 idiomas y el límite real, guía de Más y paso 6.
- `YalaUITests/PrimerosPasosPulido/PrimerosPasosPulidoCapturasUITests`: el recorrido con capturas y lo nuevo afirmado,
  incluidos tocar por mitades y mantener para pausar.
- Ajustadas: `Bienvenida23PlanificacionUITests`, `Bienvenida23FinalUITests` (paso 6), `Bienvenida23PasosUITests` (nombre
  precargado), `Bienvenida23BaseTests`, `Bienvenida23FinalTests`, `StepSevenAndTutorialDotsTests`.

## Fuera de alcance

El paso 7, la hoja de los 7 pasos, los coach tips de Ajustes y Pro y la oferta de 30 días van a su propia card
(`tablero-primeros-pasos-paso-7-como-historias-pro-ds65`).
