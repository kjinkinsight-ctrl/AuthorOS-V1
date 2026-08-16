export type ReleaseArtifact = {
  platform: "windows" | "macos" | "linux";
  fileName: string;
  fileSizeBytes: number;
  checksumSha256: string;
  contentType: string;
};

export type ReleaseRecord = {
  id: string;
  productCode: string;
  version: string;
  channel: "stable" | "beta" | "legacy";
  publishedAt: string;
  notes: string;
  artifacts: ReleaseArtifact[];
};

const defaultApiBaseUrl = "http://localhost:4000";

function resolveApiBaseUrl() {
  return process.env.API_BASE_URL ?? process.env.NEXT_PUBLIC_API_BASE_URL ?? defaultApiBaseUrl;
}

export async function fetchDownloadConfig() {
  const response = await fetch(`${resolveApiBaseUrl()}/v1/downloads/config`, {
    cache: "no-store",
    headers: { Accept: "application/json" }
  });

  if (!response.ok) {
    return {
      status: response.status,
      data: null as {
        downloadBaseUrl: string;
        signingConfigured: boolean;
        urlTtlSeconds: number;
      } | null
    };
  }

  return {
    status: response.status,
    data: (await response.json()) as {
      downloadBaseUrl: string;
      signingConfigured: boolean;
      urlTtlSeconds: number;
    }
  };
}

export async function fetchEntitledReleases(productCode: string) {
  const response = await fetch(
    `${resolveApiBaseUrl()}/v1/downloads/releases?productCode=${encodeURIComponent(productCode)}`,
    {
      cache: "no-store",
      headers: { Accept: "application/json" }
    }
  );

  let payload: any = null;
  try {
    payload = await response.json();
  } catch {
    payload = null;
  }

  return {
    status: response.status,
    data: payload as { items?: ReleaseRecord[]; summary?: string; error?: string } | null
  };
}
