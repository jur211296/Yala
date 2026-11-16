# Video de vista previa del iPad 13" en pt-BR, en-GB y pt-PT para la ficha 2.2
toca: marketing/App Store (videos de vista previa del iPad), sin código de la app

Rama base: 2.2. Un solo PR contra 2.2, un solo cierre.
Es un pedido de Lola que Jürgen aprobó el 2026-11-04. Hoy solo hay video de vista previa del iPad en español y en inglés. Haz el video del iPad 13" en pt-BR, en-GB y pt-PT, siguiendo el mismo guion y formato que los que ya existen y los requisitos de App Store Connect. Los textos y los montos van localizados: libras en en-GB y euros en pt-PT.
Deja los archivos listos para que Lola y Dan los carguen. No subas nada a ASC.

Mueve la card con `tablero`: en curso al empezar e in qa al cerrar.
Si algo bloquea o cambia el resultado, pregunta con `preguntar-bot`; no asumas nada.
El cierre trae la sección «Saltado o asumido sin preguntar».
Termina con /cerrar-total.

## Paso 0 — decisiones

Resueltas con Lola por `preguntar-bot` durante la sesión (no en autónomo):

1. **¿Puede Frank entrar en `marketing/`?** Sí, solo para este encargo (Lola).
2. **¿De dónde salen los videos de referencia?** No estaban en el repo: Mini, `~/Claude/marketing/biblioteca/asc/vista-previa/{es,en}/`, hechos con la plantilla set B de `_fuente/reels/`. Mismo formato y misma plantilla.
3. **¿Toma de pantalla?** La toma 2.2 por idioma que ya grabó el lote de la ficha (`ficha-app-store/video/`, con libras y euros). Sin regrabar.
4. **¿Frases?** Opción A (Lola): set B. en-GB = inglés tal cual; pt-BR y pt-PT traducidos por Frank y marcados como BORRADOR de copy.
5. **¿Montos de las etiquetas?** Los que se ven en pantalla (Lola): £24.00 / £190, R$ 90,00 / R$ 380, € 26,00 / € 190. Se pidió £28.00 y en la toma es £24.00.
6. **¿Composición de Remotion en el repo?** No hace falta: la plantilla set B ya tiene los formatos `ipad` e `ipad-horizontal`.
7. **¿Card?** No había una propia; se creó «Video de vista previa del iPad 13" en pt-BR, en-GB y pt-PT».
