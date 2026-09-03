---
updated: 2026-09-03
tags: [now, punto-de-retomada]
---

# NOW — 2026-09-03 (Lima)

**Rama** `2.1` · HEAD `b65a688f` — «g13_03 aplicada y verificada en producción».
TestFlight build **12** (CPV 12). **Subida Yala (TF/store) = solo Mini.**
Gateway de producción: desplegado hoy (`47d0e724`, 21:35 UTC).

## La sesión, en una línea

Cuatro arreglos de cosas que contaban mal o borraban datos —el 1:1 de divisas, el último día de los
períodos cerrados, la visita que se llevaba los grupos del dueño— y dos de Grupos que dejaban al
usuario sin explicación.

## Te espera a ti

1. **Publicar la app.** Los dos avisos de Grupos (rechazo y grupo borrado) están completos en servidor
   y en los dos entornos; lo único que falta para que lleguen a la gente es el cliente iOS.
2. **La tanda de QA: 20 tickets en 4 montajes.** Guion en **`qa/guion-tanda.md`**. Siete comparten los
   mismos dos teléfonos, así que montar eso una vez vale por siete.

## Abiertos, por prioridad

- **`invite-link-five-causes-one-message`** — pieza 1 hecha; **2, 3 y 4 son código** y nunca estuvieron
  bloqueadas. La 2 (que el nombre del grupo viaje del enlace a la pantalla) es la mayor.
- **Los 7 de `in-progress` ya no esperan criterio**: las cuatro decisiones que los bloqueaban se
  tomaron hoy y están escritas en sus tickets. Lo que queda es código.
- **`ci-verde-con-la-suite-en-rojo`** — pasos 1 y 2 hechos; 3 y 4 fuera de alcance por decisión.
- Los **2 de `blocked`** esperan **hardware**, no trabajo.

## Release 2.1 (sin cambios)

2.0.5 no se lanza; release = 2.1. A7 y M5: **HOLD, no flip**. Prod: CLOUD_MODE 100 · GROUPS_BACKEND 100
· CLOUD_ONBOARDING_CHOICE 0 · SECONDARY_SESSION 0. Cola C: 9 ACs owner/device, no corrida; D-R1 sigue
sin `ok_`. **Cero `ok_` inventado.**

## Board

95 tickets · backlog 48 · in-progress 7 · qa 20 · blocked 2 · done 13 · discarded 5. Índice cuadrado
(95 filas = 95 ficheros, verificado por diff). `qa` significa «esperando la tanda», no «cerrado».

Migraciones aplicadas hoy en **los dos entornos**: `g13_02` (el rechazado ve su propia fila) y `g13_03`
(el grupo borrado deja de confundirse con un enlace inválido), con su gemelo en `prod-promo-sql/`.

**Método, lo que más se repitió:** cinco veces un cero mío vino del FILTRO y no del código, y una sexta
busqué en el sitio equivocado —el repo en vez de la base de datos— y reporté como bloqueo algo que
llevaba horas hecho. Antes de reportar una ausencia: control positivo; y si es estado del servidor, se
mide contra el servidor.
