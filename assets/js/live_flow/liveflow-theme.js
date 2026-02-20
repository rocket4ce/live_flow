/**
 * LiveFlow Theme Plugin for Tailwind CSS v4
 *
 * Allows users to define custom LiveFlow themes using the @plugin directive.
 * Includes all daisyUI color palettes auto-mapped to LiveFlow variables,
 * plus hand-crafted themes with fine-tuned colors.
 *
 * Built-in themes (36 total):
 *   Hand-crafted: light, dark, ocean, forest, sunset, synthwave, nord,
 *                 autumn, cyberpunk, pastel, dracula, coffee
 *   Auto-generated from daisyUI palettes:
 *     acid, black, luxury, retro, lofi, valentine, lemonade, garden,
 *     aqua, corporate, bumblebee, silk, dim, abyss, night, caramellatte,
 *     emerald, cupcake, cmyk, business, winter, halloween, fantasy, wireframe
 *
 * Usage:
 *   @plugin "../js/live_flow/liveflow-theme" { name: "light"; default: true; }
 *   @plugin "../js/live_flow/liveflow-theme" { name: "dark"; prefersdark: true; }
 *   @plugin "../js/live_flow/liveflow-theme" { name: "dracula"; }
 *
 *   // Custom theme with overrides:
 *   @plugin "../js/live_flow/liveflow-theme" {
 *     name: "my-theme";
 *     --lf-background: #0a1929;
 *     --lf-node-bg: #0d2137;
 *   }
 */

var __defProp = Object.defineProperty;
var __getOwnPropNames = Object.getOwnPropertyNames;
var __getOwnPropDesc = Object.getOwnPropertyDescriptor;
var __hasOwnProp = Object.prototype.hasOwnProperty;
var __moduleCache = /* @__PURE__ */ new WeakMap;
var __toCommonJS = (from) => {
  var entry = __moduleCache.get(from), desc;
  if (entry)
    return entry;
  entry = __defProp({}, "__esModule", { value: true });
  if (from && typeof from === "object" || typeof from === "function")
    __getOwnPropNames(from).map((key) => !__hasOwnProp.call(entry, key) && __defProp(entry, key, {
      get: () => from[key],
      enumerable: !(desc = __getOwnPropDesc(from, key)) || desc.enumerable
    }));
  __moduleCache.set(from, entry);
  return entry;
};
var __export = (target, all) => {
  for (var name in all)
    __defProp(target, name, {
      get: all[name],
      enumerable: true,
      configurable: true,
      set: (newValue) => all[name] = () => newValue
    });
};

// Plugin infrastructure (same pattern as daisyui-theme.js)
var exports_liveflow_theme = {};
__export(exports_liveflow_theme, {
  default: () => liveflow_theme_default
});
module.exports = __toCommonJS(exports_liveflow_theme);

var plugin = {
  withOptions: (pluginFunction, configFunction = () => ({})) => {
    const optionsFunction = (options) => {
      const handler = pluginFunction(options);
      const config = configFunction(options);
      return { handler, config };
    };
    optionsFunction.__isOptionsFunction = true;
    return optionsFunction;
  }
};

// ---------------------------------------------------------------------------
// daisyUI color palettes (subset of tokens needed for auto-generating themes)
// Source: daisyui-theme.js object_default
// ---------------------------------------------------------------------------
var daisyPalettes = {
  light: {
    "color-scheme": "light", "--color-base-100": "oklch(100% 0 0)", "--color-base-200": "oklch(98% 0 0)", "--color-base-300": "oklch(95% 0 0)", "--color-base-content": "oklch(21% 0.006 285.885)",
    "--color-primary": "oklch(45% 0.24 277.023)", "--color-secondary": "oklch(65% 0.241 354.308)", "--color-neutral": "oklch(14% 0.005 285.823)", "--color-neutral-content": "oklch(92% 0.004 286.32)",
    "--color-error": "oklch(71% 0.194 13.428)", "--radius-box": "0.5rem", "--border": "1px"
  },
  dark: {
    "color-scheme": "dark", "--color-base-100": "oklch(25.33% 0.016 252.42)", "--color-base-200": "oklch(23.26% 0.014 253.1)", "--color-base-300": "oklch(21.15% 0.012 254.09)", "--color-base-content": "oklch(97.807% 0.029 256.847)",
    "--color-primary": "oklch(58% 0.233 277.117)", "--color-secondary": "oklch(65% 0.241 354.308)", "--color-neutral": "oklch(14% 0.005 285.823)", "--color-neutral-content": "oklch(92% 0.004 286.32)",
    "--color-error": "oklch(71% 0.194 13.428)", "--radius-box": "0.5rem", "--border": "1px"
  },
  cyberpunk: {
    "color-scheme": "light", "--color-base-100": "oklch(94.51% 0.179 104.32)", "--color-base-200": "oklch(91.51% 0.179 104.32)", "--color-base-300": "oklch(85.51% 0.179 104.32)", "--color-base-content": "oklch(0% 0 0)",
    "--color-primary": "oklch(74.22% 0.209 6.35)", "--color-secondary": "oklch(83.33% 0.184 204.72)", "--color-neutral": "oklch(23.04% 0.065 269.31)", "--color-neutral-content": "oklch(94.51% 0.179 104.32)",
    "--color-error": "oklch(71.76% 0.221 22.18)", "--radius-box": "0rem", "--border": "1px"
  },
  acid: {
    "color-scheme": "light", "--color-base-100": "oklch(98% 0 0)", "--color-base-200": "oklch(95% 0 0)", "--color-base-300": "oklch(91% 0 0)", "--color-base-content": "oklch(0% 0 0)",
    "--color-primary": "oklch(71.9% 0.357 330.759)", "--color-secondary": "oklch(73.37% 0.224 48.25)", "--color-neutral": "oklch(21.31% 0.128 278.68)", "--color-neutral-content": "oklch(84.262% 0.025 278.68)",
    "--color-error": "oklch(64.84% 0.293 29.349)", "--radius-box": "1rem", "--border": "1px"
  },
  black: {
    "color-scheme": "dark", "--color-base-100": "oklch(0% 0 0)", "--color-base-200": "oklch(19% 0 0)", "--color-base-300": "oklch(22% 0 0)", "--color-base-content": "oklch(87.609% 0 0)",
    "--color-primary": "oklch(35% 0 0)", "--color-secondary": "oklch(35% 0 0)", "--color-neutral": "oklch(35% 0 0)", "--color-neutral-content": "oklch(100% 0 0)",
    "--color-error": "oklch(62.795% 0.257 29.233)", "--radius-box": "0rem", "--border": "1px"
  },
  luxury: {
    "color-scheme": "dark", "--color-base-100": "oklch(14.076% 0.004 285.822)", "--color-base-200": "oklch(20.219% 0.004 308.229)", "--color-base-300": "oklch(23.219% 0.004 308.229)", "--color-base-content": "oklch(75.687% 0.123 76.89)",
    "--color-primary": "oklch(100% 0 0)", "--color-secondary": "oklch(27.581% 0.064 261.069)", "--color-neutral": "oklch(24.27% 0.057 59.825)", "--color-neutral-content": "oklch(93.203% 0.089 90.861)",
    "--color-error": "oklch(71.753% 0.176 22.568)", "--radius-box": "1rem", "--border": "1px"
  },
  dracula: {
    "color-scheme": "dark", "--color-base-100": "oklch(28.822% 0.022 277.508)", "--color-base-200": "oklch(26.805% 0.02 277.508)", "--color-base-300": "oklch(24.787% 0.019 277.508)", "--color-base-content": "oklch(97.747% 0.007 106.545)",
    "--color-primary": "oklch(75.461% 0.183 346.812)", "--color-secondary": "oklch(74.202% 0.148 301.883)", "--color-neutral": "oklch(39.445% 0.032 275.524)", "--color-neutral-content": "oklch(87.889% 0.006 275.524)",
    "--color-error": "oklch(68.22% 0.206 24.43)", "--radius-box": "1rem", "--border": "1px"
  },
  retro: {
    "color-scheme": "light", "--color-base-100": "oklch(91.637% 0.034 90.515)", "--color-base-200": "oklch(88.272% 0.049 91.774)", "--color-base-300": "oklch(84.133% 0.065 90.856)", "--color-base-content": "oklch(41% 0.112 45.904)",
    "--color-primary": "oklch(80% 0.114 19.571)", "--color-secondary": "oklch(92% 0.084 155.995)", "--color-neutral": "oklch(44% 0.011 73.639)", "--color-neutral-content": "oklch(86% 0.005 56.366)",
    "--color-error": "oklch(70% 0.191 22.216)", "--radius-box": "0.5rem", "--border": "1px"
  },
  lofi: {
    "color-scheme": "light", "--color-base-100": "oklch(100% 0 0)", "--color-base-200": "oklch(97% 0 0)", "--color-base-300": "oklch(94% 0 0)", "--color-base-content": "oklch(0% 0 0)",
    "--color-primary": "oklch(15.906% 0 0)", "--color-secondary": "oklch(21.455% 0.001 17.278)", "--color-neutral": "oklch(0% 0 0)", "--color-neutral-content": "oklch(100% 0 0)",
    "--color-error": "oklch(78.66% 0.15 28.47)", "--radius-box": "0.5rem", "--border": "1px"
  },
  valentine: {
    "color-scheme": "light", "--color-base-100": "oklch(97% 0.014 343.198)", "--color-base-200": "oklch(94% 0.028 342.258)", "--color-base-300": "oklch(89% 0.061 343.231)", "--color-base-content": "oklch(52% 0.223 3.958)",
    "--color-primary": "oklch(65% 0.241 354.308)", "--color-secondary": "oklch(62% 0.265 303.9)", "--color-neutral": "oklch(40% 0.153 2.432)", "--color-neutral-content": "oklch(89% 0.061 343.231)",
    "--color-error": "oklch(63% 0.237 25.331)", "--radius-box": "1rem", "--border": "1px"
  },
  nord: {
    "color-scheme": "light", "--color-base-100": "oklch(95.127% 0.007 260.731)", "--color-base-200": "oklch(93.299% 0.01 261.788)", "--color-base-300": "oklch(89.925% 0.016 262.749)", "--color-base-content": "oklch(32.437% 0.022 264.182)",
    "--color-primary": "oklch(59.435% 0.077 254.027)", "--color-secondary": "oklch(69.651% 0.059 248.687)", "--color-neutral": "oklch(45.229% 0.035 264.131)", "--color-neutral-content": "oklch(89.925% 0.016 262.749)",
    "--color-error": "oklch(60.61% 0.12 15.341)", "--radius-box": "0.5rem", "--border": "1px"
  },
  lemonade: {
    "color-scheme": "light", "--color-base-100": "oklch(98.71% 0.02 123.72)", "--color-base-200": "oklch(91.8% 0.018 123.72)", "--color-base-300": "oklch(84.89% 0.017 123.72)", "--color-base-content": "oklch(19.742% 0.004 123.72)",
    "--color-primary": "oklch(58.92% 0.199 134.6)", "--color-secondary": "oklch(77.75% 0.196 111.09)", "--color-neutral": "oklch(30.98% 0.075 108.6)", "--color-neutral-content": "oklch(86.196% 0.015 108.6)",
    "--color-error": "oklch(86.19% 0.047 25.85)", "--radius-box": "1rem", "--border": "1px"
  },
  garden: {
    "color-scheme": "light", "--color-base-100": "oklch(92.951% 0.002 17.197)", "--color-base-200": "oklch(86.445% 0.002 17.197)", "--color-base-300": "oklch(79.938% 0.001 17.197)", "--color-base-content": "oklch(16.961% 0.001 17.32)",
    "--color-primary": "oklch(62.45% 0.278 3.836)", "--color-secondary": "oklch(48.495% 0.11 355.095)", "--color-neutral": "oklch(24.155% 0.049 89.07)", "--color-neutral-content": "oklch(92.951% 0.002 17.197)",
    "--color-error": "oklch(71.76% 0.221 22.18)", "--radius-box": "1rem", "--border": "1px"
  },
  aqua: {
    "color-scheme": "dark", "--color-base-100": "oklch(37% 0.146 265.522)", "--color-base-200": "oklch(28% 0.091 267.935)", "--color-base-300": "oklch(22% 0.091 267.935)", "--color-base-content": "oklch(90% 0.058 230.902)",
    "--color-primary": "oklch(85.661% 0.144 198.645)", "--color-secondary": "oklch(60.682% 0.108 309.782)", "--color-neutral": "oklch(27% 0.146 265.522)", "--color-neutral-content": "oklch(80% 0.146 265.522)",
    "--color-error": "oklch(73.95% 0.19 27.33)", "--radius-box": "1rem", "--border": "1px"
  },
  corporate: {
    "color-scheme": "light", "--color-base-100": "oklch(100% 0 0)", "--color-base-200": "oklch(93% 0 0)", "--color-base-300": "oklch(86% 0 0)", "--color-base-content": "oklch(22.389% 0.031 278.072)",
    "--color-primary": "oklch(58% 0.158 241.966)", "--color-secondary": "oklch(55% 0.046 257.417)", "--color-neutral": "oklch(0% 0 0)", "--color-neutral-content": "oklch(100% 0 0)",
    "--color-error": "oklch(70% 0.191 22.216)", "--radius-box": "0.25rem", "--border": "1px"
  },
  pastel: {
    "color-scheme": "light", "--color-base-100": "oklch(100% 0 0)", "--color-base-200": "oklch(98.462% 0.001 247.838)", "--color-base-300": "oklch(92.462% 0.001 247.838)", "--color-base-content": "oklch(20% 0 0)",
    "--color-primary": "oklch(90% 0.063 306.703)", "--color-secondary": "oklch(89% 0.058 10.001)", "--color-neutral": "oklch(55% 0.046 257.417)", "--color-neutral-content": "oklch(92% 0.013 255.508)",
    "--color-error": "oklch(80% 0.114 19.571)", "--radius-box": "1rem", "--border": "2px"
  },
  bumblebee: {
    "color-scheme": "light", "--color-base-100": "oklch(100% 0 0)", "--color-base-200": "oklch(97% 0 0)", "--color-base-300": "oklch(92% 0 0)", "--color-base-content": "oklch(20% 0 0)",
    "--color-primary": "oklch(85% 0.199 91.936)", "--color-secondary": "oklch(75% 0.183 55.934)", "--color-neutral": "oklch(37% 0.01 67.558)", "--color-neutral-content": "oklch(92% 0.003 48.717)",
    "--color-error": "oklch(70% 0.191 22.216)", "--radius-box": "1rem", "--border": "1px"
  },
  coffee: {
    "color-scheme": "dark", "--color-base-100": "oklch(24% 0.023 329.708)", "--color-base-200": "oklch(21% 0.021 329.708)", "--color-base-300": "oklch(16% 0.019 329.708)", "--color-base-content": "oklch(72.354% 0.092 79.129)",
    "--color-primary": "oklch(71.996% 0.123 62.756)", "--color-secondary": "oklch(34.465% 0.029 199.194)", "--color-neutral": "oklch(16.51% 0.015 326.261)", "--color-neutral-content": "oklch(83.302% 0.003 326.261)",
    "--color-error": "oklch(77.318% 0.128 31.871)", "--radius-box": "1rem", "--border": "1px"
  },
  silk: {
    "color-scheme": "light", "--color-base-100": "oklch(97% 0.0035 67.78)", "--color-base-200": "oklch(95% 0.0081 61.42)", "--color-base-300": "oklch(90% 0.0081 61.42)", "--color-base-content": "oklch(40% 0.0081 61.42)",
    "--color-primary": "oklch(23.27% 0.0249 284.3)", "--color-secondary": "oklch(23.27% 0.0249 284.3)", "--color-neutral": "oklch(20% 0 0)", "--color-neutral-content": "oklch(80% 0.0081 61.42)",
    "--color-error": "oklch(75.1% 0.1814 22.37)", "--radius-box": "1rem", "--border": "2px"
  },
  sunset: {
    "color-scheme": "dark", "--color-base-100": "oklch(22% 0.019 237.69)", "--color-base-200": "oklch(20% 0.019 237.69)", "--color-base-300": "oklch(18% 0.019 237.69)", "--color-base-content": "oklch(77.383% 0.043 245.096)",
    "--color-primary": "oklch(74.703% 0.158 39.947)", "--color-secondary": "oklch(72.537% 0.177 2.72)", "--color-neutral": "oklch(26% 0.019 237.69)", "--color-neutral-content": "oklch(70% 0.019 237.69)",
    "--color-error": "oklch(85.511% 0.078 16.886)", "--radius-box": "1rem", "--border": "1px"
  },
  synthwave: {
    "color-scheme": "dark", "--color-base-100": "oklch(15% 0.09 281.288)", "--color-base-200": "oklch(20% 0.09 281.288)", "--color-base-300": "oklch(25% 0.09 281.288)", "--color-base-content": "oklch(78% 0.115 274.713)",
    "--color-primary": "oklch(71% 0.202 349.761)", "--color-secondary": "oklch(82% 0.111 230.318)", "--color-neutral": "oklch(45% 0.24 277.023)", "--color-neutral-content": "oklch(87% 0.065 274.039)",
    "--color-error": "oklch(73.7% 0.121 32.639)", "--radius-box": "1rem", "--border": "1px"
  },
  dim: {
    "color-scheme": "dark", "--color-base-100": "oklch(30.857% 0.023 264.149)", "--color-base-200": "oklch(28.036% 0.019 264.182)", "--color-base-300": "oklch(26.346% 0.018 262.177)", "--color-base-content": "oklch(82.901% 0.031 222.959)",
    "--color-primary": "oklch(86.133% 0.141 139.549)", "--color-secondary": "oklch(73.375% 0.165 35.353)", "--color-neutral": "oklch(24.731% 0.02 264.094)", "--color-neutral-content": "oklch(82.901% 0.031 222.959)",
    "--color-error": "oklch(82.418% 0.099 33.756)", "--radius-box": "1rem", "--border": "1px"
  },
  abyss: {
    "color-scheme": "dark", "--color-base-100": "oklch(20% 0.08 209)", "--color-base-200": "oklch(15% 0.08 209)", "--color-base-300": "oklch(10% 0.08 209)", "--color-base-content": "oklch(90% 0.076 70.697)",
    "--color-primary": "oklch(92% 0.2653 125)", "--color-secondary": "oklch(83.27% 0.0764 298.3)", "--color-neutral": "oklch(30% 0.08 209)", "--color-neutral-content": "oklch(90% 0.076 70.697)",
    "--color-error": "oklch(65% 0.1985 24.22)", "--radius-box": "0.5rem", "--border": "1px"
  },
  forest: {
    "color-scheme": "dark", "--color-base-100": "oklch(20.84% 0.008 17.911)", "--color-base-200": "oklch(18.522% 0.007 17.911)", "--color-base-300": "oklch(16.203% 0.007 17.911)", "--color-base-content": "oklch(83.768% 0.001 17.911)",
    "--color-primary": "oklch(68.628% 0.185 148.958)", "--color-secondary": "oklch(69.776% 0.135 168.327)", "--color-neutral": "oklch(30.698% 0.039 171.364)", "--color-neutral-content": "oklch(86.139% 0.007 171.364)",
    "--color-error": "oklch(71.76% 0.221 22.18)", "--radius-box": "1rem", "--border": "1px"
  },
  night: {
    "color-scheme": "dark", "--color-base-100": "oklch(20.768% 0.039 265.754)", "--color-base-200": "oklch(19.314% 0.037 265.754)", "--color-base-300": "oklch(17.86% 0.034 265.754)", "--color-base-content": "oklch(84.153% 0.007 265.754)",
    "--color-primary": "oklch(75.351% 0.138 232.661)", "--color-secondary": "oklch(68.011% 0.158 276.934)", "--color-neutral": "oklch(27.949% 0.036 260.03)", "--color-neutral-content": "oklch(85.589% 0.007 260.03)",
    "--color-error": "oklch(71.785% 0.17 13.118)", "--radius-box": "1rem", "--border": "1px"
  },
  caramellatte: {
    "color-scheme": "light", "--color-base-100": "oklch(98% 0.016 73.684)", "--color-base-200": "oklch(95% 0.038 75.164)", "--color-base-300": "oklch(90% 0.076 70.697)", "--color-base-content": "oklch(40% 0.123 38.172)",
    "--color-primary": "oklch(0% 0 0)", "--color-secondary": "oklch(22.45% 0.075 37.85)", "--color-neutral": "oklch(55% 0.195 38.402)", "--color-neutral-content": "oklch(98% 0.016 73.684)",
    "--color-error": "oklch(70% 0.191 22.216)", "--radius-box": "1rem", "--border": "2px"
  },
  autumn: {
    "color-scheme": "light", "--color-base-100": "oklch(95.814% 0 0)", "--color-base-200": "oklch(89.107% 0 0)", "--color-base-300": "oklch(82.4% 0 0)", "--color-base-content": "oklch(19.162% 0 0)",
    "--color-primary": "oklch(40.723% 0.161 17.53)", "--color-secondary": "oklch(61.676% 0.169 23.865)", "--color-neutral": "oklch(54.367% 0.037 51.902)", "--color-neutral-content": "oklch(90.873% 0.007 51.902)",
    "--color-error": "oklch(53.07% 0.241 24.16)", "--radius-box": "1rem", "--border": "1px"
  },
  emerald: {
    "color-scheme": "light", "--color-base-100": "oklch(100% 0 0)", "--color-base-200": "oklch(93% 0 0)", "--color-base-300": "oklch(86% 0 0)", "--color-base-content": "oklch(35.519% 0.032 262.988)",
    "--color-primary": "oklch(76.662% 0.135 153.45)", "--color-secondary": "oklch(61.302% 0.202 261.294)", "--color-neutral": "oklch(35.519% 0.032 262.988)", "--color-neutral-content": "oklch(98.462% 0.001 247.838)",
    "--color-error": "oklch(71.76% 0.221 22.18)", "--radius-box": "1rem", "--border": "1px"
  },
  cupcake: {
    "color-scheme": "light", "--color-base-100": "oklch(97.788% 0.004 56.375)", "--color-base-200": "oklch(93.982% 0.007 61.449)", "--color-base-300": "oklch(91.586% 0.006 53.44)", "--color-base-content": "oklch(23.574% 0.066 313.189)",
    "--color-primary": "oklch(85% 0.138 181.071)", "--color-secondary": "oklch(89% 0.061 343.231)", "--color-neutral": "oklch(27% 0.006 286.033)", "--color-neutral-content": "oklch(92% 0.004 286.32)",
    "--color-error": "oklch(64% 0.246 16.439)", "--radius-box": "1rem", "--border": "2px"
  },
  cmyk: {
    "color-scheme": "light", "--color-base-100": "oklch(100% 0 0)", "--color-base-200": "oklch(95% 0 0)", "--color-base-300": "oklch(90% 0 0)", "--color-base-content": "oklch(20% 0 0)",
    "--color-primary": "oklch(71.772% 0.133 239.443)", "--color-secondary": "oklch(64.476% 0.202 359.339)", "--color-neutral": "oklch(21.778% 0 0)", "--color-neutral-content": "oklch(84.355% 0 0)",
    "--color-error": "oklch(62.013% 0.208 28.717)", "--radius-box": "1rem", "--border": "1px"
  },
  business: {
    "color-scheme": "dark", "--color-base-100": "oklch(24.353% 0 0)", "--color-base-200": "oklch(22.648% 0 0)", "--color-base-300": "oklch(20.944% 0 0)", "--color-base-content": "oklch(84.87% 0 0)",
    "--color-primary": "oklch(41.703% 0.099 251.473)", "--color-secondary": "oklch(64.092% 0.027 229.389)", "--color-neutral": "oklch(27.441% 0.013 253.041)", "--color-neutral-content": "oklch(85.488% 0.002 253.041)",
    "--color-error": "oklch(51.61% 0.146 29.674)", "--radius-box": "0.25rem", "--border": "1px"
  },
  winter: {
    "color-scheme": "light", "--color-base-100": "oklch(100% 0 0)", "--color-base-200": "oklch(97.466% 0.011 259.822)", "--color-base-300": "oklch(93.268% 0.016 262.751)", "--color-base-content": "oklch(41.886% 0.053 255.824)",
    "--color-primary": "oklch(56.86% 0.255 257.57)", "--color-secondary": "oklch(42.551% 0.161 282.339)", "--color-neutral": "oklch(19.616% 0.063 257.651)", "--color-neutral-content": "oklch(83.923% 0.012 257.651)",
    "--color-error": "oklch(73.092% 0.11 20.076)", "--radius-box": "1rem", "--border": "1px"
  },
  halloween: {
    "color-scheme": "dark", "--color-base-100": "oklch(21% 0.006 56.043)", "--color-base-200": "oklch(14% 0.004 49.25)", "--color-base-300": "oklch(0% 0 0)", "--color-base-content": "oklch(84.955% 0 0)",
    "--color-primary": "oklch(77.48% 0.204 60.62)", "--color-secondary": "oklch(45.98% 0.248 305.03)", "--color-neutral": "oklch(24.371% 0.046 65.681)", "--color-neutral-content": "oklch(84.874% 0.009 65.681)",
    "--color-error": "oklch(65.72% 0.199 27.33)", "--radius-box": "1rem", "--border": "1px"
  },
  fantasy: {
    "color-scheme": "light", "--color-base-100": "oklch(100% 0 0)", "--color-base-200": "oklch(93% 0 0)", "--color-base-300": "oklch(86% 0 0)", "--color-base-content": "oklch(27.807% 0.029 256.847)",
    "--color-primary": "oklch(37.45% 0.189 325.02)", "--color-secondary": "oklch(53.92% 0.162 241.36)", "--color-neutral": "oklch(27.807% 0.029 256.847)", "--color-neutral-content": "oklch(85.561% 0.005 256.847)",
    "--color-error": "oklch(71.76% 0.221 22.18)", "--radius-box": "1rem", "--border": "1px"
  },
  wireframe: {
    "color-scheme": "light", "--color-base-100": "oklch(100% 0 0)", "--color-base-200": "oklch(97% 0 0)", "--color-base-300": "oklch(94% 0 0)", "--color-base-content": "oklch(20% 0 0)",
    "--color-primary": "oklch(87% 0 0)", "--color-secondary": "oklch(87% 0 0)", "--color-neutral": "oklch(87% 0 0)", "--color-neutral-content": "oklch(26% 0 0)",
    "--color-error": "oklch(44% 0.177 26.899)", "--radius-box": "0.25rem", "--border": "1px"
  }
};

// ---------------------------------------------------------------------------
// Auto-generate LiveFlow theme from a daisyUI color palette
// Maps daisyUI semantic colors to LiveFlow --lf-* CSS variables
// ---------------------------------------------------------------------------
function fromDaisyPalette(p) {
  var isDark = p["color-scheme"] === "dark";

  // Helper: add alpha channel to an oklch() value
  // "oklch(50% 0.1 200)" → "oklch(50% 0.1 200 / 0.3)"
  function alpha(oklchVal, a) {
    return oklchVal.replace(")", " / " + a + ")");
  }

  return {
    "--lf-background": p["--color-base-100"],
    "--lf-background-dots-color": p["--color-base-300"],
    "--lf-background-lines-color": p["--color-base-300"],
    "--lf-background-cross-color": p["--color-base-300"],
    "--lf-node-bg": isDark ? p["--color-base-200"] : p["--color-base-100"],
    "--lf-node-border": p["--color-base-300"],
    "--lf-node-border-radius": p["--radius-box"] || "8px",
    "--lf-node-shadow": isDark
      ? "0 1px 4px 1px rgba(0, 0, 0, 0.3)"
      : "0 1px 4px 1px rgba(0, 0, 0, 0.08)",
    "--lf-node-shadow-hover": isDark
      ? "0 2px 8px 2px rgba(0, 0, 0, 0.4)"
      : "0 2px 8px 2px rgba(0, 0, 0, 0.12)",
    "--lf-node-selected-border": p["--color-primary"],
    "--lf-node-selected-shadow": "0 0 0 2px " + alpha(p["--color-primary"], 0.3),
    "--lf-edge-stroke": p["--color-neutral"],
    "--lf-edge-stroke-width": "2",
    "--lf-edge-stroke-selected": p["--color-primary"],
    "--lf-edge-stroke-animated": p["--color-secondary"],
    "--lf-handle-size": "10px",
    "--lf-handle-bg": isDark ? p["--color-base-200"] : p["--color-base-100"],
    "--lf-handle-border": p["--color-neutral"],
    "--lf-handle-border-width": p["--border"] || "1.5px",
    "--lf-handle-hover-bg": p["--color-primary"],
    "--lf-selection-bg": alpha(p["--color-primary"], 0.08),
    "--lf-selection-border": alpha(p["--color-primary"], 0.9),
    "--lf-minimap-bg": alpha(isDark ? p["--color-base-200"] : p["--color-base-100"], 0.95),
    "--lf-minimap-border": p["--color-base-300"],
    "--lf-minimap-node-bg": p["--color-base-300"],
    "--lf-minimap-viewport-border": p["--color-primary"],
    "--lf-controls-bg": isDark ? p["--color-base-200"] : p["--color-base-100"],
    "--lf-controls-border": p["--color-base-300"],
    "--lf-controls-button-hover": isDark ? p["--color-base-300"] : p["--color-base-200"],
    "--lf-controls-color": alpha(p["--color-base-content"], 0.8),
    "--lf-text-primary": p["--color-base-content"],
    "--lf-text-secondary": alpha(p["--color-base-content"], 0.7),
    "--lf-text-muted": alpha(p["--color-base-content"], 0.5),
    "--lf-surface-secondary": isDark ? p["--color-base-100"] : p["--color-base-200"],
    "--lf-border-secondary": p["--color-base-300"],
    "--lf-delete-hover-bg": alpha(p["--color-error"], isDark ? 0.2 : 0.1),
    "--lf-delete-hover-color": p["--color-error"],
    "--lf-delete-hover-border": p["--color-error"]
  };
}

// ---------------------------------------------------------------------------
// Hand-crafted theme definitions (take priority over auto-generated)
// ---------------------------------------------------------------------------
var builtinThemes = {
  light: {
    "--lf-background": "#f8f8f8",
    "--lf-background-dots-color": "#ddd",
    "--lf-background-lines-color": "#e5e5e5",
    "--lf-background-cross-color": "#e5e5e5",
    "--lf-node-bg": "white",
    "--lf-node-border": "#e2e2e2",
    "--lf-node-border-radius": "8px",
    "--lf-node-shadow": "0 1px 4px 1px rgba(0, 0, 0, 0.08)",
    "--lf-node-shadow-hover": "0 2px 8px 2px rgba(0, 0, 0, 0.1)",
    "--lf-node-selected-border": "#3b82f6",
    "--lf-node-selected-shadow": "0 0 0 2px rgba(59, 130, 246, 0.3)",
    "--lf-edge-stroke": "#b1b1b7",
    "--lf-edge-stroke-width": "2",
    "--lf-edge-stroke-selected": "#3b82f6",
    "--lf-edge-stroke-animated": "#ff0072",
    "--lf-handle-size": "10px",
    "--lf-handle-bg": "white",
    "--lf-handle-border": "#555",
    "--lf-handle-border-width": "1.5px",
    "--lf-handle-hover-bg": "#3b82f6",
    "--lf-selection-bg": "rgba(59, 130, 246, 0.08)",
    "--lf-selection-border": "rgba(59, 130, 246, 0.9)",
    "--lf-minimap-bg": "rgba(255, 255, 255, 0.9)",
    "--lf-minimap-border": "#e2e2e2",
    "--lf-minimap-node-bg": "#e2e2e2",
    "--lf-minimap-viewport-border": "#3b82f6",
    "--lf-controls-bg": "white",
    "--lf-controls-border": "#e2e2e2",
    "--lf-controls-button-hover": "#f5f5f5",
    "--lf-controls-color": "#666",
    "--lf-text-primary": "#333",
    "--lf-text-secondary": "#666",
    "--lf-text-muted": "#888",
    "--lf-surface-secondary": "#f9fafb",
    "--lf-border-secondary": "#ddd",
    "--lf-delete-hover-bg": "#fee2e2",
    "--lf-delete-hover-color": "#dc2626",
    "--lf-delete-hover-border": "#fca5a5"
  },

  dark: {
    "--lf-background": "#1a1a1a",
    "--lf-background-dots-color": "#333",
    "--lf-background-lines-color": "#2a2a2a",
    "--lf-background-cross-color": "#2a2a2a",
    "--lf-node-bg": "#2d2d2d",
    "--lf-node-border": "#404040",
    "--lf-node-border-radius": "8px",
    "--lf-node-shadow": "0 1px 4px 1px rgba(0, 0, 0, 0.3)",
    "--lf-node-shadow-hover": "0 2px 8px 2px rgba(0, 0, 0, 0.4)",
    "--lf-node-selected-border": "#3b82f6",
    "--lf-node-selected-shadow": "0 0 0 2px rgba(59, 130, 246, 0.3)",
    "--lf-edge-stroke": "#707070",
    "--lf-edge-stroke-width": "2",
    "--lf-edge-stroke-selected": "#3b82f6",
    "--lf-edge-stroke-animated": "#ff0072",
    "--lf-handle-size": "10px",
    "--lf-handle-bg": "#2d2d2d",
    "--lf-handle-border": "#888",
    "--lf-handle-border-width": "1.5px",
    "--lf-handle-hover-bg": "#3b82f6",
    "--lf-selection-bg": "rgba(59, 130, 246, 0.08)",
    "--lf-selection-border": "rgba(59, 130, 246, 0.9)",
    "--lf-minimap-bg": "rgba(30, 30, 30, 0.95)",
    "--lf-minimap-border": "#404040",
    "--lf-minimap-node-bg": "#404040",
    "--lf-minimap-viewport-border": "#3b82f6",
    "--lf-controls-bg": "#2d2d2d",
    "--lf-controls-border": "#404040",
    "--lf-controls-button-hover": "#383838",
    "--lf-controls-color": "#ccc",
    "--lf-text-primary": "#eee",
    "--lf-text-secondary": "#999",
    "--lf-text-muted": "#888",
    "--lf-surface-secondary": "#1f2937",
    "--lf-border-secondary": "#4b5563",
    "--lf-delete-hover-bg": "#7f1d1d",
    "--lf-delete-hover-color": "#fca5a5",
    "--lf-delete-hover-border": "#dc2626"
  },

  ocean: {
    "--lf-background": "#0c1929",
    "--lf-background-dots-color": "#1a3450",
    "--lf-background-lines-color": "#152d47",
    "--lf-background-cross-color": "#152d47",
    "--lf-node-bg": "#0f2440",
    "--lf-node-border": "#1e4976",
    "--lf-node-border-radius": "10px",
    "--lf-node-shadow": "0 2px 8px rgba(0, 0, 0, 0.4)",
    "--lf-node-shadow-hover": "0 4px 16px rgba(0, 100, 200, 0.2)",
    "--lf-node-selected-border": "#38bdf8",
    "--lf-node-selected-shadow": "0 0 0 2px rgba(56, 189, 248, 0.3)",
    "--lf-edge-stroke": "#3d7ab8",
    "--lf-edge-stroke-width": "2",
    "--lf-edge-stroke-selected": "#38bdf8",
    "--lf-edge-stroke-animated": "#06b6d4",
    "--lf-handle-size": "10px",
    "--lf-handle-bg": "#0f2440",
    "--lf-handle-border": "#38bdf8",
    "--lf-handle-border-width": "1.5px",
    "--lf-handle-hover-bg": "#0ea5e9",
    "--lf-selection-bg": "rgba(56, 189, 248, 0.1)",
    "--lf-selection-border": "rgba(56, 189, 248, 0.8)",
    "--lf-minimap-bg": "rgba(12, 25, 41, 0.95)",
    "--lf-minimap-border": "#1e4976",
    "--lf-minimap-node-bg": "#1e4976",
    "--lf-minimap-viewport-border": "#38bdf8",
    "--lf-controls-bg": "#0f2440",
    "--lf-controls-border": "#1e4976",
    "--lf-controls-button-hover": "#163557",
    "--lf-controls-color": "#7cb8e4",
    "--lf-text-primary": "#c8e1f8",
    "--lf-text-secondary": "#6a9ec7",
    "--lf-text-muted": "#4a7ea7",
    "--lf-surface-secondary": "#0a1d33",
    "--lf-border-secondary": "#1e4976",
    "--lf-delete-hover-bg": "#4c1d1d",
    "--lf-delete-hover-color": "#f87171",
    "--lf-delete-hover-border": "#b91c1c"
  },

  forest: {
    "--lf-background": "#0f1f13",
    "--lf-background-dots-color": "#1a3821",
    "--lf-background-lines-color": "#163020",
    "--lf-background-cross-color": "#163020",
    "--lf-node-bg": "#142a18",
    "--lf-node-border": "#2d5a36",
    "--lf-node-border-radius": "10px",
    "--lf-node-shadow": "0 2px 8px rgba(0, 0, 0, 0.35)",
    "--lf-node-shadow-hover": "0 4px 16px rgba(34, 197, 94, 0.15)",
    "--lf-node-selected-border": "#22c55e",
    "--lf-node-selected-shadow": "0 0 0 2px rgba(34, 197, 94, 0.3)",
    "--lf-edge-stroke": "#4a8c5c",
    "--lf-edge-stroke-width": "2",
    "--lf-edge-stroke-selected": "#22c55e",
    "--lf-edge-stroke-animated": "#a3e635",
    "--lf-handle-size": "10px",
    "--lf-handle-bg": "#142a18",
    "--lf-handle-border": "#4ade80",
    "--lf-handle-border-width": "1.5px",
    "--lf-handle-hover-bg": "#22c55e",
    "--lf-selection-bg": "rgba(34, 197, 94, 0.1)",
    "--lf-selection-border": "rgba(34, 197, 94, 0.8)",
    "--lf-minimap-bg": "rgba(15, 31, 19, 0.95)",
    "--lf-minimap-border": "#2d5a36",
    "--lf-minimap-node-bg": "#2d5a36",
    "--lf-minimap-viewport-border": "#22c55e",
    "--lf-controls-bg": "#142a18",
    "--lf-controls-border": "#2d5a36",
    "--lf-controls-button-hover": "#1c3d22",
    "--lf-controls-color": "#7cc08d",
    "--lf-text-primary": "#c8e8d0",
    "--lf-text-secondary": "#6aaa7a",
    "--lf-text-muted": "#4a8a5c",
    "--lf-surface-secondary": "#0c1e10",
    "--lf-border-secondary": "#2d5a36",
    "--lf-delete-hover-bg": "#4c1d1d",
    "--lf-delete-hover-color": "#f87171",
    "--lf-delete-hover-border": "#b91c1c"
  },

  sunset: {
    "--lf-background": "#1c1210",
    "--lf-background-dots-color": "#3d2520",
    "--lf-background-lines-color": "#33201b",
    "--lf-background-cross-color": "#33201b",
    "--lf-node-bg": "#2a1a16",
    "--lf-node-border": "#6b3a2a",
    "--lf-node-border-radius": "10px",
    "--lf-node-shadow": "0 2px 8px rgba(0, 0, 0, 0.35)",
    "--lf-node-shadow-hover": "0 4px 16px rgba(249, 115, 22, 0.15)",
    "--lf-node-selected-border": "#f97316",
    "--lf-node-selected-shadow": "0 0 0 2px rgba(249, 115, 22, 0.3)",
    "--lf-edge-stroke": "#a85d3a",
    "--lf-edge-stroke-width": "2",
    "--lf-edge-stroke-selected": "#f97316",
    "--lf-edge-stroke-animated": "#fbbf24",
    "--lf-handle-size": "10px",
    "--lf-handle-bg": "#2a1a16",
    "--lf-handle-border": "#fb923c",
    "--lf-handle-border-width": "1.5px",
    "--lf-handle-hover-bg": "#f97316",
    "--lf-selection-bg": "rgba(249, 115, 22, 0.1)",
    "--lf-selection-border": "rgba(249, 115, 22, 0.8)",
    "--lf-minimap-bg": "rgba(28, 18, 16, 0.95)",
    "--lf-minimap-border": "#6b3a2a",
    "--lf-minimap-node-bg": "#6b3a2a",
    "--lf-minimap-viewport-border": "#f97316",
    "--lf-controls-bg": "#2a1a16",
    "--lf-controls-border": "#6b3a2a",
    "--lf-controls-button-hover": "#3d2520",
    "--lf-controls-color": "#e0976a",
    "--lf-text-primary": "#f5d5bf",
    "--lf-text-secondary": "#c08a60",
    "--lf-text-muted": "#9a6a44",
    "--lf-surface-secondary": "#201410",
    "--lf-border-secondary": "#6b3a2a",
    "--lf-delete-hover-bg": "#4c1d1d",
    "--lf-delete-hover-color": "#f87171",
    "--lf-delete-hover-border": "#b91c1c"
  },

  synthwave: {
    "--lf-background": "#1a0a2e",
    "--lf-background-dots-color": "#2d1650",
    "--lf-background-lines-color": "#261245",
    "--lf-background-cross-color": "#261245",
    "--lf-node-bg": "#221040",
    "--lf-node-border": "#6b21a8",
    "--lf-node-border-radius": "8px",
    "--lf-node-shadow": "0 2px 12px rgba(168, 85, 247, 0.15)",
    "--lf-node-shadow-hover": "0 4px 20px rgba(168, 85, 247, 0.25)",
    "--lf-node-selected-border": "#e879f9",
    "--lf-node-selected-shadow": "0 0 0 2px rgba(232, 121, 249, 0.4)",
    "--lf-edge-stroke": "#9333ea",
    "--lf-edge-stroke-width": "2",
    "--lf-edge-stroke-selected": "#e879f9",
    "--lf-edge-stroke-animated": "#f0abfc",
    "--lf-handle-size": "10px",
    "--lf-handle-bg": "#221040",
    "--lf-handle-border": "#c084fc",
    "--lf-handle-border-width": "1.5px",
    "--lf-handle-hover-bg": "#a855f7",
    "--lf-selection-bg": "rgba(168, 85, 247, 0.1)",
    "--lf-selection-border": "rgba(232, 121, 249, 0.8)",
    "--lf-minimap-bg": "rgba(26, 10, 46, 0.95)",
    "--lf-minimap-border": "#6b21a8",
    "--lf-minimap-node-bg": "#6b21a8",
    "--lf-minimap-viewport-border": "#e879f9",
    "--lf-controls-bg": "#221040",
    "--lf-controls-border": "#6b21a8",
    "--lf-controls-button-hover": "#2d1650",
    "--lf-controls-color": "#c084fc",
    "--lf-text-primary": "#e8d5f5",
    "--lf-text-secondary": "#a78bca",
    "--lf-text-muted": "#7c5fab",
    "--lf-surface-secondary": "#180930",
    "--lf-border-secondary": "#6b21a8",
    "--lf-delete-hover-bg": "#4c1d3d",
    "--lf-delete-hover-color": "#f472b6",
    "--lf-delete-hover-border": "#be185d"
  },

  nord: {
    "--lf-background": "#2e3440",
    "--lf-background-dots-color": "#3b4252",
    "--lf-background-lines-color": "#373e4d",
    "--lf-background-cross-color": "#373e4d",
    "--lf-node-bg": "#3b4252",
    "--lf-node-border": "#4c566a",
    "--lf-node-border-radius": "6px",
    "--lf-node-shadow": "0 1px 4px rgba(0, 0, 0, 0.2)",
    "--lf-node-shadow-hover": "0 2px 8px rgba(0, 0, 0, 0.3)",
    "--lf-node-selected-border": "#88c0d0",
    "--lf-node-selected-shadow": "0 0 0 2px rgba(136, 192, 208, 0.3)",
    "--lf-edge-stroke": "#616e88",
    "--lf-edge-stroke-width": "2",
    "--lf-edge-stroke-selected": "#88c0d0",
    "--lf-edge-stroke-animated": "#8fbcbb",
    "--lf-handle-size": "10px",
    "--lf-handle-bg": "#3b4252",
    "--lf-handle-border": "#88c0d0",
    "--lf-handle-border-width": "1.5px",
    "--lf-handle-hover-bg": "#81a1c1",
    "--lf-selection-bg": "rgba(136, 192, 208, 0.1)",
    "--lf-selection-border": "rgba(136, 192, 208, 0.8)",
    "--lf-minimap-bg": "rgba(46, 52, 64, 0.95)",
    "--lf-minimap-border": "#4c566a",
    "--lf-minimap-node-bg": "#4c566a",
    "--lf-minimap-viewport-border": "#88c0d0",
    "--lf-controls-bg": "#3b4252",
    "--lf-controls-border": "#4c566a",
    "--lf-controls-button-hover": "#434c5e",
    "--lf-controls-color": "#d8dee9",
    "--lf-text-primary": "#eceff4",
    "--lf-text-secondary": "#a3b1c2",
    "--lf-text-muted": "#7b88a0",
    "--lf-surface-secondary": "#2e3440",
    "--lf-border-secondary": "#4c566a",
    "--lf-delete-hover-bg": "#3b1f23",
    "--lf-delete-hover-color": "#bf616a",
    "--lf-delete-hover-border": "#a5333e"
  },

  autumn: {
    "--lf-background": "#faf5f0",
    "--lf-background-dots-color": "#e0d5c8",
    "--lf-background-lines-color": "#e6ddd2",
    "--lf-background-cross-color": "#e6ddd2",
    "--lf-node-bg": "#fff8f0",
    "--lf-node-border": "#d4a574",
    "--lf-node-border-radius": "10px",
    "--lf-node-shadow": "0 2px 6px rgba(139, 90, 43, 0.1)",
    "--lf-node-shadow-hover": "0 4px 12px rgba(139, 90, 43, 0.18)",
    "--lf-node-selected-border": "#c2410c",
    "--lf-node-selected-shadow": "0 0 0 2px rgba(194, 65, 12, 0.25)",
    "--lf-edge-stroke": "#b8956a",
    "--lf-edge-stroke-width": "2",
    "--lf-edge-stroke-selected": "#c2410c",
    "--lf-edge-stroke-animated": "#ea580c",
    "--lf-handle-size": "10px",
    "--lf-handle-bg": "#fff8f0",
    "--lf-handle-border": "#b8956a",
    "--lf-handle-border-width": "1.5px",
    "--lf-handle-hover-bg": "#c2410c",
    "--lf-selection-bg": "rgba(194, 65, 12, 0.08)",
    "--lf-selection-border": "rgba(194, 65, 12, 0.7)",
    "--lf-minimap-bg": "rgba(250, 245, 240, 0.95)",
    "--lf-minimap-border": "#d4a574",
    "--lf-minimap-node-bg": "#d4a574",
    "--lf-minimap-viewport-border": "#c2410c",
    "--lf-controls-bg": "#fff8f0",
    "--lf-controls-border": "#d4a574",
    "--lf-controls-button-hover": "#f5ebe0",
    "--lf-controls-color": "#8b5a2b",
    "--lf-text-primary": "#5c3a1e",
    "--lf-text-secondary": "#8b6a4a",
    "--lf-text-muted": "#a68a6a",
    "--lf-surface-secondary": "#f5ebe0",
    "--lf-border-secondary": "#d4a574",
    "--lf-delete-hover-bg": "#fee2e2",
    "--lf-delete-hover-color": "#dc2626",
    "--lf-delete-hover-border": "#fca5a5"
  },

  cyberpunk: {
    "--lf-background": "#0a0a0a",
    "--lf-background-dots-color": "#1a1a2e",
    "--lf-background-lines-color": "#141428",
    "--lf-background-cross-color": "#141428",
    "--lf-node-bg": "#111118",
    "--lf-node-border": "#00ff88",
    "--lf-node-border-radius": "2px",
    "--lf-node-shadow": "0 0 10px rgba(0, 255, 136, 0.15), 0 2px 8px rgba(0, 0, 0, 0.4)",
    "--lf-node-shadow-hover": "0 0 20px rgba(0, 255, 136, 0.25), 0 4px 16px rgba(0, 0, 0, 0.5)",
    "--lf-node-selected-border": "#ff00ff",
    "--lf-node-selected-shadow": "0 0 15px rgba(255, 0, 255, 0.4)",
    "--lf-edge-stroke": "#00ff88",
    "--lf-edge-stroke-width": "2",
    "--lf-edge-stroke-selected": "#ff00ff",
    "--lf-edge-stroke-animated": "#00ffff",
    "--lf-handle-size": "10px",
    "--lf-handle-bg": "#111118",
    "--lf-handle-border": "#00ff88",
    "--lf-handle-border-width": "2px",
    "--lf-handle-hover-bg": "#ff00ff",
    "--lf-selection-bg": "rgba(255, 0, 255, 0.08)",
    "--lf-selection-border": "rgba(0, 255, 136, 0.9)",
    "--lf-minimap-bg": "rgba(10, 10, 10, 0.95)",
    "--lf-minimap-border": "#00ff88",
    "--lf-minimap-node-bg": "#00ff88",
    "--lf-minimap-viewport-border": "#ff00ff",
    "--lf-controls-bg": "#111118",
    "--lf-controls-border": "#00ff88",
    "--lf-controls-button-hover": "#1a1a2e",
    "--lf-controls-color": "#00ff88",
    "--lf-text-primary": "#e0ffe8",
    "--lf-text-secondary": "#00cc6a",
    "--lf-text-muted": "#008844",
    "--lf-surface-secondary": "#0a0a14",
    "--lf-border-secondary": "#1a3a2a",
    "--lf-delete-hover-bg": "#330000",
    "--lf-delete-hover-color": "#ff4444",
    "--lf-delete-hover-border": "#cc0000"
  },

  pastel: {
    "--lf-background": "#fef7ff",
    "--lf-background-dots-color": "#f0d8f5",
    "--lf-background-lines-color": "#f2ddf7",
    "--lf-background-cross-color": "#f2ddf7",
    "--lf-node-bg": "#ffffff",
    "--lf-node-border": "#e8c5f0",
    "--lf-node-border-radius": "14px",
    "--lf-node-shadow": "0 2px 8px rgba(180, 130, 200, 0.12)",
    "--lf-node-shadow-hover": "0 4px 16px rgba(180, 130, 200, 0.2)",
    "--lf-node-selected-border": "#c084fc",
    "--lf-node-selected-shadow": "0 0 0 3px rgba(192, 132, 252, 0.2)",
    "--lf-edge-stroke": "#d4a5e0",
    "--lf-edge-stroke-width": "2",
    "--lf-edge-stroke-selected": "#c084fc",
    "--lf-edge-stroke-animated": "#f9a8d4",
    "--lf-handle-size": "10px",
    "--lf-handle-bg": "#ffffff",
    "--lf-handle-border": "#d4a5e0",
    "--lf-handle-border-width": "2px",
    "--lf-handle-hover-bg": "#c084fc",
    "--lf-selection-bg": "rgba(192, 132, 252, 0.08)",
    "--lf-selection-border": "rgba(192, 132, 252, 0.6)",
    "--lf-minimap-bg": "rgba(254, 247, 255, 0.95)",
    "--lf-minimap-border": "#e8c5f0",
    "--lf-minimap-node-bg": "#e8c5f0",
    "--lf-minimap-viewport-border": "#c084fc",
    "--lf-controls-bg": "#ffffff",
    "--lf-controls-border": "#e8c5f0",
    "--lf-controls-button-hover": "#faf0fc",
    "--lf-controls-color": "#9b6bb0",
    "--lf-text-primary": "#5b3a6e",
    "--lf-text-secondary": "#8b6a9e",
    "--lf-text-muted": "#b09abf",
    "--lf-surface-secondary": "#faf0fc",
    "--lf-border-secondary": "#e8c5f0",
    "--lf-delete-hover-bg": "#fce7f3",
    "--lf-delete-hover-color": "#db2777",
    "--lf-delete-hover-border": "#f9a8d4"
  },

  dracula: {
    "--lf-background": "#282a36",
    "--lf-background-dots-color": "#3a3c4e",
    "--lf-background-lines-color": "#343646",
    "--lf-background-cross-color": "#343646",
    "--lf-node-bg": "#44475a",
    "--lf-node-border": "#6272a4",
    "--lf-node-border-radius": "8px",
    "--lf-node-shadow": "0 2px 8px rgba(0, 0, 0, 0.3)",
    "--lf-node-shadow-hover": "0 4px 16px rgba(0, 0, 0, 0.4)",
    "--lf-node-selected-border": "#bd93f9",
    "--lf-node-selected-shadow": "0 0 0 2px rgba(189, 147, 249, 0.3)",
    "--lf-edge-stroke": "#6272a4",
    "--lf-edge-stroke-width": "2",
    "--lf-edge-stroke-selected": "#bd93f9",
    "--lf-edge-stroke-animated": "#ff79c6",
    "--lf-handle-size": "10px",
    "--lf-handle-bg": "#44475a",
    "--lf-handle-border": "#bd93f9",
    "--lf-handle-border-width": "1.5px",
    "--lf-handle-hover-bg": "#ff79c6",
    "--lf-selection-bg": "rgba(189, 147, 249, 0.1)",
    "--lf-selection-border": "rgba(189, 147, 249, 0.8)",
    "--lf-minimap-bg": "rgba(40, 42, 54, 0.95)",
    "--lf-minimap-border": "#6272a4",
    "--lf-minimap-node-bg": "#6272a4",
    "--lf-minimap-viewport-border": "#bd93f9",
    "--lf-controls-bg": "#44475a",
    "--lf-controls-border": "#6272a4",
    "--lf-controls-button-hover": "#515470",
    "--lf-controls-color": "#f8f8f2",
    "--lf-text-primary": "#f8f8f2",
    "--lf-text-secondary": "#bfbfb0",
    "--lf-text-muted": "#8a8a7a",
    "--lf-surface-secondary": "#2e3042",
    "--lf-border-secondary": "#6272a4",
    "--lf-delete-hover-bg": "#4d1f30",
    "--lf-delete-hover-color": "#ff5555",
    "--lf-delete-hover-border": "#cc3333"
  },

  coffee: {
    "--lf-background": "#1c1410",
    "--lf-background-dots-color": "#332820",
    "--lf-background-lines-color": "#2a201a",
    "--lf-background-cross-color": "#2a201a",
    "--lf-node-bg": "#261c15",
    "--lf-node-border": "#5c4333",
    "--lf-node-border-radius": "10px",
    "--lf-node-shadow": "0 2px 8px rgba(0, 0, 0, 0.3)",
    "--lf-node-shadow-hover": "0 4px 16px rgba(180, 130, 80, 0.15)",
    "--lf-node-selected-border": "#d4a574",
    "--lf-node-selected-shadow": "0 0 0 2px rgba(212, 165, 116, 0.3)",
    "--lf-edge-stroke": "#7a5a3a",
    "--lf-edge-stroke-width": "2",
    "--lf-edge-stroke-selected": "#d4a574",
    "--lf-edge-stroke-animated": "#eab676",
    "--lf-handle-size": "10px",
    "--lf-handle-bg": "#261c15",
    "--lf-handle-border": "#d4a574",
    "--lf-handle-border-width": "1.5px",
    "--lf-handle-hover-bg": "#c2915e",
    "--lf-selection-bg": "rgba(212, 165, 116, 0.1)",
    "--lf-selection-border": "rgba(212, 165, 116, 0.8)",
    "--lf-minimap-bg": "rgba(28, 20, 16, 0.95)",
    "--lf-minimap-border": "#5c4333",
    "--lf-minimap-node-bg": "#5c4333",
    "--lf-minimap-viewport-border": "#d4a574",
    "--lf-controls-bg": "#261c15",
    "--lf-controls-border": "#5c4333",
    "--lf-controls-button-hover": "#332820",
    "--lf-controls-color": "#c0a080",
    "--lf-text-primary": "#e8d5c0",
    "--lf-text-secondary": "#a08060",
    "--lf-text-muted": "#806040",
    "--lf-surface-secondary": "#1a1210",
    "--lf-border-secondary": "#5c4333",
    "--lf-delete-hover-bg": "#4c1d1d",
    "--lf-delete-hover-color": "#f87171",
    "--lf-delete-hover-border": "#b91c1c"
  }
};

// ---------------------------------------------------------------------------
// Auto-generate LiveFlow themes from daisyUI palettes for any theme
// that doesn't already have a hand-crafted definition above
// ---------------------------------------------------------------------------
Object.keys(daisyPalettes).forEach(function(name) {
  if (!builtinThemes[name]) {
    builtinThemes[name] = fromDaisyPalette(daisyPalettes[name]);
  }
});

// ---------------------------------------------------------------------------
// Plugin implementation
// ---------------------------------------------------------------------------
var liveflow_theme_default = plugin.withOptions((options = {}) => {
  return ({ addBase }) => {
    const {
      name = "custom-lf-theme",
      default: isDefault = false,
      prefersdark = false,
      ...customThemeTokens
    } = options;

    // LiveFlow themes scope to .lf-container
    let selector = `.lf-container[data-lf-theme="${name}"]`;

    if (isDefault) {
      selector = `:where(.lf-container),${selector}`;
    }

    // Merge built-in theme with custom overrides
    let themeTokens = { ...customThemeTokens };
    if (builtinThemes[name]) {
      themeTokens = {
        ...builtinThemes[name],
        ...customThemeTokens
      };
    }

    const baseStyles = {
      [selector]: { ...themeTokens }
    };

    if (prefersdark) {
      addBase({
        "@media (prefers-color-scheme: dark)": {
          ".lf-container": baseStyles[selector]
        }
      });
    }

    addBase(baseStyles);
  };
});
