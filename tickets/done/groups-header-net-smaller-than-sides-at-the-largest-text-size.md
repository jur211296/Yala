---
id: groups-header-net-smaller-than-sides-at-the-largest-text-size
status: done
priority: low
area: "grupos, accesibilidad"
created: 2026-11-03
updated: 2026-11-05
source: "pase de estrés del barrido de QA 2.2, parte C (card del tablero tablero-pase-de-estres-2-2-c-con-el-texto-al-max-ysol)"
---

# Con el texto al máximo, el neto de Grupos sale menor que «Te deben» y sus botones se cortan

## En lenguaje de usuario

Con el texto de accesibilidad al máximo, la cifra grande de Grupos (el neto) salía más pequeña que las líneas de
«Debes» y «Te deben», así que la jerarquía se invertía. Y los botones «Nuevo gasto» y «Nuevo grupo» salían «Nu…» y «N…».

## Arreglo (2026-11-04)

Solo a tamaños de accesibilidad: el neto crece con el texto (hasta 60 pt, y nunca menos de 36), y el rótulo y las
líneas de cada lado dejan de crecer en AX2 (33 pt). Los dos botones van uno debajo del otro y su texto puede ocupar
dos líneas. A tamaño normal, nada cambia (diff de píxeles en el PR). El hero del Panel no se tocó: usa el mismo token
y queda como hallazgo aparte.

## Montaje de QA (iPhone de pruebas, Yala Dev)

1. Ajustes del iPhone › Accesibilidad › Pantalla y tamaño del texto › Texto más grande: activa «Tamaños más grandes» y
   lleva el control al máximo. Deja el modo oscuro puesto (Centro de control › mantén el brillo › Modo oscuro).
2. Abre Yala Dev con datos de verdad (cuentas, algún grupo con deudas y Yala Pro para leer recibos).

## Guion

1. Abre la pestaña Grupos (con al menos un grupo con deudas).
2. Arriba, la cifra del neto («Te deben en total · en S/») es lo más grande de la cabecera, más que los importes de
   «Debes» y «Te deben».
3. «Nuevo gasto» y «Nuevo grupo» van uno debajo del otro y se leen enteros.
4. Toca «Nuevo gasto»: abre el formulario de gasto. Cierra y toca «Nuevo grupo»: abre el de grupo.
5. Pon el modo claro y repite el paso 2.
6. Con el texto normal, la cabecera y los botones se ven como antes (lado a lado).

Cerrado en el barrido de QA 2026-11-05: accesibilidad/tamaños, criterio de Jürgen; arreglo del PR #771 visto con el texto al máximo (el neto es lo mayor de la cabecera).
