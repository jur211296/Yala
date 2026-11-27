---
id: 2026-11-26-actualizar-videos-tutoriales-2-3
status: done
priority: medium
area: tutoriales
created: 2026-11-26
updated: 2026-11-27
card: tablero-actualizar-todos-los-videos-de-tutoriale-c1wm
source: encargo 2026-11-27-actualizar-videos-tutoriales-2-3 (decisión de Jürgen del 26-nov, bloque C)
---
# Actualizar todos los vídeos de tutoriales a los flujos de 2.3

Los clips de Ajustes › Tutoriales enseñaban pantallas de 2.2 (y los de «Filtrar el Panel», de la 1.1). Se regrabaron
los 38 con la herramienta de siempre (`qa/scripts/tutorial-videos/record.sh` + `TutorialVideoRecordingUITests`), en el
simulador iPhone 17 Pro, semilla `realista`, tema oscuro y es-PE. Mismo formato (1080×1080 con marco, H.264), mismos
nombres y mismos pasos: la app no cambia de código.

## Inventario

| Tutorial | Clips | Qué estaba viejo |
|---|---|---|
| Crear una cuenta | 3 | Ajustes sin tarjeta de perfil; el + abría el formulario, hoy el asistente por pasos |
| Crear categorías | 4 | Ajustes viejo; el formulario no cambió (regrabado con el resto; el paso 3 ahora abre icono y color) |
| Crear etiquetas | 2 | Ajustes viejo |
| Registrar un gasto | 4 | Formulario de 2.2 con segmentado Gasto · Ingreso · Transferencia; hoy la hoja B1 |
| Importar datos | 2 | Ajustes y pantalla de importar de 2.2 |
| Crear presupuestos | 4 | Formulario; hoy el asistente. «Mostrar en el widget» solo al editar |
| Pagos planificados | 5 | Formulario; hoy el asistente, con «¿Es una suscripción?» en la primera pregunta |
| Favoritos | 2 | «Favorito» bajo el monto y estrella arriba; hoy «···» y la fila de favoritos de B1 |
| Personalizar el Panel | 3 | Panel de 2.2 |
| Filtrar el Panel | 5 | Clips de la 1.1 sin caso de grabación; hoy se filtra tocando subcategorías en Distribución |
| Bandeja | 4 | Bandeja de 2.2 |
| Apple Pay | 4 imágenes | Vigentes: capturas de Atajos de iOS 27 (21-oct) |

Peso de los clips en el paquete: 12,11 MB → 7,41 MB.

## Cambios en la herramienta

- `record.sh --lote caso…`: una corrida de `xcodebuild` para varios casos; el simulador por defecto es el primer
  «iPhone 17 Pro» disponible.
- Casos reescritos para los asistentes y la hoja B1, y 5 casos nuevos de «Filtrar el Panel».
- Con la hoja B1 y un importe escrito, la app nunca llega a «quieta» para XCTest (60 s de espera por gesto): los dos
  casos que pasan por ahí quitan esa espera solo mientras corren.
- `YalaTests/TutorialesVideos23/`: cada paso del catálogo tiene su clip y no queda ningún clip huérfano.

## Queda fuera

- Cuatro textos de paso ya no casan del todo con la pantalla (cuenta paso 3, favoritos paso 1, pagos paso 4, filtrar
  paso 1). No se tocaron: textos nuevos los decide Jürgen (card en el tablero).

Antes y después: https://claude.ai/artifact/S5K5sLWEfnmMTQUYqCb8Je
