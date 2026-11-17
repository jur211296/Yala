---
id: 2026-11-15-grupos-captura-igual-personal
status: done
area: groups
priority: medium
created: 2026-11-15
updated: 2026-11-16
source: pedido de Jürgen del 15-nov · encargo «Grupos: voz, foto y Yala IA idénticos a personal»
---

# Grupos: Voz, Foto y Yala IA idénticos a personal, y el «+» solo al desplazar

## Qué pidió Jürgen (15-nov)

1. Voz, Foto y Yala IA en un grupo deben verse y sentirse igual que en personal: mismas pantallas, animaciones, textos
   y pasos. Solo cambia lo del grupo (quién pagó, cómo se divide y el destino del registro).
2. Dentro de un grupo, el «+» flotante no sale hasta que el scroll se lleva los botones de arriba, como en Panel,
   Registros, Presupuestos y Pagos, reutilizando el mecanismo que ya existe.

## Qué se construyó (16-nov)

- `Yala/App/Views/Groups/Captura/`: las tres hojas de Grupos hechas con las piezas de personal.
  - Voz (`GroupVoiceCaptureView`): media altura que ya escucha, onda, tiempo, frase en vivo, Cancelar/Listo, orbe al
    procesar y la pantalla de fallo de personal. La revisión sube la hoja a grande.
  - Foto (`GroupPhotoCaptureView`): fichas Cámara, Fotos y Archivo (PDF: primera página), la foto se lee al elegirla con
    su línea de luz. Lo del grupo: «¿Quién comió qué?» opcional antes de elegir.
  - Yala IA (`GroupAIChatView`): el chat de personal (burbujas, tres puntos, barra con micrófono y panel de voz). La
    respuesta es el reparto por persona con «Ajustar» y «Usar este reparto».
  - Motor común (`GroupCaptureModel`): tareas `receipt.*`, cupo de Grupos sin candado; antes vivía dentro de
    `GroupReceiptSplitView`, que ahora es solo la revisión del reparto.
- El resultado sigue abriendo Nuevo gasto relleno; «Apuntarlo a mano» abre Nuevo gasto vacío.
- `GroupDetailView` + `GroupRecordsView`: el «+» cuelga de la fila de «Nuevo gasto» con
  `revealsFloatingActionWhenScrolledAway` y se funde con la animación de la lista de Grupos.
- Textos nuevos en `L10n+GruposCaptura.swift`, en los 16 idiomas.

## Pruebas

- Unit: `YalaTests/GruposCaptura/GruposCapturaTests.swift` (enrutado al gasto del grupo, división por defecto, piezas
  de personal, flotante según el scroll).
- XCUITest: `GroupReceiptSplitUITests` (adaptado a las hojas nuevas) y `GruposCapturaFlotanteUITests`, también en un
  iPhone SE.
- Capturas lado a lado: `GruposCapturaCapturasUITests` (solo a mano, con `TEST_RUNNER_CAPTURA_DIR`).

## Queda fuera

- Micrófono y cámara reales: el simulador no los tiene. Guion para el iPhone 14: abre un grupo, toca Voz y di «pizza
  40 Ana y yo, lomo 35 Beto»; toca Foto › Cámara y saca un recibo; toca Yala IA y dicta con el micrófono. En los tres,
  «Usar este reparto» abre Nuevo gasto con los importes por persona.
- El chat de Grupos no tiene el «+» de Temas ni los ajustes de IA del chat personal: son de las preguntas de finanzas,
  que en un grupo no existen.
