import { readFile } from "node:fs/promises";
import { access } from "node:fs/promises";

const requiredFiles = [
  "README.md",
  "docs/architecture/ADR-0001-authoros-boundary.md",
  "docs/architecture/ADR-0002-platform-runtime.md",
  "docs/architecture/system-context.md",
  "docs/architecture/security-baseline.md",
  "docs/architecture/milestone-gates.md",
  "packages/contracts/openapi/indiauthors-platform.yaml",
  "packages/contracts/schemas/license.schema.json",
  "packages/contracts/schemas/order.schema.json",
  "infra/env/site.env.example",
  "infra/env/api.env.example",
  "infra/policies/secrets.md",
  "infra/policies/headers.md"
];

const blockedPatterns = [
  /sk_live_/i,
  /pk_live_/i,
  /-----BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY-----/i,
  /^SUPABASE_SERVICE_ROLE_KEY\s*=\s*\S+/i,
  /^PAYMENT_PROVIDER_SECRET_KEY\s*=\s*\S+/i,
  /^SESSION_SECRET\s*=\s*\S+/i
];

async function fileExists(path) {
  try {
    await access(path);
    return true;
  } catch {
    return false;
  }
}

const missing = [];
for (const file of requiredFiles) {
  if (!(await fileExists(file))) {
    missing.push(file);
  }
}

if (missing.length > 0) {
  console.error("W00 check failed: missing required files.");
  for (const file of missing) {
    console.error(`- ${file}`);
  }
  process.exit(1);
}

const filesToScan = [
  "infra/env/site.env.example",
  "infra/env/api.env.example",
  "README.md"
];

for (const file of filesToScan) {
  const content = await readFile(file, "utf8");
  const lines = content.split(/\r?\n/);
  for (const line of lines) {
    for (const pattern of blockedPatterns) {
      if (pattern.test(line)) {
        console.error(`W00 check failed: blocked secret-like content found in ${file}.`);
        process.exit(1);
      }
    }
  }
}

console.log("W00 guardrail checks passed.");
