import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "FutureTrust Broker Dashboard",
  description: "Trust-first broker attribution and lead protection dashboard.",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en" className="h-full antialiased">
      <body className="min-h-full flex flex-col">{children}</body>
    </html>
  );
}
