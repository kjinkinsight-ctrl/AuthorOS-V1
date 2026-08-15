import Link from "next/link";

export function SiteShell({ children }: { children: React.ReactNode }) {
  return (
    <div className="site-bg">
      <header className="topbar">
        <div className="container topbar-inner">
          <p className="brand-eyebrow">Indie Authors</p>
          <nav aria-label="Primary navigation">
            <ul className="topnav">
              <li><Link href="/">Home</Link></li>
              <li><Link href="/authoros">AuthorOS</Link></li>
              <li><Link href="/explore">Explore</Link></li>
              <li><Link href="/pricing">Pricing</Link></li>
              <li><Link href="/account">Account</Link></li>
            </ul>
          </nav>
        </div>
      </header>
      <main id="main-content" className="container">{children}</main>
      <footer className="footer container">
        <p>Indie Authors</p>
        <p>AuthorOS is a product by Indie Authors.</p>
      </footer>
    </div>
  );
}
