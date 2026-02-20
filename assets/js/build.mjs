import { build } from "esbuild";

const watch = process.argv.includes("--watch");

const config = {
  entryPoints: ["assets/js/live_flow/index.js"],
  bundle: true,
  format: "esm",
  outfile: "priv/static/live_flow.esm.js",
  sourcemap: true,
  target: "es2020",
  logLevel: "info",
};

if (watch) {
  const ctx = await build({ ...config, ...{ plugins: [] } });
  await ctx.watch();
  console.log("Watching for changes...");
} else {
  await build(config);
}
