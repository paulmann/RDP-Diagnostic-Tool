// Verifies a published npm release of rdp-diagnostic-tool:
//   - the version manifest resolves and reports the expected shape
//   - the tarball integrity matches what the registry advertises
//   - the shipped RDP-Tool.ps1 is byte-identical to the repository copy and keeps its BOM
//   - the packaged README is the repository README with no relative links (which 404 on the
//     npm package page)
//
// Usage: node tools/npm/verify-published.mjs [version]
import { createHash } from 'node:crypto';
import { execFileSync } from 'node:child_process';
import { mkdtempSync, readFileSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';

const version = process.argv[2] ?? JSON.parse(readFileSync('tools/npm/package.json', 'utf8')).version;
const pkgName = JSON.parse(readFileSync('tools/npm/package.json', 'utf8')).name;
const registry = `https://registry.npmjs.org/${pkgName}`;

const failures = [];
const check = (label, ok, detail = '') => {
  console.log(`${ok ? 'OK  ' : 'FAIL'} ${label}${detail ? `: ${detail}` : ''}`);
  if (!ok) failures.push(label);
};

const res = await fetch(`${registry}/${version}`, { signal: AbortSignal.timeout(60000) });
if (res.status !== 200) {
  console.error(`FAIL ${pkgName}@${version} is not published (HTTP ${res.status})`);
  const packument = await fetch(registry, { signal: AbortSignal.timeout(60000) }).then((r) => r.json());
  console.error('packument time:', JSON.stringify(packument.time ?? {}));
  process.exit(1);
}
const manifest = await res.json();

check('version resolves', manifest.version === version, manifest.version);
check('license declared', Boolean(manifest.license), manifest.license);
check('bin exposes rdp-tool', Boolean(manifest.bin?.['rdp-tool']), JSON.stringify(manifest.bin));
check('windows-only declaration', JSON.stringify(manifest.os) === '["win32"]', JSON.stringify(manifest.os));
check('file count', manifest.dist.fileCount === 6, String(manifest.dist.fileCount));

const tarball = await fetch(manifest.dist.tarball, { signal: AbortSignal.timeout(120000) });
const bytes = Buffer.from(await tarball.arrayBuffer());
const integrity = `sha512-${createHash('sha512').update(bytes).digest('base64')}`;
check('tarball integrity matches the advertised digest', integrity === manifest.dist.integrity);

const dir = mkdtempSync(path.join(tmpdir(), 'verify-'));
writeFileSync(path.join(dir, 'pkg.tgz'), bytes);
execFileSync('tar', ['-xzf', 'pkg.tgz'], { cwd: dir });

const sha256 = (buf) => createHash('sha256').update(buf).digest('hex');
const shipped = readFileSync(path.join(dir, 'package', 'RDP-Tool.ps1'));
const repo = readFileSync(path.resolve('RDP-Tool.ps1'));
check('shipped script is byte-identical to the repository copy', sha256(shipped) === sha256(repo), sha256(shipped));
check('shipped script keeps its UTF-8 BOM', shipped[0] === 0xef && shipped[1] === 0xbb && shipped[2] === 0xbf);

const readme = readFileSync(path.join(dir, 'package', 'README.md'), 'utf8');
check('packaged README matches the repository README', readme === readFileSync(path.resolve('README.md'), 'utf8'));
const relative = (readme.match(/\]\((?!#|https?:)[^)]*\)/g) || []).length;
check('packaged README has no relative links', relative === 0, String(relative));
check('packaged README carries badges', /img\.shields\.io/.test(readme));

console.log(`\nunpacked in: ${dir}`);
console.log(failures.length === 0 ? 'all checks passed' : `${failures.length} check(s) failed`);
process.exit(failures.length === 0 ? 0 : 1);
