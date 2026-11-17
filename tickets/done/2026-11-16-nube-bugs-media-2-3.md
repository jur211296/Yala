---
id: 2026-11-16-nube-bugs-media-2-3
status: done
priority: medium
area: "modo-nube"
created: 2026-11-16
updated: 2026-11-16
source: "encargo del 16-nov (Jürgen: «encola… también los cinco bugs media»); criterio de salida de 2.3: cero bugs de nube de prioridad media"
---

# Nube 2.3: los cinco bugs de prioridad media

## 1 · Volver a la nube con la misma cuenta (card «2.3 · Poder volver a la nube con la misma cuenta»)

Decisión de Jürgen (16-nov, 17:51): **opción A**, volver a pasar es una activación nueva que REEMPLAZA la copia congelada
por lo que hay en iCloud. Servidor `qa/cloud/g31_01_*` (aplicado en staging; Producción con su visto bueno), Worker
(`p_recutover` solo con `recutover: true`, desplegado en staging), app (el claim de «Migrar» manda `recutover`) y la hoja de
volver a iCloud deja de decir «Hoy no se puede». Probado de punta a punta en el iPhone 14 contra staging (README de
`qa/cloud`, sección g31_01). Regla: `.claude/rules/swiftdata-cloudkit.md`, «Volver a pasar a la nube…».

## 2 · Modo iCloud: la salida se llama «Cerrar sesión»

Decisión de Jürgen del 13-nov. Sin cuenta de Yala la fila de Ajustes se llama «Cerrar sesión», su hoja usa el título y el
botón del cierre de siempre y su nota nombra «Entrar con iCloud privado» (el botón de la bienvenida 2.3, leído del propio
botón). «Sesión cerrada» queda igual. No cambia: el aviso de los 45 s («Quitar mis datos igualmente», decisión A del
19-oct) ni el texto de progreso.

## 3 · «Tus datos ya están en tu cuenta» con la cuenta vacía

Medido: el aviso del Panel no lo dispara el faro sino cualquier marcador de migración del iCloud, de cualquier cuenta. Se
toma la recomendada «comprobar antes de afirmarlo»: el aviso exige un marcador de la cuenta que nombra el faro. «Dónde
viven tus datos» no cambia.

## 4 · Lo que llega a iCloud después de la comprobación del adopt

Números de la flota y política en `tickets/done/adopt-window-uploads-what-reaches-the-mirror-after-the-icloud-check.md`:
0 altas `mirror` en 90 días; sin política de bloqueo, el canario sigue.

## 5 · Filas que fallan al volver a iCloud

Medición en el iPhone 14 y la flota en `tickets/done/reverse-upload-failed-rows-need-a-device-measurement.md`: ningún fallo
por fila; ningún motivo pasa a contar.

## Encontrado

- `reverse-on-the-iphone-left-the-local-store-empty` (backlog, high): tras «Volver a tu iCloud» en el iPhone 14 el store
  local quedó vacío y salió «Datos no disponibles».
