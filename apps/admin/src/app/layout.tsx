import type { Metadata } from "next";
import { APP_NAME } from "@iitk-bicycle/shared";
import "./globals.css";

export const metadata: Metadata = {
  title: `${APP_NAME} Admin`,
  description: "Admin console for the IIT Kanpur campus bicycle pool.",
};

export default function RootLayout({ children }: LayoutProps<"/">) {
  return (
    <html lang="en" className="h-full antialiased">
      <body className="min-h-full flex flex-col">{children}</body>
    </html>
  );
}
