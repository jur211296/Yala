---
name: reference-contar-el-store-del-iphone-con-devicectl
description: Para saber QUÉ hay en el store de Yala Dev del iPhone de pruebas (conteo por entidad), copiarlo con devicectl desde el App Group y contar con sqlite3
metadata:
  type: reference
---

El store NO está en el contenedor de la app: está en el **App Group**.

    xcrun devicectl device copy from --device <UDID del 14> --domain-type appGroupDataContainer \
      --domain-identifier group.com.jurgenschmidt.yala.dev --source "Library/Application Support" --destination <dir>

Trae `YalaModel-Dev.store` (+ wal/shm), `YalaGroups-Dev.store`, `YalaSyncMeta-Dev.store`. Copia el directorio antes de
abrirlo y cuenta `select count(*) from Z<ENTIDAD>`. Con `appDataContainer` sale vacío (solo tipkit y spotlight).

**Why:** 2026-11-05, card i9wh: «qué son los 3333 elementos» llevaba un día sin medir; el conteo dio 3234 tipos de cambio
(383 días, hasta 9 copias) en cinco minutos, sin otra activación ni Jürgen. Funciona con el 14 «available (paired)».

**How to apply:** cuando una card pregunte qué datos tiene el teléfono de pruebas, mide así antes de pedir otra prueba.
Junto con [[reference-linea-de-tiempo-de-una-activacion]] da el qué y el cuándo.
