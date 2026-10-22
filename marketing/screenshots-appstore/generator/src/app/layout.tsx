import type { Metadata } from "next";
import { Nunito } from "next/font/google";
import "./globals.css";

const nunito = Nunito({ subsets: ["latin"], weight: ["400", "600", "700", "800", "900"] });

export const metadata: Metadata = {
  title: "Yala — App Store Screenshots",
  description: "Generador de screenshots para el App Store de Yala 2.0",
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="es">
      <body className={nunito.className}>{children}</body>
    </html>
  );
}
