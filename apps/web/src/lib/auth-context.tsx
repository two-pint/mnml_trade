"use client";

import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
} from "react";
import type { User } from "@repo/types";
import { authApi, setToken, setRefreshToken, clearTokens, getToken } from "./api";

interface AuthContextValue {
  user: User | null;
  loading: boolean;
  login: (email: string, password: string) => Promise<void>;
  register: (email: string, password: string, username?: string) => Promise<void>;
  logout: () => void;
}

const AuthContext = createContext<AuthContextValue | null>(null);

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [user, setUser] = useState<User | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const existingToken = getToken();
    if (!existingToken) {
      setLoading(false);
      return;
    }

    import("./api")
      .then(({ apiClient }) => apiClient.get<{ id: string; email: string; username: string | null; email_verified: boolean }>("/api/user/me"))
      .then((data) => {
        setUser(data as User);
      })
      .catch(() => {
        clearTokens();
      })
      .finally(() => {
        setLoading(false);
      });
  }, []);

  const login = useCallback(async (email: string, password: string) => {
    const res = await authApi.login(email, password);
    setToken(res.token);
    if (res.refresh_token) setRefreshToken(res.refresh_token);
    setUser(res.user);
  }, []);

  const register = useCallback(
    async (email: string, password: string, username?: string) => {
      const res = await authApi.register({ email, password, username });
      setToken(res.token);
      if (res.refresh_token) setRefreshToken(res.refresh_token);
      setUser(res.user);
    },
    [],
  );

  const logout = useCallback(() => {
    clearTokens();
    setUser(null);
  }, []);

  const value = useMemo(
    () => ({ user, loading, login, register, logout }),
    [user, loading, login, register, logout],
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth() {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error("useAuth must be used within AuthProvider");
  return ctx;
}
