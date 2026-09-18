// Screenshots tutorial/<page>.html into man/figures/<page>.png.
// Run from the package root after tutorial/plot.R:
//   node tutorial/render.mjs              (tutorial page)
//   node tutorial/render.mjs validation   (validation page)
// Uses a dedicated headless Chromium (Playwright), never the desktop browser.
import { chromium } from 'playwright';
import { fileURLToPath, pathToFileURL } from 'node:url';
import path from 'node:path';

const here = path.dirname(fileURLToPath(import.meta.url));
const name = process.argv[2] ?? 'tutorial';
const out = path.join(here, '..', 'man', 'figures', `${name}.png`);

const browser = await chromium.launch({ headless: true });
const page = await browser.newPage({
  viewport: { width: 1240, height: 900 },
  deviceScaleFactor: 2,
});
await page.goto(pathToFileURL(path.join(here, `${name}.html`)).href);
await page.waitForLoadState('networkidle');
await page.locator('.sheet').screenshot({ path: out });
await browser.close();
console.log(`${out} written`);
