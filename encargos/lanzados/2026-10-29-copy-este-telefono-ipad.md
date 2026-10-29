# Copy dispositivos: «este teléfono» fuera de Grupos

Cierre: **cierra-sola** → al terminar, `/cerrar-total`.
Versión **2.2**. Base `origin/2.2`. Esfuerzo: medium.
Slug: `copy-este-telefono-ipad` · Sesión cola **S27b** · al cerrar → **S27d** (grupos-borrar-era-cloudkit).

## Contexto · card
- Unas 80 frases dicen «este teléfono» y también salen en el iPad (`tablero ver tablero-unas-80-frases-dicen-este-telefono-y-tam-bvzw`).
- Mismo fallo que la sesión S8 (PR #644, «este iPhone» → «este dispositivo») con otra palabra: ~79 claves en español dicen «este teléfono» (Grupos, Welcome, cierre de sesión) y salen igual en el iPad. En japonés, 4 dicen «iPhone».
- Ticket: `tickets/backlog/copy-names-this-phone-outside-groups.md` en 2.2. Sigue el mismo criterio que #644 (redacción neutra de dispositivo, 16 idiomas, sin migrar datos existentes).

## Qué se pide
1. Inventario de «este teléfono» / equivalentes indebidos en los 16 idiomas y corrección a texto neutro de dispositivo, coherente con #644.
2. Guarda en LocalizationParityTests (o la suite de localización existente) que detecte la palabra vieja; comprobar con un mutante.
3. Un solo PR a 2.2 en auto-merge.

Mueve la card a «in progress» con `--agente frank` al empezar; al cerrar, a in qa / done según su cierre.

## Qué NO tocar
- marketing/ y Web/ (Lola).
- Otras sesiones de la cola (no las lances).
- No desactivar tests ni saltarte el gate.

## Cómo se sabe que está bien
Se cumple el hechaCuando de la card (cero «este teléfono» indebido en los 16 idiomas, LocalizationParityTests en verde); PR a 2.2 en auto-merge; termina con `/cerrar-total`.

## Pie pipeline
- Base: `origin/2.2`. Una sesión Yala a la vez. Rebase único antes del PR.
- Pipeline serial Yala: (1) limpiar sims muertos, DerivedData y cachés XcodeBuildMCP de worktrees cerrados; (2) build `xcodebuild -jobs 2` sin sim booteado; (3) bootear 1 sim; (4) tests; (5) apagar y limpiar.
- Al cerrar: Frank publica digest y lanza la siguiente según `~/Claude/tmp-frank/siguiente-activo.txt` y `~/Claude/tmp-frank/cola-2-2-orden-activo.txt`.
- marketing/ y Web/ = Lola. No relances otras sesiones Yala.

## Paso 0 — decisiones (resueltas en autónomo, bypass)

1. **Qué cuenta como indebido.** Toda frase que nombre como «teléfono» el aparato donde corre Yala, en cualquier
   idioma (también «móvil» en es-ES, «celular» en pt-BR, «telemóvel» en pt-PT, «Handy» en de, «この iPhone» en ja).
   Inventario medido: 75 claves × 15 idiomas, y 6 en japonés.
2. **«Antes de cambiar de teléfono» y «usa otro teléfono» también cambian.** El ticket dudaba; en un iPad, cambiar de
   aparato es cambiar de iPad. «Dispositivo» es correcto en los dos casos.
3. **Se quedan con «teléfono» (lista cerrada en el test):** la subcategoría de gasto «Teléfono y comunicación», los
   datos de demo (`devseed.*`) y «media móvil» de Planificación. No nombran el aparato.
4. **Fuera de alcance, apuntado:** «Lo que va entendiendo el iPhone» (`voice.live.transcriptAccessibility`, 16 idiomas)
   y la novedad de Siri «En un iPhone con Apple Intelligence». Dicen «iPhone», no «teléfono»; el segundo es una
   afirmación sobre qué modelos lo admiten. La guarda no los mira.
5. **Término por idioma**, el de i9r1/#644: dispositivo, device, Gerät, appareil, apparaat, urządzenie, 端末, 设备.
   Concordancias revisadas a mano en pl (neutro), nl (het-woord), fr (cet/l’appareil).
6. **Guarda:** test nuevo en `LocalizationParityTests` con una expresión por idioma y la lista de claves permitidas;
   se prueba con un mutante (devolver una frase al texto viejo).
7. **Sin migración**: son textos, no datos guardados.
