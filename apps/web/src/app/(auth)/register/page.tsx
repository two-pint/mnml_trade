"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import Link from "next/link";
import { useAuth } from "@/lib/auth-context";
import { ApiClientError } from "@repo/api-client";

export default function RegisterPage() {
  const { register } = useAuth();
  const router = useRouter();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [username, setUsername] = useState("");
  const [error, setError] = useState("");
  const [fieldErrors, setFieldErrors] = useState<Record<string, string[]>>({});
  const [submitting, setSubmitting] = useState(false);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError("");
    setFieldErrors({});
    setSubmitting(true);

    try {
      await register(email, password, username || undefined);
      router.replace("/dashboard");
    } catch (err) {
      if (err instanceof ApiClientError) {
        const apiErr = err.error as { message: string; errors?: Record<string, string[]> };
        setError(apiErr.message);
        if (apiErr.errors) setFieldErrors(apiErr.errors);
      } else {
        setError("Something went wrong. Please try again.");
      }
    } finally {
      setSubmitting(false);
    }
  }

  function fieldError(field: string): string | undefined {
    const errs = fieldErrors[field];
    return errs?.[0];
  }

  return (
    <>
      <div className="mb-8 text-center">
        <h1 className="text-2xl font-bold tracking-tight text-gray-900">
          Create your account
        </h1>
        <p className="mt-2 text-sm text-gray-500">
          Already have an account?{" "}
          <Link
            href="/login"
            className="font-medium text-primary-600 hover:text-primary-700"
          >
            Sign in
          </Link>
        </p>
      </div>

      <div className="rounded-xl border border-gray-200 bg-white p-8 shadow-sm">
        <form onSubmit={handleSubmit} className="space-y-5">
          {error && (
            <div className="rounded-lg bg-bearish-light/30 px-4 py-3 text-sm text-bearish-dark">
              {error}
            </div>
          )}

          <div className="flex flex-col gap-1.5">
            <label
              htmlFor="email"
              className="text-sm font-medium text-gray-700"
            >
              Email
            </label>
            <input
              id="email"
              type="email"
              required
              autoComplete="email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              className={`rounded-lg border px-3 py-2 text-sm transition-colors placeholder:text-gray-400 focus:outline-none focus:ring-2 focus:ring-primary-500 ${
                fieldError("email")
                  ? "border-bearish text-bearish-dark"
                  : "border-gray-300 text-gray-900"
              }`}
              placeholder="you@example.com"
            />
            {fieldError("email") && (
              <p className="text-sm text-bearish">{fieldError("email")}</p>
            )}
          </div>

          <div className="flex flex-col gap-1.5">
            <label
              htmlFor="username"
              className="text-sm font-medium text-gray-700"
            >
              Username{" "}
              <span className="font-normal text-gray-400">(optional)</span>
            </label>
            <input
              id="username"
              type="text"
              autoComplete="username"
              value={username}
              onChange={(e) => setUsername(e.target.value)}
              className={`rounded-lg border px-3 py-2 text-sm transition-colors placeholder:text-gray-400 focus:outline-none focus:ring-2 focus:ring-primary-500 ${
                fieldError("username")
                  ? "border-bearish text-bearish-dark"
                  : "border-gray-300 text-gray-900"
              }`}
              placeholder="Choose a username"
            />
            {fieldError("username") && (
              <p className="text-sm text-bearish">{fieldError("username")}</p>
            )}
          </div>

          <div className="flex flex-col gap-1.5">
            <label
              htmlFor="password"
              className="text-sm font-medium text-gray-700"
            >
              Password
            </label>
            <input
              id="password"
              type="password"
              required
              autoComplete="new-password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              className={`rounded-lg border px-3 py-2 text-sm transition-colors placeholder:text-gray-400 focus:outline-none focus:ring-2 focus:ring-primary-500 ${
                fieldError("password")
                  ? "border-bearish text-bearish-dark"
                  : "border-gray-300 text-gray-900"
              }`}
              placeholder="At least 8 characters"
            />
            {fieldError("password") && (
              <p className="text-sm text-bearish">{fieldError("password")}</p>
            )}
          </div>

          <button
            type="submit"
            disabled={submitting}
            className="w-full rounded-lg bg-primary-600 px-4 py-2.5 text-sm font-medium text-white transition-colors hover:bg-primary-700 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary-500 disabled:opacity-50"
          >
            {submitting ? "Creating account..." : "Create account"}
          </button>
        </form>
      </div>
    </>
  );
}
