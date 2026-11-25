# Entorno de desarrollo limpio antes de la 2.3 (10) — 25-nov-2026

Para que Jürgen pruebe la bienvenida de Yala Dev desde cero en el iPhone 14. **Producción no se tocó.**
Sin correos ni datos personales: los usuarios se nombran por los 8 primeros caracteres de su id.

## Evidencia de que el destino era desarrollo

| Qué | Desarrollo (lo que se borró) | Producción (no se tocó) | De dónde sale |
|---|---|---|---|
| Supabase | `fostjbbwstyuunmmefuk` · «yala-modo-nube-staging» | `kefvaiymtgytemwbltlz` · «yala-modo-nube-production» | `Yala/App/Services/CloudBackendConfig.swift`: `DEV_BUILD` → staging. La Management API lista los dos con esos nombres. |
| Gateway (Cloudflare) | Worker `yala-gateway-staging`, D1 `yala-gateway-staging` (`6f76834b…`), KV `66bcbb46…` | `yala-gateway-production`, D1 `60cdd68d…`, KV `af4bd878…` | `gateway/wrangler.toml` (`[vars]` vs `[env.production]`) y `ProxyConfig.swift` (`DEV_BUILD` → staging). |
| Conector de IA | KV `yala-mcp-staging-oauth` (`97058869…`) | `yala-mcp-production-oauth` (`3683c133…`) | `mcp/wrangler.toml`. |
| iCloud | `iCloud.com.jurgenschmidt.yala.dev` y `iCloud.com.jurgenschmidt.yala.groups.dev`, entorno **Development** | `iCloud.com.jurgenschmidt.yala` y `…yala.groups` | `SwiftDataConfiguration.cloudKitContainerIdentifier`: el App Group `.dev` de Yala Dev elige `.dev`. Yala Dev se firma en desarrollo (`aps-environment = development`), así que usa el entorno Development. |

## Lo que se borró

### Supabase de desarrollo

| Proveedor | Antes | Después |
|---|---|---|
| Google | 2 | **0** |
| Apple | 0 | 0 |
| Correo (usuarios sintéticos de las pruebas del servidor) | 4 | 4 (se quedan, ver abajo) |
| **Total `auth.users`** | 6 | **4** |

Borrado con las funciones de la propia app (`groups_forget_user` y `delete_personal_account`, las que usa «Eliminar mi
cuenta»), una por cuenta. Filas borradas, sumando las dos cuentas: movimientos 2.370 · tipos de cambio 1.176 ·
subcategorías 143 · avisos 35 · preferencias 16 · categorías 13 · etiquetas 10 · pagos planificados 10 · cuentas 9 ·
borradores de la Bandeja 9 · presupuestos 7 · tokens de notificaciones 2 · memoria de comercios 1 · contador de sync 1 ·
perfil 1 · identidades 2. Sin grupos. Después: 0 filas huérfanas.

**Por qué quedan 4:** son los usuarios `…@test.yala` de las pruebas del gateway contra staging (uno entró hoy). Jürgen
decidió el 16-nov que «limpiar staging» no los incluye; borrarlos rompe esas pruebas hasta recrearlos. No son cuentas
de la app ni aparecen en ningún teléfono.

### Gateway de staging (D1 y KV)

- D1: 2 filas de una cuenta que ya no existía (dirección de correo del banco y un correo visto). Las demás filas son de
  los usuarios sintéticos.
- KV del conector: 1 permiso OAuth de esa misma cuenta huérfana.
- Se quedan las **116 llaves de App Attest** (son de dispositivo, ninguna con Pro de prueba) y las sesiones web de los
  sintéticos. La KV del gateway ya estaba vacía. Suscripciones vinculadas: 0.

### iCloud de desarrollo

- `cktool reset-schema` sobre el entorno Development de los dos contenedores dev: borra **todos los datos** de ese entorno
  (también las bases privadas de cada Apple ID) y deja el esquema igual al de Producción.
- Antes se comprobó que el esquema de Development era idéntico al de Producción en los dos (`export-schema` + `diff`),
  así que no hubo que reimportar nada. Después del reset, el `diff` vuelve a dar idéntico.

## Lo que no se puede borrar desde fuera

- **El almacén clave-valor de iCloud de Yala Dev** (en el Apple ID del teléfono). Guarda el «faro» que dice «este Apple ID
  ya tuvo una cuenta en la nube». No hay API para borrarlo desde la Mac: la app lo limpia sola cuando comprueba que esa
  cuenta ya no existe. Si la bienvenida dice al principio «ya tienes una cuenta», es eso, y debería corregirse solo.
