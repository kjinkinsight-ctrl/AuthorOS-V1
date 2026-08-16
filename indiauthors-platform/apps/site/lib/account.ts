export type AuthConfigResponse = {
  mode: "disabled" | "external_oidc";
  provider: string;
  integrationReady: boolean;
  capabilities: {
    register: boolean;
    login: boolean;
    logout: boolean;
    passwordRecovery: boolean;
    accountDashboard: boolean;
  };
};

export type AccountSummaryResponse = {
  error?: string;
  summary?: string;
};

const defaultApiBaseUrl = "http://localhost:4000";

function resolveApiBaseUrl() {
  return process.env.API_BASE_URL ?? process.env.NEXT_PUBLIC_API_BASE_URL ?? defaultApiBaseUrl;
}

export async function fetchAuthConfig(): Promise<AuthConfigResponse | null> {
  const response = await fetch(`${resolveApiBaseUrl()}/v1/auth/config`, {
    cache: "no-store",
    headers: { Accept: "application/json" }
  });

  if (!response.ok) {
    return null;
  }

  return (await response.json()) as AuthConfigResponse;
}

export async function fetchAccountSummary(): Promise<{
  status: number;
  data: AccountSummaryResponse | null;
}> {
  const response = await fetch(`${resolveApiBaseUrl()}/v1/account/summary`, {
    cache: "no-store",
    headers: { Accept: "application/json" }
  });

  let data: AccountSummaryResponse | null = null;
  try {
    data = (await response.json()) as AccountSummaryResponse;
  } catch {
    data = null;
  }

  return {
    status: response.status,
    data
  };
}
