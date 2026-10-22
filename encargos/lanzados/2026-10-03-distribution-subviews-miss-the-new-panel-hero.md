# El hero del Panel se queda visible en las subvistas de Distribución (categoría, subcategoría, etiquetas y Gráficas/Detalle)

## Contexto
Ticket: `tickets/backlog/distribution-subviews-miss-the-new-panel-hero.md`.
El resumen del final de Tendencias (PR #345) ya está en cola de merge a 2.1. Esta noche y el domingo se ataca todo el diseño posible de 2.1 antes del QA del lunes.

Decisión de Jürgen (2026-10-03 ~22:29 Lima), ya tomada — no la reabras:
- El hero del Panel **se queda visible** en categoría, subcategoría, etiquetas y Gráficas/Detalle.
- Los botones flotantes (FABs) **los decides tú** en la sesión, sin esperar a Jürgen.
- Alcance (ampliación 2026-09-17): alinear el Hero de Estadísticas (todas sus subvistas) con el hero del Panel, incluidos FABs; si hay más vistas con hero paralelo, audítalas.

No hay que inventar diseño nuevo ni dejar propuestas a medias: aplica esa decisión y cierra.

## Que se pide
1. Haz que el hero del Panel permanezca visible (y coherente) en las subvistas de Distribución: categoría, subcategoría, etiquetas, y al alternar Gráficas/Detalle.
2. Decide y aplica los FABs de esas pantallas de forma coherente con el Panel (sin preguntar).
3. Audita otras pantallas de Estadísticas / app con hero paralelo y alíneaslas si el mismo problema se ve.
4. Capturas antes/después en `capturas/antes.png` y `capturas/despues.png` del worktree.
5. PR a 2.1 con auto-merge cuando el gate pase. Cierra con `/cerrar-total`.

## Que NO hay que tocar
- marketing/
- Revisar uso de IA / partir nube-privado / mascota / respuesta por voz (van a 2.2, después del QA del lunes)
- No reabrir la decisión del hero: ya está decidida

## Como se sabe que esta bien
- En iPhone (y iPad si tocas adaptive), el hero se ve en categoría / subcategoría / etiquetas / Gráficas y Detalle, alineado con el del Panel.
- FABs coherentes; gate (build + tests tocados) en verde; PR en cola de merge a 2.1; capturas en el worktree; `/cerrar-total`.

---

## Paso 0 (Frank, 2026-10-03, auto-contestado: sesión sin nadie delante)

Medido antes de decidir: Distribución tiene **un solo** hero para sus subvistas (carrusel categoría /
subcategoría / etiquetas y Gráficas/Detalle); no desaparece en ninguna, pero es **otro diseño** que el del
Panel (centrado, período encima, rótulo debajo de la cifra, tipografía `heroAmount`). Las otras tres pestañas
de Estadísticas, igual. Registros (la página) reutiliza `RecordsTabView`, así que hereda lo que se haga ahí.

| Decisión | Elegido | Por qué |
|---|---|---|
| Qué es «el hero del Panel» en Estadísticas | Su **maquetación**: rótulo arriba a la izquierda + píldora de período a la derecha, cifra grande alineada a la izquierda con `panelHeroAmount`, detalle debajo alineado a la izquierda | Es lo que se ve distinto. Los **números no cambian**: la decisión del 06-sep (cada pestaña su cifra, rotulada) sigue mandando |
| Dónde va el rótulo de la cifra («Saldo de cuentas», «Neto del período»…) | En el hueco de «Disponible» del Panel, arriba a la izquierda | Es el mismo papel: decir qué es la cifra. Mantiene `stats_hero_caption` |
| Cómo se evita que vuelvan a divergir | Un componente compartido (`HeroHeader`) que usan el Panel y las cuatro pestañas | El ticket nace de «cinco heros, ninguno compartido» |
| iPhone girado (poco alto) | Resumen y Registros conservan su banda (`SummaryHeaderStack`); solo cambia la rama vertical | No revertir `iphone-landscape-headers-fill-the-short-screen` |
| FABs | Los de Registros (Yala IA + «+») pasan a **las cuatro** pestañas de Estadísticas | En el Panel siempre hay a mano «Nuevo registro» (fila o flotante); en Estadísticas solo en Registros. Mismo componente, mismas acciones, mismo margen inferior (`fabStackClearance`) |
| Sin datos en el período | La píldora de período sigue (arriba a la derecha); el rótulo solo si hay cifra | Un rótulo sin cifra no dice nada |
| Chips ingresos/gastos | Igual que hoy en cada pestaña (filtran en Registros, informativos en Resumen/Tendencias) | Cambiar su comportamiento no es maquetación |
| Otras pantallas con hero | Auditadas: Planificados (`ScheduledPaymentsListView`) tiene hero centrado propio; se alinea si cabe sin tocar su lógica | Ampliación 17-sep: «si hay más vistas con hero, también» |
| Review adversarial | No | Polish visual, sin cálculo ni sync |
