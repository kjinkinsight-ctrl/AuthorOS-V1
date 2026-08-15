import { access } from "node:fs/promises";

const requiredFiles = [
  "packages/contracts/openapi/indiauthors-platform.yaml",
  "packages/contracts/schemas/license.schema.json",
  "packages/contracts/schemas/order.schema.json"
];

async function exists(path) {
  try {
    await access(path);
    return true;
  } catch {
    return false;
  }
}

const missing = [];
for (const file of requiredFiles) {
  if (!(await exists(file))) {
    missing.push(file);
  }
}

if (missing.length > 0) {
  console.error("Missing required contract files:");
  for (const file of missing) {
    console.error(`- ${file}`);
  }
  process.exit(1);
}

console.log("Contract file check passed.");
