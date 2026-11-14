---
name: una-cifra-igual-a-la-semilla-no-prueba-nada
description: «Cargar datos de prueba» usa semilla fija: la misma cifra en dos sitios (2351) no prueba que uno copie al otro; mide antes y después de cargar
metadata:
  type: feedback
---

La card 4lld del barrido infería que una cuenta en la nube exportaba al iCloud del teléfono porque «Volver a tu iCloud»
contaba 2351 registros, los mismos que «Cargar datos de prueba». `DevSeedService` siembra con `SeededRandom(seed: 42)`:
el mismo día da la misma cifra en cualquier modo, así que iCloud ya los tenía de una carga anterior en modo iCloud.
Medido el 14-nov: cuenta nueva vacía → iCloud 2359; tras cargar 2351 en la cuenta → 2359; cero eventos del espejo y cero
tablas `ANSCK*` en el almacén copiado. La card cerró sin código.

**Why:** una coincidencia de cifras con datos deterministas parece una prueba y es la mitad de una.

**How to apply:** para «¿llega X a iCloud?», mide N antes y después de crear X (la pregunta previa de «Volver a tu
iCloud» cuenta iCloud de verdad) y mira `iCloudSync: event received` en la consola y `sqlite_master like 'ANSCK%'` en el
store copiado ([[reference-contar-el-store-del-iphone-con-devicectl]]). Y «Remote CloudKit change» de `AppBootstrapper`
no prueba espejo: lo dispara cualquier escritura de otro coordinador.
