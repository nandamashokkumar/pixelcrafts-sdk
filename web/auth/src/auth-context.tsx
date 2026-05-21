"use client";

import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useState,
  type ReactNode,
} from "react";

import {
  clearAuth,
  exchangeToken,
  getStoredToken,
  getStoredUser,
  isAuthStorageKey,
  storeAuth,
} from "./auth-service";
import type { AuthResult, PlatformUser } from "./types";

export interface AuthContextValue {
  user: PlatformUser | null;
  token: string | null;
  /** True until the initial `useEffect` has finished restoring from localStorage. */
  isLoading: boolean;

  /**
   * Persist a fresh exchange result. Call this from your sign-in
   * screen after `exchangeFirebaseToken` returns.
   */
  login: (result: AuthResult) => void;

  /**
   * Exchange an upstream identity-provider access token for a platform
   * JWT *and* store it. Provider-agnostic — pass a Firebase ID token,
   * a Supabase access token, or whatever the registered `apps.authProvider`
   * for this app verifies. Convenience wrapper around `exchangeToken + login`.
   */
  exchangeUpstreamToken: (idToken: string) => Promise<AuthResult>;

  /**
   * @deprecated Renamed to [exchangeUpstreamToken]. Kept as an alias so
   * existing Firebase consumers don't need to rewire their sign-in screens
   * before adopting a Supabase-backed brand.
   */
  exchangeFirebaseToken: (idToken: string) => Promise<AuthResult>;

  /**
   * Clear local state. By default this also calls the
   * `upstreamSignOut?.()` prop so consumers can wire their own SDK's
   * sign-out (Firebase, Supabase, etc.) without the SDK statically
   * importing any of them.
   */
  logout: () => Promise<void>;
}

const AuthContext = createContext<AuthContextValue | null>(null);

export interface AuthProviderProps {
  children: ReactNode;
  /**
   * Optional callback fired at the end of `logout()`. Use this to
   * sign out from the upstream auth provider:
   *   - Firebase:  `upstreamSignOut={() => signOut(auth)}`
   *   - Supabase:  `upstreamSignOut={() => supabase.auth.signOut()}`
   * Errors are swallowed — local state must clear even if the remote
   * signOut hiccups.
   */
  upstreamSignOut?: () => Promise<void> | void;
  /**
   * @deprecated Renamed to [upstreamSignOut]. Kept as an alias so
   * existing Firebase consumers don't break on rename.
   */
  firebaseSignOut?: () => Promise<void> | void;
}

export function AuthProvider({
  children,
  upstreamSignOut,
  firebaseSignOut,
}: AuthProviderProps) {
  // Honour the deprecated alias if the new prop is absent.
  const resolvedUpstreamSignOut = upstreamSignOut ?? firebaseSignOut;
  const [user, setUser] = useState<PlatformUser | null>(null);
  const [token, setToken] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    setUser(getStoredUser());
    setToken(getStoredToken());
    setIsLoading(false);

    // Cross-tab sync — when another tab logs in/out, mirror it here.
    const handleStorageChange = (e: StorageEvent) => {
      if (!isAuthStorageKey(e.key)) return;
      setUser(getStoredUser());
      setToken(getStoredToken());
    };
    window.addEventListener("storage", handleStorageChange);
    return () => window.removeEventListener("storage", handleStorageChange);
  }, []);

  const login = useCallback((result: AuthResult) => {
    storeAuth(result);
    setUser(result.user);
    setToken(result.token);
  }, []);

  const exchangeUpstreamToken = useCallback(
    async (idToken: string): Promise<AuthResult> => {
      const result = await exchangeToken(idToken);
      storeAuth(result);
      setUser(result.user);
      setToken(result.token);
      return result;
    },
    []
  );

  const logout = useCallback(async () => {
    // Clear local state first — UI updates immediately.
    clearAuth();
    setUser(null);
    setToken(null);
    if (resolvedUpstreamSignOut) {
      try {
        await resolvedUpstreamSignOut();
      } catch {
        // Intentionally swallowed; local state has already cleared.
      }
    }
  }, [resolvedUpstreamSignOut]);

  return (
    <AuthContext.Provider
      value={{
        user,
        token,
        isLoading,
        login,
        exchangeUpstreamToken,
        // Deprecated alias — points at the same function so existing
        // Firebase consumers don't break on rename.
        exchangeFirebaseToken: exchangeUpstreamToken,
        logout,
      }}
    >
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth(): AuthContextValue {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error("useAuth must be used within an AuthProvider");
  }
  return context;
}
