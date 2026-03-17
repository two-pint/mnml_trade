"use client"

import { useEffect } from "react"
import Link from "next/link"
import { useRouter } from "next/navigation"
import { Logo } from "@repo/ui"
import { useAuth } from "@/lib/auth-context"
import { useTheme } from "@/lib/theme-context"
import { StockSearch } from "@/components/stock-search"
import { ThemeToggle } from "@/components/theme-toggle"

export default function AppLayout({ children }: { children: React.ReactNode }) {
  const { user, loading, logout } = useAuth()
  const { resolvedTheme } = useTheme()
  const router = useRouter()

  useEffect(() => {
    if (!loading && !user) {
      router.replace("/login")
    }
  }, [user, loading, router])

  if (loading) {
    return (
      <div className="flex min-h-screen items-center justify-center bg-zinc-50 dark:bg-zinc-900">
        <div className="h-8 w-8 animate-spin rounded-full border-4 border-primary-200 border-t-primary-600" />
      </div>
    )
  }

  if (!user) return null

  return (
    <div className="flex min-h-screen flex-col bg-zinc-50 dark:bg-zinc-900">
      <header className="sticky top-0 z-40 border-b border-zinc-200 bg-white dark:border-zinc-700 dark:bg-zinc-900">
        <div className="mx-auto flex max-w-7xl items-center gap-4 px-4 py-3 sm:px-6">
          <Link
            href="/dashboard"
            className="shrink-0"
            aria-label="mnml trade home"
          >
            <Logo height={36} dark={resolvedTheme === "dark"} className="block" />
          </Link>
          <div className="min-w-0 flex-1">
            <StockSearch />
          </div>
          <div className="flex shrink-0 items-center gap-1">
            <ThemeToggle />
            <Link
              href="/watchlist"
              className="rounded-lg px-3 py-1.5 text-sm font-medium text-zinc-700 transition-colors hover:bg-zinc-100 dark:text-zinc-300 dark:hover:bg-zinc-700"
            >
              Watchlist
            </Link>
            <Link
              href="/portfolio"
              className="rounded-lg px-3 py-1.5 text-sm font-medium text-zinc-700 transition-colors hover:bg-zinc-100 dark:text-zinc-300 dark:hover:bg-zinc-700"
            >
              Portfolio
            </Link>
            <Link
              href="/profile"
              className="rounded-lg px-3 py-1.5 text-sm font-medium text-zinc-700 transition-colors hover:bg-zinc-100 dark:text-zinc-300 dark:hover:bg-zinc-700"
            >
              {user.username || user.email}
            </Link>
          </div>
        </div>
      </header>
      <main className="flex-1">{children}</main>
    </div>
  )
}
