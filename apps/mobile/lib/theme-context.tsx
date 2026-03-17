"use client";

import React, { createContext, useCallback, useContext, useMemo, useState } from "react";
import { useColorScheme } from "react-native";

export type Theme = "light" | "dark" | "system";

type ThemeContextValue = {
  theme: Theme;
  setTheme: (theme: Theme) => void;
  resolved: "light" | "dark";
  isDark: boolean;
};

const ThemeContext = createContext<ThemeContextValue | null>(null);

export function ThemeProvider({ children }: { children: React.ReactNode }) {
  const systemScheme = useColorScheme();
  const [theme, setThemeState] = useState<Theme>("system");

  const resolved: "light" | "dark" = useMemo(() => {
    if (theme === "system") {
      return systemScheme === "dark" ? "dark" : "light";
    }
    return theme;
  }, [theme, systemScheme]);

  const setTheme = useCallback((next: Theme) => {
    setThemeState(next);
  }, []);

  const value: ThemeContextValue = useMemo(
    () => ({
      theme,
      setTheme,
      resolved,
      isDark: resolved === "dark",
    }),
    [theme, setTheme, resolved]
  );

  return <ThemeContext.Provider value={value}>{children}</ThemeContext.Provider>;
}

export function useTheme() {
  const ctx = useContext(ThemeContext);
  if (!ctx) throw new Error("useTheme must be used within ThemeProvider");
  return ctx;
}
