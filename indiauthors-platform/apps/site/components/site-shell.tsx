import Link from "next/link";
import { primaryNav, siteConfig } from "../content/site";

export function SiteShell({ children }: { children: React.ReactNode }) {
  return (
    <div className="site-bg">
      <header className="topbar">
        <div className="container topbar-inner">
          <p className="brand-eyebrow">{siteConfig.brand}</p>
          <nav aria-label="Primary navigation">
            <ul className="topnav">
              {primaryNav.map((item) => (
                <li key={item.href}>
                  <Link href={item.href}>{item.label}</Link>
                </li>
              ))}
            </ul>
          </nav>
        </div>
      </header>
      <main id="main-content" className="container">{children}</main>
      <footer className="footer container">
        <p>{siteConfig.brand}</p>
        <p>{siteConfig.product} is a product by {siteConfig.brand}.</p>
      </footer>
    </div>
  );
}
