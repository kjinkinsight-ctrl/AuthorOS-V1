import { cpSync, existsSync, mkdirSync, rmSync } from "node:fs";
import { resolve } from "node:path";

const root = resolve(process.cwd());
const output = resolve(root, "desktop-dist");

rmSync(output, { recursive: true, force: true });
mkdirSync(output, { recursive: true });

for (const entry of ["index.html", "css", "js", "assets"]) {
    const source = resolve(root, entry);

    if (!existsSync(source)) {
        throw new Error(`Missing desktop asset: ${entry}`);
    }

    cpSync(source, resolve(output, entry), { recursive: true });
}

console.log("Prepared desktop assets in desktop-dist/");
