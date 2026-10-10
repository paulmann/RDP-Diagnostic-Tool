#!/usr/bin/env node
/**
 * RDP Diagnostic & Remediation Tool - npm launcher.
 *
 * Runs the bundled PowerShell 7 script (RDP-Tool.ps1) with the caller's
 * arguments and forwards its exit code unchanged, so CI and scripts can rely
 * on the tool's own codes (0 ok, 1 critical, 2 errors, 3 unsupported OS,
 * 4 prerequisite/platform, 5/6 update, 99 script error).
 *
 * Launcher-level failures use codes that the tool itself documents for the same
 * situation: 4 for a non-Windows platform and 99 (generic failure) when the
 * runtime cannot be started at all.
 */
import { spawnSync } from 'node:child_process';
import { existsSync } from 'node:fs';
import path from 'node:path';
import process from 'node:process';
import { fileURLToPath } from 'node:url';

const EXIT_LAUNCH_FAILED = 99;
const EXIT_UNSUPPORTED_PLATFORM = 4;

const packageRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const scriptPath = path.join(packageRoot, 'RDP-Tool.ps1');

if (process.platform !== 'win32') {
  process.stderr.write(
    'RDP-Tool diagnoses Windows Remote Desktop. It runs on Windows only ' +
      `(current platform: ${process.platform}).\n`
  );
  process.exit(EXIT_UNSUPPORTED_PLATFORM);
}

if (!existsSync(scriptPath)) {
  process.stderr.write(`Bundled script not found: ${scriptPath}\n`);
  process.exit(EXIT_LAUNCH_FAILED);
}

/** Resolve pwsh.exe: install locations first (PowerShell 7 is required), then PATH. */
function resolvePwsh() {
  const roots = [process.env.ProgramW6432, process.env.ProgramFiles, 'C:\\Program Files'].filter(
    Boolean
  );
  const candidates = roots.map((root) => path.join(root, 'PowerShell', '7', 'pwsh.exe'));
  for (const candidate of candidates) {
    if (existsSync(candidate)) return candidate;
  }
  return 'pwsh';
}

const pwsh = resolvePwsh();
const args = [
  '-NoLogo',
  '-NoProfile',
  '-NonInteractive',
  '-ExecutionPolicy',
  'Bypass',
  '-File',
  scriptPath,
  ...process.argv.slice(2),
];

const result = spawnSync(pwsh, args, { stdio: 'inherit' });

if (result.error) {
  if (result.error.code === 'ENOENT') {
    process.stderr.write(
      'PowerShell 7 (pwsh) was not found. RDP-Tool requires PowerShell 7.0 or later.\n' +
        'Install it with:  winget install --id Microsoft.PowerShell --source winget\n'
    );
    process.exit(EXIT_LAUNCH_FAILED);
  }
  process.stderr.write(`Failed to start ${pwsh}: ${result.error.message}\n`);
  process.exit(EXIT_LAUNCH_FAILED);
}

if (result.signal) {
  process.stderr.write(`RDP-Tool was terminated by signal ${result.signal}.\n`);
  process.exit(EXIT_LAUNCH_FAILED);
}

process.exit(result.status ?? 1);
