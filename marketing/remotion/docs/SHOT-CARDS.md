# Shot cards — `ia-gasto-pizza`

Los planos de la pieza piloto. Nueve movimientos de cámara y siete beats de texto sobre
una toma continua de 16,18 s.

El footage **no se corta**: cortar una demo de producto rompe la prueba de que la app hace
eso de verdad, seguido. Lo que se mueve es la cámara.

---

## Los siete beats

| # | Seg. | Estilo | Texto | Por qué ahí |
|---|---|---|---|---|
| 1 | 0,0–2,1 | hero | **Sin formularios.** | El hook ataca la **fricción**, que es el posicionamiento entero. No dice lo que la app tiene; dice lo que te ahorra |
| 2 | 2,2–3,7 | line | Lo escribes como lo dirías | Titula el gesto que se está viendo |
| 3 | 3,9–5,7 | line | Y la IA hace el resto | El relevo: tú paras, la app sigue |
| 4 | 6,0–7,9 | pill | Monto · categoría · fecha | Etiqueta lo que la card **ya está enseñando**. No lo anuncia |
| 5 | 8,3–11,1 | line | Tú eliges la cuenta | Lo único que la IA no decide sola. Decirlo es honestidad, y evita prometer de más |
| 6 | 11,8–13,9 | hero, rosa | **Registrado.** | El golpe. Entra **medio segundo después** de que aparezca la fila de éxito: a la vez parecería que lo anuncia; después, lo confirma |
| 6b | 12,1–13,9 | badge | **PEN 20.00** · Pizza · Restaurantes | Sale de la pantalla. Es exactamente lo que dice la fila de éxito, nada más |
| 7 | 14,2–16,2 | line | Tus cuentas, al día | Cierra el arco: el gasto ya está donde tiene que estar |

Ni un beat dura más de 2,9 s y no hay más de 0,4 s sin texto en pantalla.

---

## Los nueve planos

| Seg. | `focusY` | `scale` | Qué se ve |
|---|---|---|---|
| 0,0 | 0,40 | 1,02 | Los tres chips de sugerencia. Plano abierto |
| 1,7 | 0,70 | 1,02 | El campo de texto ← **el gesto**. Se ve lo que se escribe, con el teclado asomando |
| 3,9 | 0,26 | 1,12 | La burbuja del usuario, ya enviada |
| 6,1 | 0,49 | 1,00 | **La card entera**, de «Gasto 20 PEN» a «Guardar». El plano estrella: no se recorta |
| 8,4 | 0,41 | 1,22 | Primer plano de la fila «Cuenta» cambiando de valor |
| 10,1 | 0,42 | 1,14 | La misma fila, ya en «Gastos Soles · PEN» |
| 11,6 | 0,34 | 1,18 | La fila de éxito: Pizza · PEN 20.00 · Registrado |
| 14,1 | 0,34 | 1,00 | Se abre a la lista de Registros |
| 16,2 | 0,38 | 1,10 | Push lento de salida hacia la end card |

Cada `focusY` sale de localizar el elemento con `ffmpeg` y pasarlo a fracción del trozo
visible. **No hay ni un número estimado en esta tabla.**

---

## Lo que este piloto NO demuestra

- **No demuestra el look 2.1.** La toma es tema Light; el pack es Liquid Glass oscuro.
- **No demuestra una toma limpia.** Lleva la píldora roja de grabación, tapada con
  `crop: { top: 0.05 }`.

Lo que sí demuestra es que **el sistema funciona de punta a punta**: footage real → beats y
cámara en `copy.ts` → dos lienzos → dos mp4 verificados.
