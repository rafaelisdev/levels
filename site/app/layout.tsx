import type { Metadata, Viewport } from "next";
import { Analytics } from "@vercel/analytics/next";
import { Geist_Mono, Inter_Tight } from "next/font/google";
import { site } from "@/lib/site";
import "./globals.css";

const isProduction = !process.env.VERCEL_ENV || process.env.VERCEL_ENV === "production";

const sans = Inter_Tight({ subsets: ["latin"], variable: "--font-sans", display: "swap" });
const mono = Geist_Mono({ subsets: ["latin"], variable: "--font-mono", display: "swap" });

export const metadata: Metadata = {
  metadataBase: new URL(site.url),
  title: { default: site.title, template: "%s | Levels" },
  description: site.description,
  applicationName: site.name,
  keywords: [
    "per-app volume mac",
    "macOS volume mixer",
    "app volume control mac",
    "menu bar volume",
    "Core Audio process tap",
    "homebrew cask",
  ],
  alternates: { canonical: "/" },
  openGraph: {
    type: "website",
    url: "/",
    siteName: site.name,
    title: site.title,
    description: site.description,
  },
  twitter: { card: "summary_large_image", title: site.title, description: site.description },
  // Preview builds (e.g. getlevels.vercel.app on the pre-production branch) must not compete with getlevels.app.
  robots: isProduction ? { index: true, follow: true } : { index: false, follow: false },
};

export const viewport: Viewport = {
  themeColor: "#ffffff",
  colorScheme: "light",
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" className={`${sans.variable} ${mono.variable}`}>
      <body>
        {children}
        <Analytics />
      </body>
    </html>
  );
}
