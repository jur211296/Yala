---
id: 2026-11-16-bugs-barrido-final-2-3-app
status: qa
priority: high
area: cloud-sync
created: 2026-11-16
updated: 2026-11-16
source: encargo 2026-11-16-bugs-barrido-2-3-app (barrido QA final de 2.3, cards c8i9, xhbn, lplc y 120i)
qa-status: passed
qa-date: 2026-11-16
qa-notes: probado en el iPhone 14 (Yala Dev de esta rama); falta el visto bueno de Jurgen en su tanda
---

# Bugs del barrido final de 2.3 en la app

## Qué cambia para la persona

1. **Tras «¡Tu cuenta está lista!» › «Empezar», el Panel enseña el esqueleto de carga hasta que llega la cuenta**, y luego
   los datos. Nunca S/ 0 con «Crear categorías» (card c8i9).
2. **Cancelar la entrada a una cuenta ya no deja en el teléfono nada de esa cuenta.** La sesión se suelta al cancelar, así
   que Grupos no baja sus grupos ni el puente escribe «Grupos PEN» y el gasto del grupo; la entrada siguiente pide la
   cuenta de nuevo (card xhbn).
3. **Tocar cualquier punto de «Vaciar mis datos» abre «¿Vaciar tus datos?»**, y «Exportar una copia antes» abre Exportar
   (card lplc).
4. **Yala IA en Grupos ya no deja la descripción vacía** con un gasto escrito, y **el aviso de Yala IA nombra también
   escribir** (card 120i, puntos 3 y 4). Los puntos 1 y 2 pasan a tickets propios:
   `closing-yala-during-the-icloud-return-wipe-cancels-it-silently` y
   `move-to-yala-account-sheet-offers-a-sign-in-it-will-refuse`.

## Causas medidas (iPhone 14, 16-nov, con trazas en la consola)

- **Panel**: al tocar «Empezar» habían llegado 2 de 6 cuentas y 0 movimientos. La espera del Panel solo arrancaba con cero
  cuentas, así que pintaba S/ 0; los datos completos llegaban 8,5 s después.
- **Cancelar**: la marca del adopt (`AdoptSessionOwnership`) quedaba en `nil` también con la sesión abierta por la
  pantalla, así que la cancelación no cerraba la sesión. Al cerrarse la pantalla se soltaba el candado de Grupos y, con la
  sesión viva, el canal bajaba los grupos y el puente escribía. Medido: tras cancelar y reabrir, 1 cuenta, 1 movimiento, 2
  categorías y 2 grupos en el almacén; con el arreglo, todo a 0.
- **Vaciar**: el botón rojo llevaba el estilo automático dentro de una fila de `List`. El simulador no lo reproduce.

## Guion de QA para Jürgen (iPhone 14, Yala Dev de 2.3)

1. Bienvenida › Entrar con Google › tu cuenta con datos › Cargar mis datos y entrar › «¡Tu cuenta está lista!» › Empezar.
   Esperado: esqueleto unos segundos y luego tu saldo; nunca S/ 0 con «Crear categorías».
2. Ajustes › Cerrar sesión. Entrar con Google › Cargar mis datos y entrar › «Cancelar la activación» en cuanto se active ›
   Sí, cancelar. Cierra Yala y ábrela. Esperado: bienvenida; «Entrar con Google» vuelve a pedir la cuenta; sin «quedar en
   blanco» ni pantallas de Grupos por la puerta principal (salvo que la cuenta elegida sea solo de grupos).
3. Ajustes › Vaciar datos › toca el centro de «Vaciar mis datos». Esperado: «¿Vaciar tus datos?». Cancelar. Toca
   «Exportar una copia antes»: abre Exportar.
4. Grupos › un grupo › Yala IA › escribe «pizza 40 entre todos» › Usar. Esperado: el formulario trae descripción.

## Evidencia

`~/Claude/entregas/2026-11-16-bugs-barrido-2-3-app/evidencia/` (antes y después de cada bug, vídeos y el conteo del
almacén en `almacen-antes-y-despues.txt`).
