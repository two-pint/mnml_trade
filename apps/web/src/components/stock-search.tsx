"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import { useRouter } from "next/navigation";
import type { SearchResult } from "@repo/types";
import { stocksApi } from "@/lib/api";

const RECENT_KEY = "mnml-recent-stocks";
const RECENT_MAX = 5;
const DEBOUNCE_MS = 300;

function getRecent(): SearchResult[] {
  if (typeof window === "undefined") return [];
  try {
    const raw = localStorage.getItem(RECENT_KEY);
    if (!raw) return [];
    const parsed = JSON.parse(raw) as SearchResult[];
    return Array.isArray(parsed) ? parsed.slice(0, RECENT_MAX) : [];
  } catch {
    return [];
  }
}

function addRecent(item: SearchResult) {
  const recent = getRecent();
  const without = recent.filter((r) => r.ticker !== item.ticker);
  const next = [item, ...without].slice(0, RECENT_MAX);
  try {
    localStorage.setItem(RECENT_KEY, JSON.stringify(next));
  } catch {
    // ignore
  }
}

export function StockSearch() {
  const router = useRouter();
  const [query, setQuery] = useState("");
  const [results, setResults] = useState<SearchResult[]>([]);
  const [recent, setRecent] = useState<SearchResult[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [open, setOpen] = useState(false);
  const [showRecent, setShowRecent] = useState(false);
  const debounceRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const containerRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    setRecent(getRecent());
  }, []);

  useEffect(() => {
    if (debounceRef.current) clearTimeout(debounceRef.current);
    const q = query.trim();
    if (!q) {
      setResults([]);
      setLoading(false);
      setShowRecent(true);
      return;
    }
    setShowRecent(false);
    setLoading(true);
    setError(null);
    debounceRef.current = setTimeout(() => {
      debounceRef.current = null;
      stocksApi
        .searchStocks(q)
        .then((data) => {
          setResults(data ?? []);
          setError(null);
        })
        .catch(() => {
          setResults([]);
          setError("Search failed");
        })
        .finally(() => setLoading(false));
    }, DEBOUNCE_MS);
    return () => {
      if (debounceRef.current) clearTimeout(debounceRef.current);
    };
  }, [query]);

  const handleSelect = useCallback(
    (item: SearchResult) => {
      addRecent(item);
      setRecent(getRecent());
      setQuery("");
      setOpen(false);
      setResults([]);
      router.push(`/stocks/${encodeURIComponent(item.ticker)}`);
    },
    [router],
  );

  useEffect(() => {
    function handleClickOutside(e: MouseEvent) {
      if (containerRef.current && !containerRef.current.contains(e.target as Node)) {
        setOpen(false);
      }
    }
    document.addEventListener("mousedown", handleClickOutside);
    return () => document.removeEventListener("mousedown", handleClickOutside);
  }, []);

  const displayList = open && (query.trim() ? results : showRecent ? recent : []);
  const showEmpty = open && query.trim() && !loading && results.length === 0 && !error;
  const showError = open && query.trim() && error;

  return (
    <div ref={containerRef} className="relative w-full max-w-sm">
      <input
        type="search"
        value={query}
        onChange={(e) => setQuery(e.target.value)}
        onFocus={() => setOpen(true)}
        placeholder="Search stocks..."
        className="w-full rounded-lg border border-gray-300 bg-white px-3 py-2 pl-9 text-sm placeholder:text-gray-400 focus:outline-none focus:ring-2 focus:ring-primary-500"
        aria-expanded={open}
        aria-autocomplete="list"
        aria-controls="stock-search-list"
      />
      <span
        className="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 text-gray-400"
        aria-hidden
      >
        <svg className="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
        </svg>
      </span>
      {loading && (
        <span className="absolute right-3 top-1/2 -translate-y-1/2" aria-hidden>
          <span className="h-4 w-4 animate-spin rounded-full border-2 border-primary-200 border-t-primary-600" />
        </span>
      )}
      {open && (displayList.length > 0 || showEmpty || showError) && (
        <ul
          id="stock-search-list"
          role="listbox"
          className="absolute top-full z-50 mt-1 max-h-72 w-full overflow-auto rounded-lg border border-gray-200 bg-white py-1 shadow-lg"
        >
          {showError && (
            <li className="px-3 py-2 text-sm text-bearish">Search failed. Try again.</li>
          )}
          {showEmpty && !showError && (
            <li className="px-3 py-2 text-sm text-gray-500">No results</li>
          )}
          {!showError && displayList.length > 0 && (
            <>
              {showRecent && recent.length > 0 && !query.trim() && (
                <li className="px-3 py-1.5 text-xs font-medium text-gray-500">Recent</li>
              )}
              {displayList.map((item) => (
                <li
                  key={`${item.ticker}-${item.name}`}
                  role="option"
                  tabIndex={0}
                  className="cursor-pointer px-3 py-2 text-sm transition-colors hover:bg-gray-100 focus:bg-gray-100 focus:outline-none"
                  onMouseDown={() => handleSelect(item)}
                >
                  <span className="font-medium text-gray-900">{item.ticker}</span>
                  <span className="ml-2 text-gray-500">{item.name}</span>
                </li>
              ))}
            </>
          )}
        </ul>
      )}
    </div>
  );
}
