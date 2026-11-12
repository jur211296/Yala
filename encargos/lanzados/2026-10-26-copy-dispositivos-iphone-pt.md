# Copy dispositivos: «este iPhone» + pt-PT você

Cierre: **cierra-sola** → al terminar, `/cerrar-total`.
Versión **2.2**. Base `origin/2.2`. Esfuerzo: medium.
Slug: `copy-dispositivos-iphone-pt` · Sesión cola **S8** · al cerrar → **S9**.

## Contexto · cards del lote
- Unos 20 textos dicen «este iPhone» y también salen en el iPad
- pt-PT: dos subcategorías de sistema de Grupos dicen «você»

## Briefs per-card (lee y cumple cada uno)
- `~/Claude/tmp-frank/copy-este-iphone-fuera-grupos-hxah.md`
- `~/Claude/tmp-frank/pt-pt-subcategorias-grupos-voce-bxds.md`

## Qué se pide
1. Lee y cumple los dos briefs per-card (orden: iPhone→dispositivo, luego pt-PT você).
2. Un solo PR a 2.2 que cubra ambas cards (o dos commits claros en el mismo PR).
3. LocalizationParityTests verdes; inventario sin «iPhone» indebido; pt-PT sin «você» en esas subcategorías y sin duplicados.

Mueve las cards a «in progress» con `--agente frank` al empezar; al cerrar, a in qa / done según el cierre de cada una.

## Qué NO tocar
- marketing/ y Web/ (Lola).
- Otras sesiones de la cola (no las lances).
- No desactivar tests ni saltarte el gate.
- Lo específico de cada brief per-card.

## Cómo se sabe que está bien
Cada card cumple su hechaCuando; suite relevante verde; PR a 2.2 en auto-merge; `/cerrar-total`.

## Pie pipeline
- Base: `origin/2.2`. Una sesión Yala a la vez. Rebase único antes del PR.
- Pipeline serial Yala: (1) limpiar sims muertos, DerivedData y cachés XcodeBuildMCP de worktrees cerrados; (2) build `xcodebuild -jobs 2` sin sim booteado; (3) bootear 1 sim; (4) tests; (5) apagar y limpiar.
- Al cerrar: Frank publica digest y lanza la siguiente según `~/Claude/tmp-frank/siguiente-activo.txt` y `~/Claude/tmp-frank/cola-2-2-orden-activo.txt`.
- marketing/ y Web/ = Lola. No relances otras sesiones Yala.


## Paso 0 — decisiones (resueltas en autónomo, bypass)

Medido antes de decidir (2026-10-26, sobre `origin/2.2`):
- `es.lproj` tiene **24** claves con «iPhone» (el ticket decía 23; la de más es `pj22.language.inIOSFooter`).
  En los 16 idiomas son las mismas 23 + 1, salvo pl, que escribe «iPhonie»/«iPhone’a» (el grep sin raíz no lo veía).
- ja nombra el iPhone en 4 claves donde los demás idiomas dicen «este teléfono». Hay ~79 claves «este teléfono» en
  español con el mismo fallo en el iPad.
- pt-PT tiene ~190 claves con «você», no 2: el bloque de respaldo pt-BR que ya cubre la card de revisión nativa.
  Las dos subcategorías de saldo inicial son las únicas que **se guardan como nombre** y se buscan por él.
- El seed de Grupos (`seedSystemGroupCategoriesIfNeeded`) busca la subcategoría SOLO por el nombre del idioma actual:
  cambiar el texto pt-PT sin más le siembra una segunda a quien la tenía. `GroupBridgeSystemEntities` la encuentra hoy
  porque pt-BR conserva el nombre viejo, por casualidad.

Decisiones:
1. «este iPhone» como sitio de los datos → «este dispositivo» en los 16 idiomas, con el término que ya fijó i9r1
   (de Gerät, fr appareil, nl apparaat, pl urządzenie, ja この端末, zh 这台设备). Incluye «tu iPhone», «otro iPhone» y
   «el modelo de tu iPhone» (soporte).
2. «Ajustes del iPhone» → «Ajustes» a secas (recomendación del brief), con el nombre de la app en cada idioma
   (pt-PT Definições).
3. «este teléfono» (~79 claves) y las 4 de ja **no** entran: es otra palabra y otro alcance. Ticket de backlog nuevo.
4. pt-PT: solo las dos subcategorías → «Saldo inicial (devem-te)» / «Saldo inicial (deves)» (tú, como it). El resto
   de «você» queda para `pt-pt-needs-a-native-review-after-the-pt-br-sweep`.
5. Emparejamiento: lista de nombres viejos por rol (molde «Sin asignar»), usada por el seed y por
   `GroupBridgeSystemEntities`. No se renombra lo guardado: un aparato pt-BR del mismo usuario dejaría de reconocerla.
   Consecuencia asumida: quien ya la tenía en pt-PT la sigue viendo con el nombre viejo; los nuevos ven el nuevo.
6. Tests: unit del emparejamiento + seed con el nombre viejo sin duplicar + pt-PT sin «você» en esas dos claves;
   el XCUITest que buscaba «Quitar mis datos de este iPhone» se actualiza. Sin capturas: es texto, el gate lo cubre.
