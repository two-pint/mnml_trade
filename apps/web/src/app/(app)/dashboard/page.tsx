"use client";

import { useRouter } from "next/navigation";
import { useAuth } from "@/lib/auth-context";

export default function DashboardPage() {
  const { user, logout } = useAuth();
  const router = useRouter();

  function handleLogout() {
    logout();
    router.replace("/login");
  }

  return (
    <div className="flex min-h-screen flex-col">
      <header className="border-b border-gray-200 bg-white">
        <div className="mx-auto flex max-w-5xl items-center justify-between px-6 py-4">
          <h1 className="text-lg font-semibold tracking-tight text-gray-900">
            mnml trade
          </h1>
          <div className="flex items-center gap-4">
            <span className="text-sm text-gray-500">
              {user?.email}
            </span>
            <button
              onClick={handleLogout}
              className="rounded-lg border border-gray-300 px-3 py-1.5 text-sm font-medium text-gray-700 transition-colors hover:bg-gray-50"
            >
              Sign out
            </button>
          </div>
        </div>
      </header>

      <main className="flex flex-1 items-center justify-center px-6">
        <div className="text-center">
          <h2 className="text-3xl font-bold tracking-tight text-gray-900">
            Welcome{user?.username ? `, ${user.username}` : ""}
          </h2>
          <p className="mt-3 text-gray-500">
            You&apos;re signed in. This is your dashboard.
          </p>
        </div>
      </main>
    </div>
  );
}
