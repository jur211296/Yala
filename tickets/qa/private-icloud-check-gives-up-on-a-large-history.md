---
id: private-icloud-check-gives-up-on-a-large-history
status: qa
priority: high
area: "onboarding, modo-nube, iCloud"
created: 2026-10-20
updated: 2026-10-20
source: "tablero-no-pudimos-conectarnos-a-icloud-al-elegi-blqa (QA guiado del TF19, 2026-10-20)"
---

# «No pudimos conectarnos a iCloud» al elegir iCloud privado con un iCloud con mucho historial

## En lenguaje de usuario

Elijo «Tu cuenta en tu iCloud privado» (en el Welcome o en «Activar Yala completo»), Yala se queda un rato en «Revisando…» y me dice «No pudimos conectarnos a iCloud · Puede ser la conexión». Lo reintento y sale lo mismo. Mi conexión está bien; lo que pasa es que mi iCloud tiene mucho historial.

## Lo medido (2026-10-20)

- `ICloudPersonalCorpusProbe.measureFromCloudKit` cortaba con un plazo TOTAL de 25 s (`scanDeadline`), mirado solo entre páginas. La revisión del adopt (`findAdoptRelevantRecord`, 25 s) y la de la vuelta a iCloud (`scanForeignCorpus`, 60 s) tenían el mismo molde.
- En el iPhone de QA la consola no imprimió «probe failed»: no fue un `CKError`, fue el plazo.
- **Inferido, sin medir**: que la zona devuelva muchas páginas de borrados. El simulador no tiene CloudKit; queda en el rastro (abajo).

## Lo que cambia

- Las tres revisiones pasan por un solo recorrido, `ICloudZoneScan`, con **plazo SIN avance** (el molde del #564): se corta solo si una espera —la lista de zonas o una página— pasa de 25 s (60 s en la vuelta). Avanzar es que llegue una página, traiga registros, solo borrados o nada. Sin plazo total: «Revisando…» tiene su «Volver».
- El motivo pasa de `scanDeadline` a `scanStalled` (`ICloudZoneScanEnd.stalledReason`); cambia la serie de los canarios que lo llevan (`cloudAdoptICloudCorpusChecked failed:<motivo>`).
- **Texto propio cuando fue el plazo** en la puerta privada: «iCloud tardó demasiado en responder · No pudimos terminar de revisar tu iCloud…», y su variante «…así que no borramos nada». No habla de la conexión. Los demás fallos conservan el de siempre. 16 idiomas.
- Rastro de cada revisión (sin PII): `ICloudScan[probe|adopt|reverse] end=… pages=… records=… deletions=…` en la categoría `CloudSync` del Logger.

## Tests

`ICloudZoneScanTests` (40 páginas de 2 s terminan; una espera de 26 s corta; frontera 25/25,5; páginas solo de borrados; fallo parcial; parada del llamador; zona borrada; el texto solo con el plazo) y `ICloudZoneScanWiringTests` (las tres revisiones por el recorrido, sin plazo total; la puerta elige el texto por el motivo). XCUITest `PrivateGateProbeStalledUITests` con el seam `-uitest-private-gate-probe-stalled`.

## Device-QA (Jürgen, iPhone de QA, Yala Dev con el contenedor de test@)

1. En el iPhone de QA, con la sesión solo-grupos de admin@, Perfil › «Activar Yala completo» › «Tu cuenta en tu iCloud privado».
2. Esperado: contesta con cifras (o «vacío»), sin «No pudimos conectarnos a iCloud». Puede tardar más de 25 s.
3. Si aun así sale un aviso, debe decir «iCloud tardó demasiado en responder». Con la Mac conectada, la consola filtrada por `ICloudScan` dice cuántas páginas y borrados devolvió.
