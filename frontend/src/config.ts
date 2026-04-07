/// Configuration for the chess dApp.
/// Set VITE_NETWORK and VITE_PACKAGE_ID in .env or at build time.

function requireEnv(name: string): string {
  const value = import.meta.env[name] as string | undefined;
  if (!value) {
    throw new Error(`Missing required environment variable: ${name}`);
  }
  return value;
}

export const NETWORK = requireEnv("VITE_NETWORK");
export const PACKAGE_ID = requireEnv("VITE_PACKAGE_ID");
export const LOBBY_ID = requireEnv("VITE_LOBBY_ID");

/// Module name in the package.
export const MODULE = "chess";
