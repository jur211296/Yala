Yala
# Hoja «Esto leí»: dar aire a la primera card y hacer visible su borde superior
---
toca: Yala/App/Views/Image/ImageSelectionView.swift,Yala/App/Views/Image/ImageEntrySheetHeight.swift,Yala/App/Views/Image/EntrySheetCloseButton.swift,Yala/App/Views/Image/EstoLeiPhotoViewer.swift,Yala/App/Views/Voice/VoiceDraftReviewCard.swift,YalaTests/EstoLeiCardSuperior/,tickets/backlog/2026-11-23-esto-lei-aire-card-superior.md,tickets/done/2026-11-23-esto-lei-aire-card-superior.md
esfuerzo: medium
cierre: cierra-sola
---

Pedido de Jürgen (23-nov, pruebas de Yala 2.3 en iPhone, modo oscuro).

## Problema reportado
En la hoja «Esto leí» (al escanear una foto de recibo, por ejemplo Rappi S/ 27.90):
1. El borde superior de la primera card no se distingue dónde termina porque el fondo del panel y el efecto glass se mezclan.
2. El tope superior de esa primera card queda demasiado pegado al botón «X» (arriba a la izquierda) y a la miniatura de la foto (arriba a la derecha).

## Qué se pide
1. Revisar la composición superior de la hoja «Esto leí» (tanto en foto como si comparte layout con voz) para que la primera card arranque un poco más abajo, dejando aire claro entre la cabecera («X», título «Esto leí», miniatura de la foto) y el borde superior de la card.
2. Hacer que el borde superior (y contorno) de la primera card se distinga con nitidez sobre el fondo/material de la hoja, tanto en modo oscuro como en modo claro, sin perder armonía con el diseño de Yala.
3. Verificar que no se corte ni se empuje fuera de pantalla el botón «Guardar» ni la nota «Si cierras sin guardar, lo encontrarás en tu Bandeja de Entrada» en iPhone estándar e iPhone SE.
4. Revisar si `ImageEntrySheetHeight` necesita un ajuste menor de altura por ese espacio extra.

## Pruebas, entorno y cierre
- Base: `origin/2.3`.
- Antes de usar simulador, comprueba si el iPhone 14 conectado a la Mini vía DeviceMCP está libre (no lo des por ocupado sin comprobarlo). Si corres en la Max y necesitas simulador, tienes permiso explícito para usar un segundo simulador (tope 2 en la Max; en la Mini tope 1).
- En la Mini, respeta el pipeline serial (compilar sin simulador encendido, apagar y limpiar el simulador al terminar) y limpia DerivedData propio y cachés de XcodeBuildMCP de worktrees ya retirados sin preguntar.
- Agrega pruebas en `YalaTests/EstoLeiCardSuperior/` si aplica lógica de altura o layout testeable.
- Guarda capturas de antes y después en `capturas/` del worktree (modo oscuro y modo claro).
- Abre un PR sin firma de IA contra `2.3` con auto-merge activado y espera a que el PR entre de verdad en `2.3` antes de `/cerrar-total` (si tras ~45 min el CI sigue rojo por algo ajeno al PR, cierra y anótalo).

## Paso 0 — decisiones

> Resueltas por la sesión (modo semi, menores y reversibles): las recomendaciones se dan por buenas. Se discuten en el PR.

**D1 · ¿Cuánto aire entre la cabecera y la primera card?** → 16 pt (`DS.Spacing.lg`) en vez de 4 pt (`xs`), solo en «Esto leí».
Por qué: es el aire que la hoja ya usa a los lados y separa el círculo de la X y la miniatura girada sin descolgar la card. Alternativa descartada: 24 pt (`xxl`), empuja demasiado en el iPhone SE.

**D2 · ¿Cómo se distingue el borde de la card?** → contorno de 1 pt en la propia `VoiceDraftReviewCard` (`strokeBorder`), con un tono de token visible sobre el glass en oscuro y en claro, sin degradados ni brillos.
Por qué: el problema es el borde, no el relleno; tocar el relleno cambiaría la identidad de la card en voz y foto. Alternativa descartada: sombra (se pierde sobre el glass oscuro).

**D3 · ¿Voz también?** → el contorno sí (la card es la misma pieza); el aire superior solo en foto, que es lo reportado y lo que declara `toca:` (`VoiceRecordingView` queda fuera).
Por qué: no abrir un fichero que el encargo no declara y otra sesión podría tocar. Queda anotado en «Encontrado».

**D4 · ¿Ajuste de altura?** → sí: la hoja personal de foto ofrece una media altura propia = la `.medium` del sistema o, si no alcanza, lo que mide un registro con su nota y «Guardar». La foto de Grupos sigue con `.medium`.
Por qué: medido en el SE antes del cambio, la `.medium` ya cortaba la fila de chips y la nota de la Bandeja; con 12 pt más de aire también se cortaría en el 17 Pro. Alternativa descartada: quitar padding interno de la card (rompe el hueco de «Ver todo»).
