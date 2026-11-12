# Qué hay que hacer, en una línea
Un solo encargo: adaptar a X (16:9, ES+EN, set B) los vídeos y carruseles que ya sirven en IG/Threads; música sin voz en vídeo; carruseles en packs de 4 láminas.

## Contexto
- Pedido completo de Lola (2026-10-25), sustituye el encargo corto solo del cap. 2. Jürgen: **no lanzar ahora**; encolar tras el Fundido (cuando la Mini esté libre).
- Regla X: fotos y vídeos en **16:9**. Estáticos/carruseles: **1600×900**. Vídeos: **1920×1080** (o 1600×900 si el pipeline de set B ya fija ese tamaño; lo importante es 16:9 real, no 9:16). ES y EN. Vídeo X: **música sin voz** (como los `*-x.mp4` actuales). Estilo set B.
- Hoy: los `*-x.mp4` de reels y serie siguen en **1080×1920**. Los carruseles `es-16x9` / `en` tienen **6** láminas; falta el pack de **4** optimizado para X (historia completa en 4; no partir 6 en 4+2).
- Biblioteca: `~/Claude/marketing/biblioteca/`. Fuente: `_fuente/` (serie, reels, carruseles). INDICE + nota PARA-LOLA al cerrar.
- Destino: `lanzar-sesion marketing`. Prioridad = plan sem 2 + lun/mar (cap. 2 serie y lo del plan). Binarios en biblioteca, no en el repo. Sin PR de app salvo scripts/seeds de marketing.

## Qué se pide

### A) Vídeos 16:9 ES+EN con música (sin voz)
1. **Reels** (prioridad del plan): Categorías, Pagos planificados, Cuentas, Recordatorios, Búsqueda; y Voz + Yala IA si aún no hay 16:9 real.
2. **Serie «Yala en 20 segundos»**: al menos **cap. 2** (Foto de la boleta); ideal **caps. 2–4** en 16:9.
- Layout pensado para horizontal (no letterbox ni estirar el 9:16). Misma música/nivel que los `*-x` actuales.
- Rutas claras (p. ej. `…/con-audio/*-x-16x9.mp4` o carpeta `x/` documentada en el INDICE). **No tocar** los `*-ig.mp4` ni los mudos/9:16 de IG.

### B) Carruseles 4 láminas 16:9 ES+EN
- Temas: Registro rápido, Panel y presupuestos, Yala IA, Grupos.
- Adaptar copy y layout al horizontal; **no** solo recortar las 4 primeras de las 6.
- Historia completa en 4 láminas por post. Dejar en subcarpeta clara (p. ej. `carruseles/<tema>/x-4/` o `…/es-16x9-4/` y EN equivalente) sin pisar las 6 láminas ni el 4:5 de IG.

### C) Cierre
- Actualizar `INDICE.md` (añadir, no reescribir) + `PARA-LOLA-assets-x-16x9.md` con rutas, medidas (`ffprobe` / `sips`) y qué publicar dónde.
- `/cerrar-total`. Frank avisa a Lola.

## Qué NO hay que tocar
- IG 4:5, reels/serie 9:16 que ya sirven (`*-ig`, mudos, portadas IG).
- Caps 1 de la serie si ya está bien para el plan (salvo que falte 16:9 y entre en el alcance ideal).
- Otras tmux, iPhones reales, CloudAgent, rama 2.1 de producción.

## Cómo se sabe que está bien
- Vídeos pedidos en 16:9 real con música; carruseles de 4 a 1600×900 ES+EN; INDICE + PARA-LOLA; IG intacto.

/cerrar-total

## Nota de disco
La Mini tiene ~29 GB libres (umbral 32). Preferir escritura en la biblioteca de marketing; si hace falta DerivedData/caché, limpiar al cerrar. No pedirle a Jürgen que limpie.

## Paso 0 (auto-contestado; sesión sin nadie delante)

- **Vídeo 16:9 = formato nuevo `x` (1920×1080) en las plantillas de reel y de serie**, no un letterbox: frase y pasos a la izquierda, teléfono a la derecha, gancho y cierre incluidos. Los 9:16 se regeneran idénticos (comprobado con `diff` del `index.html`).
- **Música = la pista del `*-x.mp4` vertical tal cual.** El 16:9 dura lo mismo que el 9:16, así que mismo tema y mismo nivel sin remezclar. Sin voz.
- **Alcance vídeo:** los 7 reels pedidos (Categorías, Pagos planificados, Cuentas, Recordatorios, Búsqueda, Voz, Yala IA) y la serie, caps. 2–4 (el ideal). Cap. 1, Panel, Grupos y Bandeja no entran.
- **Rutas:** `reels/<función>/con-audio/<función>-<idioma>-x-16x9.mp4` y `serie/…/<idioma>/con-audio/cap-0N-…-<idioma>-x-16x9.mp4`. Junto a lo existente, que no se toca.
- **Carruseles de 4:** guion propio en `_fuente/carruseles/textos-x4.json` y `x4.py`: 01 gancho con el teléfono que enseña la cifra, 02-03 funciones, 04 función final con el lema y la insignia dentro. Salida en `carruseles/<tema>/x-4/<idioma>/`. Cifras sacadas de la pantalla que acompaña.
- **Repo:** los binarios y las plantillas viven en `~/Claude/marketing/biblioteca` (fuera de git). El PR solo lleva este encargo con su Paso 0.
