/**
 * Cuándo una cifra lleva «≈». Port de `ApproximateMarkThreshold` (Yala/App/Logic/Helpers/ApproximateMarkThreshold.swift):
 * se marca si la magnitud dudosa llega al 5 % de la magnitud total, con un suelo de ruido de 0,01.
 */
export const APPROX_FRACTION = 0.05;
const NOISE_FLOOR = 0.01;

export function marksApproximate(approximate: number, total: number): boolean {
  const a = Math.abs(approximate);
  if (!(a > NOISE_FLOOR)) return false;
  const t = Math.abs(total);
  if (!(t > NOISE_FLOOR)) return true;
  return a >= APPROX_FRACTION * t * (1 - 1e-9);
}
