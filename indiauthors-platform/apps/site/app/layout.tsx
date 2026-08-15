import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  metadataBase: new URL("https://indiauthors.com"),
  title: "Indie Authors | AuthorOS for Independent Writers",
  description:
    "Indie Authors is the home of AuthorOS, a writing and story planning platform for independent authors.",
  openGraph: {
    title: "Indie Authors",
    description:
      "Explore AuthorOS, manage your account, licenses, and downloads.",
    url: "https://indiauthors.com",
    siteName: "Indie Authors",
    type: "website"
  },
  alternates: {
    canonical: "https://indiauthors.com"
  }
};

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
