"use client";

import { useAuth } from "@/lib/auth-context";

export default function DashboardPage() {
  const { user } = useAuth();

  return (
    <div className="flex flex-1 items-center justify-center px-4 py-8 sm:px-6">
      <div className="text-center">
        <h2 className="text-2xl font-bold tracking-tight text-gray-900 sm:text-3xl">
          Welcome{user?.username ? `, ${user.username}` : ""}
        </h2>
        <p className="mt-3 text-gray-500">
          Use the search bar to find a stock and view its overview and technical analysis.
        </p>
      </div>
    </div>
  );
}
