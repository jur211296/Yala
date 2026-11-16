---
id: new-record-suggests-previous-descriptions
status: qa
priority: medium
area: "transactions, new-record"
created: 2026-11-06
updated: 2026-11-06
card: tablero-nuevo-registro-sugerencias-de-descripcio-y6du
source: "encargo lote de productividad 2.3 (hormiga, logos, sugerencias)"
---

# Nuevo registro sugiere descripciones que ya usaste

## Qué cambia para la persona

Mientras escribe la descripción de un gasto o ingreso (desde 2 letras), debajo del campo aparecen hasta **5
descripciones que ya usó**, en cápsulas. Tocar una pone **el texto exacto**, para escribir siempre igual lo mismo y que
el seguimiento lo agrupe. Ocupan el sitio de la pista de atajos (`#`, `!`, `@`), que vuelve cuando no hay nada que sugerir.

- Sin mayúsculas ni tildes: «cafe» encuentra «Café con Ana».
- Primero lo que empieza por lo escrito (o una de sus palabras), después lo que lo contiene; dentro, lo más usado y lo más reciente.
- Solo del mismo lado: un ingreso no sugiere descripciones de gastos. Nada en transferencias.

## Qué queda fuera (siguiente paso)

- Proponer también la categoría y la cuenta del registro elegido.
- La aprobación de la Bandeja y el Nuevo gasto de Grupos (tienen su propio campo).

Código: `DescriptionSuggestionLogic`; tests `DescriptionSuggestionLogicTests` y `ProductividadLote23UITests`.

## Guion de QA para Jürgen (iPhone de pruebas, Yala Dev)

1. Toca **Nuevo registro** en el Panel.
2. Escribe las dos primeras letras de algo que anotas a menudo (por ejemplo «ub» o «ca»).
3. Debajo aparecen cápsulas con descripciones tuyas. Toca una: el campo queda con ese texto exacto.
4. Cambia a **Ingreso** y escribe dos letras de un ingreso tuyo: solo salen descripciones de ingresos.
5. Responde: **¿las sugerencias son las que esperabas y en buen orden? (sí / no)**.
