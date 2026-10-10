#!/usr/bin/env node
/**
 * Builds the publishable npm package into dist/npm.
 *
 * Layout produced (exactly what npm publishes, see package.json "files"):
 *   dist/npm/package.json    generated from tools/npm/package.json
 *   dist/npm/bin/rdp-tool.mjs
 *   dist/npm/RDP-Tool.ps1    byte-for-byte copy (UTF-8 with BOM is preserved)
 *   dist/npm/README.md
 *   dist/npm/CHANGELOG.md
 *   dist/npm/LICENSE
 *
 * Usage:
 *   node tools/npm/build-npm-package.mjs
 *   node tools/npm/build-npm-package.mjs --out <dir>
 */
import { copyFileSync, mkdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import path from 'node:path';
import process from 'node:process';
import { fileURLToPath } from 'node:url';

const repoRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const outIndex = process.argv.indexOf('--out');
const outDir =
  outIndex !== -1 && process.argv[outIndex + 1]
    ? path.resolve(process.argv[outIndex + 1])
    : path.join(repoRoot, 'dist', 'npm');

const sourcePackage = JSON.parse(
  readFileSync(path.join(repoRoot, 'tools', 'npm', 'package.json'), 'utf8')
);

// Guard: the published version must match the shipped script and the changelog.
const scriptText = readFileSync(path.join(repoRoot, 'RDP-Tool.ps1'), 'utf8');
const versionMatch = scriptText.match(
  /\$script:ToolVersion\s*=\s*\[version\]'(\d+\.\d+\.\d+(?:\.\d+)?)'/
);
if (!versionMatch) {
  process.stderr.write('Build aborted: $script:ToolVersion not found in RDP-Tool.ps1.\n');
  process.exit(1);
}
const scriptVersion = versionMatch[1];
if (scriptVersion !== sourcePackage.version) {
  process.stderr.write(
    `Build aborted: package.json is ${sourcePackage.version} but RDP-Tool.ps1 is ${scriptVersion}.\n`
  );
  process.exit(1);
}
const changelogTop = readFileSync(path.join(repoRoot, 'CHANGELOG.md'), 'utf8').match(
  /^##\s*\[(\d+\.\d+\.\d+(?:\.\d+)?)\]/m
);
if (!changelogTop || changelogTop[1] !== scriptVersion) {
  process.stderr.write(
    `Build aborted: top CHANGELOG entry is ${changelogTop ? changelogTop[1] : 'missing'}, expected ${scriptVersion}.\n`
  );
  process.exit(1);
}

rmSync(outDir, { recursive: true, force: true });
mkdirSync(path.join(outDir, 'bin'), { recursive: true });

copyFileSync(path.join(repoRoot, 'tools', 'npm', 'rdp-tool.mjs'), path.join(outDir, 'bin', 'rdp-tool.mjs'));
copyFileSync(path.join(repoRoot, 'tools', 'npm', 'package.json'), path.join(outDir, 'package.json'));
copyFileSync(path.join(repoRoot, 'RDP-Tool.ps1'), path.join(outDir, 'RDP-Tool.ps1'));
copyFileSync(path.join(repoRoot, 'CHANGELOG.md'), path.join(outDir, 'CHANGELOG.md'));
copyFileSync(path.join(repoRoot, 'LICENSE'), path.join(outDir, 'LICENSE'));
writeFileSync(path.join(outDir, 'README.md'), readFileSync(path.join(repoRoot, 'README.md')));

const ps1 = readFileSync(path.join(outDir, 'RDP-Tool.ps1'));
const hasBom = ps1.length >= 3 && ps1[0] === 0xef && ps1[1] === 0xbb && ps1[2] === 0xbf;
if (!hasBom) {
  process.stderr.write(
    'Build aborted: RDP-Tool.ps1 lost its UTF-8 BOM. Windows PowerShell 5.1 and Notepad need it.\n'
  );
  process.exit(1);
}

process.stdout.write(`built ${outDir} (version ${scriptVersion}, BOM preserved)\n`);
