# Guía visual para decidir la experiencia del usuario nuevo

Convierte la [revisión del usuario nuevo](../README.md) y sus [alternativas](../alternativas.md) en pantallas: en cada
parte del recorrido, lo que ve hoy la persona, el problema en una línea y de 3 a 5 alternativas maquetadas con el
estilo de Yala, todas con el mismo caso ficticio. **No elige ganador**: cada parte cierra con la decisión pendiente.

## Cómo abrirla

- **En el iPhone:** cualquier `.html` se abre solo (capturas y estilos van dentro). Empieza por `00-indice.html`.
  Si el visor no ejecuta JavaScript se ve igual; solo se pierde el avance al tocar el anillo cian.
- **De respaldo:** `guia-visual-usuario-nuevo.pdf`, con las mismas páginas (112 páginas, unos 10 MB).
- **En la Mac:** abre `00-indice.html` en el navegador; los enlaces entre páginas funcionan desde esta carpeta.

| Fichero | Qué tiene |
|---|---|
| `00-indice.html` | El caso, las ocho partes y lo revisado en el simulador (iPad, texto grande, crear cuenta) |
| `01-bienvenida.html` … `08-donde-crear.html` | Una parte del recorrido cada una: hoy, problema, alternativas, lado a lado, comparación, lente de perfiles y la decisión |
| `09-combinaciones.html` | Las cuatro combinaciones de la revisión como recorridos completos hasta el primer gasto guardado, con hoy como línea de base |
| `10-perfiles.html` | Los siete perfiles como lentes: qué opción le va bien o mal a cada uno |
| `guia-visual-usuario-nuevo.pdf` | Todo lo anterior en un PDF |
| `capturas-simulador/` | Capturas tomadas el 2026-11-06 con la build de `2.3` (iPhone 17 Pro e iPad Pro 13, modo oscuro) |
| `fuente/` | El generador: `ui.py` (componentes de maqueta), `pantallas.py`, `partes_*.py`, `combinaciones.py` y `build.py` |

## Qué es observado y qué no

- **Observado:** las capturas del 6-nov de la revisión y las de `capturas-simulador/`. Lo que se midió esta noche
  está en el índice, sección «Lo que faltaba validar».
- **Hipótesis:** la lente de perfiles (salvo la columna «Hoy», que viene de la revisión) y los umbrales propuestos.
- **No validado:** lo técnico de A2, A3 y A4 (arranque del almacenamiento), el cálculo de H3 y la vista en iPad horizontal.
- Los conteos de pantallas y toques se cuentan **sobre las maquetas**. No hay métricas de uso ni testimonios.
- Las alternativas X3 y X4 (parte 8) son **propuestas nuevas** de esta guía; el resto viene de `alternativas.md`.

## Regenerar

```bash
cd docs/ux/revision-usuario-nuevo-2026-11/guia-visual/fuente
python3 build.py                       # reescribe los .html de la carpeta de arriba
python3 build.py --todo /tmp/todo.html # además, una página con todo para imprimir el PDF
```

El PDF se imprime desde `todo.html` con Chromium (Playwright, `printBackground`, tamaño de página del CSS). Dos trampas
medidas al hacerlo: el texto con la fuente del sistema (variable) se incrusta como Type 3 y engorda el PDF, por eso la
impresión usa Helvetica Neue; y las sombras y desenfoques se rasterizan, por eso se apagan al imprimir.
