#!/usr/bin/env node
// render.mjs — render each HTML file in INPUT_DIR to PNG in OUTPUT_DIR.
// Viewport is decided by the `data-platform` attribute of `.mockup-frame`:
//   mobile  → 375 wide
//   desktop → 1280 wide
// Falls back to 1280 if the attribute is missing.
//
// Usage: node render.mjs <input_dir> <output_dir>

import { readdir, readFile, mkdir } from 'node:fs/promises';
import { existsSync } from 'node:fs';
import { join, basename, extname, resolve } from 'node:path';
import { pathToFileURL } from 'node:url';

const [, , INPUT_DIR, OUTPUT_DIR] = process.argv;
if (!INPUT_DIR || !OUTPUT_DIR) {
  console.error('usage: render.mjs <input_dir> <output_dir>');
  process.exit(2);
}

let puppeteer;
try {
  puppeteer = (await import('puppeteer')).default;
} catch {
  console.error('puppeteer not installed — install with: npm i -g puppeteer (or run via `npx -y puppeteer ...`)');
  process.exit(3);
}

await mkdir(OUTPUT_DIR, { recursive: true });

const files = (await readdir(INPUT_DIR)).filter(f => f.endsWith('.html'));
if (files.length === 0) {
  console.error(`no .html files in ${INPUT_DIR}`);
  process.exit(0);
}

const browser = await puppeteer.launch({ headless: true });
try {
  for (const file of files) {
    const inputPath = resolve(INPUT_DIR, file);
    const outName = basename(file, extname(file)) + '.png';
    const outputPath = resolve(OUTPUT_DIR, outName);

    const html = await readFile(inputPath, 'utf8');
    const stripped = html.replace(/<style[^>]*>[\s\S]*?<\/style>/gi, '');
    const platformMatch = stripped.match(/data-platform=["'](mobile|desktop)["']/);
    const platform = platformMatch ? platformMatch[1] : 'desktop';
    const width = platform === 'mobile' ? 375 : 1280;

    const page = await browser.newPage();
    await page.setViewport({ width, height: 100, deviceScaleFactor: 2 });
    await page.goto(pathToFileURL(inputPath).href, { waitUntil: 'networkidle0' });

    // Auto-size height to content
    const bodyHeight = await page.evaluate(() => document.body.scrollHeight);
    await page.setViewport({ width, height: bodyHeight, deviceScaleFactor: 2 });

    await page.screenshot({ path: outputPath, fullPage: false });
    await page.close();
    console.log(`rendered: ${outName} (${platform}, ${width}x${bodyHeight})`);
  }
} finally {
  await browser.close();
}
