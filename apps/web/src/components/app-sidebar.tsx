"use client"

import Link from "next/link"
import { usePathname } from "next/navigation"
import { Logo } from "@repo/ui"
import { useTheme } from "@/lib/theme-context"
import { PortfolioNavSection } from "@/components/portfolio-nav-section"

const NAV = [
  { href: "/dashboard", label: "Dashboard" },
  { href: "/watchlist", label: "Watchlist" },
] as const

function navLinkClass(active: boolean) {
  return [
    "block rounded-lg px-3 py-2 text-sm font-medium transition-colors",
    active
      ? "bg-primary-50 text-primary-700 dark:bg-primary-950/50 dark:text-primary-300"
      : "text-zinc-700 hover:bg-zinc-100 dark:text-zinc-300 dark:hover:bg-zinc-800",
  ].join(" ")
}

function isNavActive(pathname: string, href: string) {
  return pathname === href || (href !== "/" && pathname.startsWith(`${href}/`))
}

type AppSidebarProps = {
  onNavigate?: () => void
  className?: string
}

export function AppSidebar({ onNavigate, className = "" }: AppSidebarProps) {
  const pathname = usePathname()
  const { resolvedTheme } = useTheme()

  return (
    <div className={`flex h-full min-h-0 flex-col ${className}`.trim()}>
      <div className="border-b border-zinc-200 px-4 py-4 dark:border-zinc-700 flex items-center h-16
      ">
        <Link
          href="/dashboard"
          className="inline-block"
          aria-label="mnml trade home"
          onClick={onNavigate}
        >
          <Logo height={24} dark={resolvedTheme === "dark"} className="block" />
        </Link>
      </div>
      <nav
        className="flex-1 space-y-0.5 overflow-y-auto px-3 py-4"
        aria-label="Main"
      >
        {NAV.map(({ href, label }) => (
          <Link
            key={href}
            href={href}
            onClick={onNavigate}
            className={navLinkClass(isNavActive(pathname, href))}
          >
            {label}
          </Link>
        ))}
        <PortfolioNavSection onNavigate={onNavigate} />
      </nav>
    </div>
  )
}
