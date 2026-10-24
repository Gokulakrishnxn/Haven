import type { Metadata, Viewport } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Haven — Point at anything. Haven does the rest.",
  description:
    "Haven is a native Mac app that puts your AI agent one shortcut away. Point at anything, say what you want, and keep working while it gets done.",
  openGraph: {
    title: "Haven",
    description: "Point at anything. Haven does the rest.",
    type: "website",
  },
};

export const viewport: Viewport = {
  colorScheme: "dark light",
  themeColor: [
    { media: "(prefers-color-scheme: dark)", color: "#000000" },
    { media: "(prefers-color-scheme: light)", color: "#fbfbfd" },
  ],
};

export default function RootLayout({ children }: LayoutProps<"/">) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
