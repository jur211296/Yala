// Movido a shared-core/ (núcleo compartido con Yala web). Se queda este reexport para que el gateway, que importa
// esta ruta, siga igual. Código nuevo: importa de shared-core.
export * from "../../shared-core/src/supabaseEnv";
