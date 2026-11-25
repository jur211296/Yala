---
id: 2026-11-24-bugs-barrido-build-8
status: done
priority: high
area: "captura-atajo-banco-parte-2, panel, statistics, planning, a11y"
created: 2026-11-24
updated: 2026-11-24
source: "barrido de QA de la 2.3 antes de la build 8 (`docs/qa/barrido-2-3-antes-build-8/lista.md`, «Hallazgos»)"
---

# Bugs del barrido de la build 8

Cinco hallazgos del barrido, en un lote.

## Qué cambia para quien usa Yala

1. **Guía de Atajos de «Avisos del banco».** En iOS 27 enseña los pasos de la app Atajos nueva: el «+» de abajo abre
   «Nuevo atajo», el disparador se elige en la pestaña «Automatización» de la hoja de abajo, la acción de Yala se busca
   en el buscador de esa hoja y se guarda con «‹». Para quitarla, pulsación larga › Eliminar y confirmar. En iOS 26 la
   guía sigue como estaba. Los 16 idiomas (`BankNoticeGuideVersion`).
2. **«Ver detalle ›» del Panel abre Estadísticas.** Antes el toque lo recogía el ojo de al lado y ocultaba los montos.
   Ahora «Ver detalle» es un botón propio; el ojo sigue ocultando con su toque.
3. **Con texto de accesibilidad, la cifra grande** de Estadísticas, Registros y «Te falta pagar» es la mayor de su bloque
   (ticket `2026-11-24-cifra-del-hero-pequena-con-texto-de-accesibilidad`).
4. **El saldo grande del Panel sale aunque se esté guardando sin parar** (una semilla, un import). Ya no espera al pase
   por tramos del hero, que cada guardado corta: sale en cuanto el saldo está calculado. En «Solo gastos» la cifra es el
   gasto del período, que sí sale de ese pase, y sigue esperándolo.
5. **Al cambiar de período en Estadísticas**, mientras el período nuevo se calcula, la cifra, el ingreso y el gasto del
   hero salen en esqueleto en vez de los del período anterior.

## Cómo se probó

- iPhone 14 (iOS 27.2.1): la guía entera en Atajos de verdad, y el paso 5 con una compra simulada (un recordatorio con el
  texto de un aviso de BCP como disparador): el gasto llegó a la Bandeja y el BCP pasó a «Funcionando». «Ver detalle» 3
  de 3 abre Estadísticas. Con la semilla `pesado` escribiendo, el saldo grande sale (antes: todo menos el saldo). Al
  cambiar a «Mes pasado», esqueleto en vez de las cifras de este mes.
- AX5 en el iPhone 14 y en los simuladores iPhone SE e iPad Pro 13.
- Tests: `YalaTests/BugsBarridoBuild8/` (guía por versión y 16 idiomas, lógica y cableado de los heros, saldo con
  guardados seguidos desde otro contexto). Mutante: con el saldo esperando otra vez al pase, el caso cae.

## Lo que se intentó y no bastó

Que el pase del hero en curso terminara en vez de relanzarse con cada recálculo. Verde en test, pero en el iPhone el
saldo seguía sin salir: lo que corta el pase es el aviso de cambio del almacén de cada guardado (protege de leer filas
borradas), no el recálculo.

## Fuera

- `-uitest-reset` con un almacén de diez años pasa del límite de 20 s del arranque: es del gancho de pruebas, no se tocó.
