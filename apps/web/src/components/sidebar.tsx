"use client"

import Link from "next/link"
import { usePathname } from "next/navigation"
import { Logo } from "@repo/ui"

const navItems = [
  { href: "/dashboard", label: "Dashboard" },
  { href: "/stocks", label: "Research stocks" },
  { href: "/options", label: "Options" },
] as const

export function Sidebar() {
  const pathname = usePathname()

  return (
    <aside className="flex w-56 flex-col border-r border-gray-200 bg-white">
      <div className="flex h-16 shrink-0 items-center border-b border-gray-200 px-4">
        <Link
          href="/dashboard"
          className="shrink-0"
          aria-label="mnml trade home"
        >
          <Logo height={32} className="block" />
        </Link>
      </div>
      <nav
        className="flex flex-1 flex-col gap-0.5 p-3"
        aria-label="Main navigation"
      >
        {navItems.map(({ href, label }) => {
          const isActive =
            pathname === href ||
            (href !== "/dashboard" && pathname.startsWith(href))
          return (
            <Link
              key={href}
              href={href}
              className={`rounded-lg px-3 py-2.5 text-sm font-medium transition-colors ${
                isActive
                  ? "bg-primary-50 text-primary-700"
                  : "text-gray-700 hover:bg-gray-100 hover:text-gray-900"
              }`}
            >
              {label}
            </Link>
          )
        })}
      </nav>
    </aside>
  )
}
