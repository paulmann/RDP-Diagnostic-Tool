// README structure check: balanced <details>, code fences and no relative links
// (relative targets 404 on the npm package page, which renders the package README).
import { readFileSync } from 'node:fs';

const md = readFileSync(process.argv[2] ?? 'README.md', 'utf8');
const count = (re) => (md.match(re) || []).length;

const detailsOpen = count(/<details>/g);
const detailsClose = count(/<\/details>/g);
const fence = count(/^```/gm);
const rel = new Set();
for (const m of md.matchAll(/\[([^\]]*)\]\(([^)]+)\)/g)) {
  if (!/^(https?:|mailto:|#)/.test(m[2])) rel.add(m[2]);
}

const rows = [
  ['details open/close', `${detailsOpen}/${detailsClose}`, detailsOpen === detailsClose],
  ['<summary> blocks', String(count(/<summary>/g)), true],
  ['code fences', String(fence), fence % 2 === 0],
  ['relative links', rel.size ? [...rel].join(', ') : 'none', rel.size === 0],
];
let ok = true;
for (const [name, value, pass] of rows) {
  if (!pass) ok = false;
  console.log(`${pass ? 'OK  ' : 'FAIL'} ${name}: ${value}`);
}
process.exit(ok ? 0 : 1);
