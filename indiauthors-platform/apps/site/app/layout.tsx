import type { Metadata } from "next";
import "./globals.css";
import { buildPageMetadata } from "../lib/seo";

export const metadata: Metadata = buildPageMetadata({
  title: "Indie Authors | AuthorOS for Independent Writers",
  description:
    "Indie Authors is the home of AuthorOS, a writing and story planning platform for independent authors.",
  path: "/",
  keywords: [
    "author software",
    "writing software",
    "novel writing software",
    "story planning software",
    "indie author tools",
    "AuthorOS"
  ]
});

export default function RootLayout({
  children
}: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="en">
      <body>
        <a className="skip-link" href="#main-content">
          Skip to content
        </a>
        {children}
      </body>
    </html>
  );
}
