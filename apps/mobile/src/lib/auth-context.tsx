import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
} from "react";
import type { User } from "@repo/types";
import {
  authApi,
  apiClient,
  setToken,
  setRefreshToken,
  clearTokens,
  loadToken,
} from "./api";

interface AuthContextValue {
  user: User | null;
  loading: boolean;
  login: (email: string, password: string) => Promise<void>;
  register: (email: string, password: string, username?: string) => Promise<void>;
  logout: () => Promise<void>;
}

const AuthContext = createContext<AuthContextValue | null>(null);

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [user, setUser] = useState<User | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    (async () => {
      try {
        const existing = await loadToken();
        if (!existing) return;

        const data = await apiClient.get<{
          id: string;
          email: string;
          username: string | null;
          email_verified: boolean;
        }>("/api/user/me");
        setUser(data as User);
      } catch {
        await clearTokens();
      } finally {
        setLoading(false);
      }
    })();
  }, []);

  const login = useCallback(async (email: string, password: string) => {
    const res = await authApi.login(email, password);
    await setToken(res.token);
    if (res.refresh_token) await setRefreshToken(res.refresh_token);
    setUser(res.user);
  }, []);

  const register = useCallback(
    async (email: string, password: string, username?: string) => {
      const res = await authApi.register({ email, password, username });
      await setToken(res.token);
      if (res.refresh_token) await setRefreshToken(res.refresh_token);
      setUser(res.user);
    },
    [],
  );

  const logout = useCallback(async () => {
    await clearTokens();
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
