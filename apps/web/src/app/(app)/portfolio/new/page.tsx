"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { CreatePortfolioForm } from "@/components/create-portfolio-form";

export default function NewPortfolioPage() {
  const router = useRouter();

  return (
    <div className="mx-auto max-w-7xl px-4 py-8 sm:px-6">
      <Link
        href="/portfolio"
        className="mb-6 inline-block text-sm text-zinc-500 hover:text-zinc-900 dark:text-zinc-400 dark:hover:text-zinc-100"
      >
        ← Portfolios
      </Link>
      <h1 className="text-2xl font-bold text-zinc-900 dark:text-zinc-100">New portfolio</h1>
      <p className="mt-2 max-w-lg text-sm text-zinc-500 dark:text-zinc-400">
        Choose a name and starting balance for paper trades. Cash and positions are separate from your other portfolios.
      </p>
      <div className="mt-8">
        <CreatePortfolioForm onSuccess={(id) => router.push(`/portfolio/${id}`)} />
      </div>
    </div>
  );
}
