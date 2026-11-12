---
id: reverse-ineligible-copy-says-right-now-for-a-permanent-case
status: done
priority: low
area: "modo-nube, settings, l10n"
created: 2026-10-21
updated: 2026-10-21
source: "tablero-ahora-mismo-no-puedes-volver-a-icloud-de-i9qh (QA guiado 2026-10-19)"
---

# «Ahora mismo no puedes volver a iCloud» en un teléfono donde no se podrá nunca

## En lenguaje de usuario

En un iPhone que entró en una cuenta de la nube creada en otro, «Dónde viven tus datos» decía «Ahora mismo no puedes
volver a iCloud desde este dispositivo», sin decir por qué ni qué hacer.

## Lo que cambia

Con `ReverseEligibility.degradedNoMap` la tarjeta dice: «Tu cuenta llegó a la nube desde otro dispositivo, así que la
vuelta a iCloud se hace desde ese, si aún tiene Yala. Aquí puedes seguir usando la nube.» (16 idiomas). El mapa ilegible
(`.mapUnreadable`, que sí puede cambiar) conserva el «ahora mismo».

Residual: un teléfono que creó su cuenta en la nube con un build anterior a la marca `isBornCloud` cae en el mismo caso
y lee «desde otro dispositivo».

## Tests

`ReverseIneligibleOtherDeviceUITests` (seam `-uitest-adopted-cloud-storage`; la condición es el caso nacido aquí).
