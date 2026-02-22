import { build as esbuild } from "esbuild";
import { rm } from "fs/promises";
import { execSync } from "child_process";
import { resolve } from "path";
import { fileURLToPath } from "url";

const projectRoot = fileURLToPath(new URL("..", import.meta.url));
const tscBin = resolve(projectRoot, "node_modules", ".bin", "tsc");

async function buildPackage() {
  await rm("dist", { recursive: true, force: true });

  console.log("building package declarations...");
  execSync(`${tscBin} -p tsconfig.build.json`, { stdio: "inherit" });

  console.log("building package entry (ESM)...");
  await esbuild({
    entryPoints: ["index.ts"],
    platform: "node",
    bundle: true,
    format: "esm",
    outfile: "dist/index.js",
    external: ["crypto"],
    logLevel: "info",
  });
}

buildPackage().catch((err) => {
  console.error(err);
  process.exit(1);
});
