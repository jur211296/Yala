# Revisión 2.3 por vistas · artefacto

**Abrir:** https://claude.ai/artifact/Xz4qpagf9wssYVfc1rAiaT (privado, de Jürgen).

Junta en una sola página las once revisiones por vistas de 2.3 (7 al 9 de noviembre de 2026) y su consolidación en
lotes. Portada con los hallazgos por nivel y por vista, los 13 lotes y las decisiones que frenan algo; una sección
por vista con cada hallazgo, su nivel, su lote y el enlace al PR, la ficha, el ticket o el encargo de origen.

La clase de cada hallazgo es la de la consolidación (zonas 34 a 41) o la de la ficha y los lotes ya hechos (zonas 30
a 32). **El 9-nov Jürgen decidió en una discusión uno por uno todo lo que pedía decisión** (las siete que frenaban algo,
los «a decidir» y los «sin clasificar»): lo que va pasó a la clase `vad` («Decidido · va», del grupo «Importa») con un
lote existente o «Sin lote aún», y lo que no va, a `dsc` («Descartado»). La nota de cada hallazgo dice qué opción se
eligió y el número de la decisión en el registro. La portada lleva el bloque «Decidido en la discusión del 9-nov».

**Lo que sigue:** el merge de 2.2 en 2.3 (tras la corrección de 2.2 en curso y su TestFlight) y, después, crear las
cards de todo lo decidido, agrupadas en lotes.

## Qué hay aquí

| Fichero | Qué es |
|---|---|
| `fuente/hallazgos.tsv` | Los datos: una fila por hallazgo, ocho campos separados por barras (la cabecera los explica). Se edita a mano. |
| `fuente/decisiones-discusion.md` | El registro de la discusión del 9-nov: cada hallazgo, la decisión, su motivo y la fecha (83 puntos). Es la fuente de las notas `9-nov (N)` de la tabla. |
| `fuente/build.py` | Lotes, decisiones, notas y metadatos de cada vista; genera `index.html` e `img/`. |
| `fuente/plantilla.html` | La página (estilo y script). Los datos entran por el marcador `/*__DATOS__*/null`. |
| `index.html` | La página generada: es lo que se publica. |
| `img/` | Una captura por problema, sacada de `docs/ux/revision-vistas-2.3/<zona>/capturas/`. No se versiona: la regenera `build.py`. |

## Cómo actualizarlo

1. Edita `fuente/hallazgos.tsv` (o los lotes y decisiones en `fuente/build.py`).
2. `python3 docs/ux/revision-2-3-artefacto/fuente/build.py` (usa `sips`, del Mac; `--sin-img` no rehace las capturas).
3. Publica con la herramienta Artifact de Claude Code pasando `url: https://claude.ai/artifact/Xz4qpagf9wssYVfc1rAiaT`,
   `file_path` a `index.html`, `root` a esta carpeta y cada `img/*.jpg` en `files`. Desde otra conversación, léelo
   antes con `action: "read"`, o la publicación se rechaza.

## Fuentes

PR de las revisiones: 846 (Panel), 847 (Registros), 848 (Nuevo registro), 852 (Planificación), 853 (Estadísticas),
856 y 857 (Grupos y sus tickets), 859 (Reportes y Flujo), 860 (Bandeja e IA), 862 (Cuentas y categorías),
864 (Perfil y Ajustes) y 865 (Nube). Índices: 850 y 851. Consolidación: 866. Lotes ya hechos: 854 (Panel) y 855
(Formulario). Todos en la rama `2.3` de `jur211296/Yala`.
