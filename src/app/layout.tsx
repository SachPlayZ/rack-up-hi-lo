import type { Metadata, Viewport } from "next";
import { Barlow_Condensed, Bowlby_One_SC } from "next/font/google";
import { Providers } from "@/components/providers";
import "./globals.css";

const display = Bowlby_One_SC({
  subsets: ["latin"],
  weight: "400",
  variable: "--font-display",
  display: "swap",
});

const body = Barlow_Condensed({
  subsets: ["latin"],
  weight: ["400", "500", "600", "700"],
  variable: "--font-body",
  display: "swap",
});

export const metadata: Metadata = {
  title: { default: "Rack Up — Onchain Hi-Lo", template: "%s — Rack Up" },
  description: "A live, verifiably random Hi-Lo pool game on Base Sepolia.",
};

export const viewport: Viewport = {
  width: "device-width",
  initialScale: 1,
  maximumScale: 1,
  viewportFit: "cover",
  themeColor: "#071b15",
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="en" className={`${display.variable} ${body.variable}`}>
      <body>
        <Providers>{children}</Providers>
      </body>
    </html>
  );
}
