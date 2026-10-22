---
id: reverse-exit-leaves-a-partial-copy-in-icloud
status: backlog
priority: low
area: "modo-nube, migración"
created: 2026-09-16
updated: 2026-10-08
source: "review adversarial de `reverse-upload-has-no-ceiling-and-no-exit` (2026-09-16), lente de datos — H4"
---

# Al salir de la vuelta a iCloud, lo que ya subió se queda en iCloud sin dueño

## El problema, en lenguaje de usuario

Empiezo «Volver a iCloud», sube una parte y salgo: sigo en la nube. Meses después cierro sesión de la nube y elijo
mi iCloud privado, o abro Yala en un iPad en modo privado con el mismo Apple ID, y aparece una copia vieja y a medias
de mis datos.

## Por qué pasa

- La salida de `reverseUpload` (`[.rearmMirrorOff, .reverseRollback]`) no toca la zona de CloudKit: lo exportado se
  queda allí. Hasta relanzar, el espejo sigue montado y exporta también lo que la persona anota.
- Nada es dueño de esa copia: no hay marcador para una cuenta nacida en la nube, ni limpieza.
- Si después la persona vuelve al modo privado, `ICloudPersonalCorpusProbe` la encuentra y el espejo la importa
  como si fuera su copia; un iPad en modo privado del mismo Apple ID la importa igual.

## Por qué no se tocó

Limpiar la zona antes de re-armar el apagado del espejo no es un cambio mínimo, y un siguiente intento de «Volver a
iCloud» APROVECHA esa copia (el espejo conserva su metadata y solo sube lo que falta). Borrarla tiraría ese avance.

## Criterios de aceptación

- [ ] Decidido si la copia parcial se conserva (para reintentar) o se limpia, y cuándo.
- [ ] Si se conserva, la vuelta al modo privado no la importa como si fuera la copia buena sin avisar.

## Relacionado

- `reverse-upload-has-no-ceiling-and-no-exit` · `reverse-cancel-pushes-what-the-mirror-imported-during-the-wait`.

## Medido en 2.1 (triage 2026-10-08)

- `MigrationStateMachine` sigue saliendo de `reverseUpload` con `effects: [.rearmMirrorOff, .reverseRollback]`; ninguno toca la zona ni deja marcador de dueño. Sin commits que lo cambien desde el 2026-09-16.
- Recomendación sobre la decisión: **conservar la copia** (un reintento de «Volver a iCloud» la aprovecha) y que la vuelta al modo privado o un dispositivo en privado avise antes de importarla como la buena, que es el segundo criterio. La prioridad es la de esa opción.

Triage 2026-10-08: abierto · low → low · exige salir a mitad de la vuelta y, después, volver a privado o abrir otro dispositivo en privado con el mismo Apple ID.
