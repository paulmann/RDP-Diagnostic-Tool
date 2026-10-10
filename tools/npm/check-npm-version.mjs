#!/usr/bin/env node
/**
 * Version-sync gate for the npm package.
 *
 * The published npm version must match the version embedded in the shipped
 * PowerShell script ($script:ToolVersion). Run from the package root:
 *   node tools/npm/check-npm-version.mjs
 * Exits 1 on mismatch, 0 when in sync.
 */
import { readFileSync } from 'node:fs';
import path from 'node:path';
import process from 'node:process';

const root = process.argv[2] ? path.resolve(process.argv[2]) : process.cwd();
const pkg = JSON.parse(readFileSync(path.join(root, 'package.json'), 'utf8'));
const script = readFileSync(path.join(root, 'RDP-Tool.ps1'), 'utf8');

const match = script.match(/\$script:ToolVersion\s*=\s*\[version\]'(\d+\.\d+\.\d+(?:\.\d+)?)'/);
if (!match) {
  process.stderr.write(`Could not find $script:ToolVersion in ${path.join(root, 'RDP-Tool.ps1')}\n`);
  process.exit(1);
}

const scriptVersion = match[1];
const bad = (message) => {
  process.stderr.write(`${message}\n`);
  process.exit(1);
};

if (scriptVersion !== pkg.version) {
  bad(
    `Version mismatch: package.json has ${pkg.version}, RDP-Tool.ps1 declares ${scriptVersion}. ` +
      'Update both before publishing.'
  );
}

const changelog = readFileSync(path.join(root, 'CHANGELOG.md'), 'utf8');
const top = changelog.match(/^##\s*\[(\d+\.\d+\.\d+(?:\.\d+)?)\]/m);
if (!top) {
  bad('Could not read the top CHANGELOG.md version entry.');
}
if (top[1] !== pkg.version) {
  bad(`Version mismatch: package.json has ${pkg.version}, top CHANGELOG entry is ${top[1]}.`);
}

process.stdout.write(`version sync OK: ${pkg.version} (package.json, RDP-Tool.ps1, CHANGELOG.md)\n`);
