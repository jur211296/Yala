/**
 * Config del estudio de vídeo de Yala.
 *
 * Nota: cuando se usan las APIs de Node, este fichero NO aplica; ahí las
 * opciones se pasan directas a la API.
 * Todas las opciones: https://remotion.dev/docs/config
 */

import { Config } from "@remotion/cli/config";
import { enableTailwind } from "@remotion/tailwind-v4";

// ⚠️ rspack APAGADO a propósito, y el scaffold oficial lo trae ENCENDIDO.
//
// Medido el 2026-09-11 con Remotion 4.0.523 + bun 1.3.11 en macOS arm64:
// con `setRspack(true)` el bundle sale SIN `bundle.js` —solo index.html,
// favicon y public/— y el render muere con un ENOENT de source-map
// (`getSourceMapFromLocalFile`) que no menciona el bundler por ningún lado.
// Pasa igual con y sin Tailwind, así que no es el override: es rspack.
// Con webpack el bundle trae sus 40 chunks y el render sale.
//
// Antes de volver a encenderlo: `bunx remotionb bundle --out-dir=/tmp/x` y
// comprobar que existe `/tmp/x/bundle.js`. Si existe, esta nota ya caducó.
Config.setRspack(false);

Config.setVideoImageFormat("jpeg");
Config.setOverwriteOutput(true);
Config.overrideBundlerConfig(enableTailwind);
