# npm channel

The npm package **`rdp-diagnostic-tool`** ships the same `RDP-Tool.ps1` as the GitHub
release plus a small launcher. It is a convenience channel, not a different tool:
diagnostics, remediation, exit codes and self-update behave identically.

## Requirements

| Requirement | Notes |
|---|---|
| Windows 10 / 11 / Server 2016+ | The package declares `os: win32` and refuses to start elsewhere |
| Node.js 18 or later | Only to install/unpack the package |
| PowerShell 7+ (`pwsh`) | `winget install Microsoft.PowerShell`. PowerShell 5.1 is **not** supported |
| Administrator rights | Only for changes (`-EnableRDP`, `-SetPort`, `-AddUser`, ...). Diagnostics work unelevated |

The launcher looks for `pwsh.exe` in `%ProgramFiles%\PowerShell\7\`, then on `PATH`.

## Install

```powershell
# try it without installing anything
npx rdp-diagnostic-tool@5.0.0 -Version

# permanent install: puts rdp-tool (and rdp-diagnostic-tool) on PATH
npm install -g rdp-diagnostic-tool
```

## Use

Arguments are passed through to the script unchanged, and the script's exit code is
returned to the caller, so CI and other scripts can branch on it.

```powershell
rdp-tool                                     # full read-only audit
rdp-tool -ExportReport .\report.html -ExportJson .\report.json
rdp-tool -TestRdpTarget "srv01.contoso.com:3390"
rdp-tool -EnableRDP -Force                   # elevated: enable + repair, no prompts
rdp-tool -Help                               # complete reference
```

## Exit codes

| Code | Meaning |
|---|---|
| 0 | success - system ready, action completed, or already up to date |
| 1 | **critical** diagnostics - RDP will not work until resolved |
| 2 | errors detected - RDP degraded or limited |
| 3 | unsupported Windows edition (Home / SE cannot host RDP) |
| 4 | prerequisite not met - elevation required, invalid parameter combination, or non-Windows platform (the launcher also uses 4 on non-Windows) |
| 5 | update available (`-CheckUpdate` only) |
| 6 | update check / update failed |
| 99 | unhandled script error; the launcher also uses 99 when `pwsh` cannot be started |

## Update

The script updates itself in place; the npm wrapper only starts it, so an update
survives until the package itself is reinstalled.

```powershell
rdp-tool -CheckUpdate      # 0 = current, 5 = newer release, 6 = check failed
rdp-tool -Update -Force    # backup + atomic replace of RDP-Tool.ps1
npm update -g rdp-diagnostic-tool   # refresh the wrapper and the bundled copy
```

## Uninstall

```powershell
npm uninstall -g rdp-diagnostic-tool
```

Nothing is written to the registry. Reports and logs live only where you asked for
them (`-ExportReport`, `-ExportJson`, `-LogPath`).

## Troubleshooting

| Symptom | Cause and fix |
|---|---|
| `PowerShell 7 (pwsh) was not found` | Install PowerShell 7: `winget install Microsoft.PowerShell` |
| `RDP-Tool diagnoses Windows Remote Desktop. It runs on Windows only` | The package is Windows-only by design (`os: win32`) |
| Script is blocked by execution policy | The launcher already passes `-ExecutionPolicy Bypass`; if a machine policy forbids it, use the GitHub release and an approved signing policy |
| `npm` cannot resolve the global bin directory | Check `npm config get prefix` and that its `bin` (`%PREFIX%` on Windows) is on `PATH` |

## Building and publishing (maintainers)

The publishable tree is generated, never edited in place:

```powershell
node tools/npm/build-npm-package.mjs        # -> dist/npm
cd dist/npm
npm pack --dry-run                          # what would be published (6 files)
npm publish --access public
```

`dist/npm` contains exactly what npm publishes: `package.json`, `bin/rdp-tool.mjs`,
`RDP-Tool.ps1`, `README.md`, `CHANGELOG.md`, `LICENSE`. The build fails if
`RDP-Tool.ps1` lost its UTF-8 BOM, because Windows PowerShell 5.1 and Notepad need it.

Version consistency is enforced by `tools/npm/check-npm-version.mjs` (wired to
`prepack`): the version in `package.json` must match `$script:ToolVersion` in
`RDP-Tool.ps1` and the top `CHANGELOG.md` entry. Bump all three together.

Authentication for publishing:

```powershell
npm login --auth-type=web       # interactive, browser-based
npm whoami                      # confirm the account before publishing
```

With two-factor authentication enabled on the account, `npm publish` asks for a
one-time password. A non-interactive session cannot answer that prompt, so either pass
it explicitly (`npm publish --otp <code>`) or publish with a granular access credential
created with **Bypass 2FA** enabled, supplied through the environment (a repository
secret in CI, or an entry in the user-level `.npmrc` for a local run). Never commit such
a credential to the repository.

For releases after the first one, prefer **trusted publishing** (OIDC) over a stored
credential. Configure a Trusted Publisher for this package on npmjs.com (GitHub Actions,
repository `paulmann/RDP-Diagnostic-Tool`, workflow filename), then publish from a
workflow that declares `id-token` write permission. This needs npm CLI 11.5.1+ and
Node 22.14+ and produces a provenance attestation automatically.

> Published versions are immutable: a mistake in `5.0.0` cannot be fixed in place,
> only superseded by `5.0.1`.
