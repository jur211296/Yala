Yala
# Nube 2.3: los cinco bugs de prioridad media (volver a la nube, salida de iCloud, aviso falso y dos mediciones)
---
toca: Yala/App/Logic/BeaconOrphanLogic.swift, Yala/App/Logic/ReverseUploadWaitingCopyLogic.swift, Yala/App/Logic/StorageMigrationIdentityGateLogic.swift, Yala/App/Logic/StorageMigrationSignInLogic.swift, Yala/App/Logic/SyncSignInBannerLogic.swift, Yala/App/Views/Settings/StorageSettingsView.swift, Yala/Services/CloudSync/CloudBeacon.swift, Yala/Services/CloudSync/CloudMigrationController.swift, Yala/Services/CloudSync/MigrationRunner.swift, Yala/Services/CloudSync/ICloudCutoverGateLogic.swift, Yala/Utils/L10n+Nube23Media.swift, Yala/Resources/*.lproj/Localizable.strings, YalaTests/Nube23Media/, tickets/backlog/adopt-window-uploads-what-reaches-the-mirror-after-the-icloud-check.md, tickets/backlog/reverse-upload-failed-rows-need-a-device-measurement.md, tickets/done/2026-11-16-nube-bugs-media-2-3.md
esfuerzo: high
cierre: cierra-sola
---

Encargo autorizado por Jürgen el 16-nov en el chat («encola… también los cinco bugs media»). El criterio de salida de 2.3 en `docs/ROADMAP.md` pide cero bugs de nube de prioridad media. Son estas cinco cards de la 2.3:

1. «2.3 · Poder volver a la nube con la misma cuenta»: después de pasar de la cuenta de Yala a iCloud, se puede volver a la nube con esa misma cuenta. Se dejó para decidir en la discusión del 9-nov: si el diseño tiene una decisión de producto real, presenta opciones y recomendación; si es directo, constrúyelo.
2. «Modo iCloud: la salida se llama "Cerrar sesión" y su hoja se reescribe» (ya decidida por Jürgen el 13-nov): en Ajustes, modo iCloud, la salida se llama «Cerrar sesión» y la hoja nombra los botones que existen hoy («Entrar con mi iCloud» en la bienvenida). «Sesión cerrada» al final queda igual.
3. «Tras dejar iCloud aparte, el modo privado dice "Tus datos ya están en tu cuenta en la nube" con esa cuenta vacía»: el faro (`CloudBeacon`) dispara el aviso aunque la cuenta no tenga datos. Elige la recomendada entre comprobar que la cuenta tiene datos antes de afirmarlo o no escribir el faro en la entrada que deja iCloud aparte, y anótalo.
4. «Decidir qué hacer con lo que llega a iCloud después de la comprobación del adopt» (ticket `adopt-window-uploads-what-reaches-the-mirror-after-the-icloud-check.md`, canario del PR #359).
5. «Medir en un iPhone por qué fallan filas al volver a iCloud, y decidir qué motivos cuentan» (ticket `reverse-upload-failed-rows-need-a-device-measurement.md`).

Para 4 y 5: haz tú la medición en el iPhone 14 por DeviceMCP (guion del ticket) en lugar de esperar a Jürgen. La política final es decisión de Jürgen: entrégale los números con opciones y recomendación en el artifact; si la recomendada es menor y reversible, impleméntala y anótala; si es vital, pregúntala según el modo.

Textos nuevos en `Yala/Utils/L10n+Nube23Media.swift`, en los 16 idiomas. Tests nuevos en `YalaTests/Nube23Media/`. Nada de cambios de esquema en CloudKit o Supabase Production sin GO de Jürgen. Si tocas un archivo de nube que no está en `toca:`, que sea mínimo y anótalo.

## Reglas
- Commit y PR contra 2.3, sin firma de IA.
- Simuladores: en la Max puedes usar un segundo simulador además del de otra sesión, o el iPhone 14 por DeviceMCP.
- Entrega visual: artifact visual de Claude con cada bug antes y después, y las mediciones (no Markdown).
- Cierre según el modo fijado al arrancar: semi con trabajo completo, `/cerrar-total`; nocturno, si queda algo vital, checkpoint sin completar ni mergear lo incompleto, card abierta «Espera decisión». El cierre incluye «Saltado o asumido sin preguntar» y «Decidido sin consultar» (con motivo o «Nada»).

## Paso 0 — decisiones (semi; las de producto, de Jürgen)

1. **Volver a la nube con la misma cuenta** — decisión de producto: **Jürgen eligió A** el 16-nov (17:51 Lima): volver a pasar es una activación nueva que REEMPLAZA la copia congelada por lo de iCloud. Staging primero, Producción solo con su visto bueno (vital).
   - Servidor: `claim_account` gana `p_recutover` (default false). Con él + `p_migration` sobre una cuenta `groups_only` con `reverted_at` y sin ida ni vuelta en curso: perfil a `complete`, sin congelar, líder este dispositivo; las filas vivas de las 16 tablas personales pasan a BORRADAS (no DELETE: un teléfono rezagado las baja) con `deleted_hlc` = HLC de la fila con nodo al máximo (gana a la fila, pierde con lo que suba el teléfono). `migrated_at` y `personal_adopted_at` a null (cerraban el relevo antes del cutover nuevo).
   - Por qué un parámetro explícito y no la rama por `p_migration`: la entrada de un teléfono nuevo por la bienvenida también reclama con `p_migration`; sin el parámetro, vaciaría la copia desde un teléfono vacío.
   - Worker: pasa `p_recutover` solo cuando es `true` (una base sin g31_01 sigue resolviendo la firma de 4 args). App: lo manda solo el claim de «Migrar» (`marksMigrationAttempt`). Orden: SQL → Worker → app.
   - Cliente sin purga de sync-meta: el cursor viejo baja todo lo retirado (server_seq nuevo) y lo resubido; se verifica de punta a punta en staging.
   - Copy: la hoja de volver a iCloud deja «Hoy no se puede» → «Cuando quieras: lo que tengas en tu iCloud reemplaza lo guardado».
2. **Modo iCloud «Cerrar sesión»** (decidida el 13-nov): fila con `L10n.Settings.signOut`, hoja con el título y botón del cierre de siempre; la nota nombra «Entrar con iCloud privado» (el botón de la bienvenida 2.3 de hoy, leído del propio botón: la card decía «Entrar con mi iCloud», ya no existe). La fila no se mueve de su tarjeta. El texto de progreso («Quitando tus datos…») se queda: dice lo que pasa.
3. **Aviso falso «Tus datos ya están en tu cuenta»** — medido: el aviso del Panel NO lo dispara el faro, sino CUALQUIER `CloudMigrationMarker` del iCloud (de cualquier cuenta). Recomendada y tomada: «comprobar que la cuenta tiene datos antes de afirmarlo», en local: el aviso exige un marcador de la cuenta que nombra el faro (un marcador solo existe con datos verificados). «No escribir el faro en la entrada que deja iCloud aparte» no lo arreglaría. «Dónde viven tus datos» no cambia: allí el marcador elige adopt o «Migrar».
4. **Lo que llega a iCloud tras la comprobación del adopt** — números de la flota (90 días): ninguna alta `mirror|*` (0 en producción y staging); 5 adopts con `none`/`noAccount` en staging, y lo que subió fue `local|…|other` (7 por adopt, del arranque). Recomendada (menor y reversible): sin política de bloqueo, el canario sigue y se reabre si aparece `mirror|none|TransactionItem`. El caso 2 en un iPhone pide un segundo Apple ID con contraseña: no autorizado, se usa la flota.
5. **Filas que fallan al volver a iCloud** — flota: 0 `cloudReverseUploadFailedRows` en 9 vueltas reales (5 teléfonos, staging) y en producción. Se mide además en el iPhone 14 dentro de la prueba de punta a punta del punto 1. Recomendada (menor): ningún motivo pasa a contar hasta que aparezca alguno; el canario sigue.
