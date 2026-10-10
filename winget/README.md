# winget manifests

This directory holds the [winget](https://github.com/microsoft/winget-pkgs) manifest set
for `Paulmann.RDPDiagnosticTool`, laid out in the repository structure winget expects:

```
manifests/p/Paulmann/RDPDiagnosticTool/<version>/Paulmann.RDPDiagnosticTool.yaml
manifests/p/Paulmann/RDPDiagnosticTool/<version>/Paulmann.RDPDiagnosticTool.installer.yaml
manifests/p/Paulmann/RDPDiagnosticTool/<version>/Paulmann.RDPDiagnosticTool.locale.en-US.yaml
```

## How it works

The package installs the portable ZIP from the GitHub release and exposes
`rdp-tool.exe` as the command `rdp-tool`. winget refuses script files
(`.cmd`/`.ps1`) as portable nested files, which is why the release ZIP ships a real
launcher executable built from `tools/release/launcher/rdp-tool.cs`.

PowerShell 7 (`pwsh`) is a runtime requirement, not a file in the package; the
manifests name it in the package description, and the launcher prints the install
command if `pwsh` is missing.

## Regenerating

Never hand-edit the version or the hash. After bumping the version and publishing a
GitHub release with assets:

```powershell
pwsh -NoLogo -NoProfile -NonInteractive -File .\tools\release\make-release-assets.ps1
pwsh -NoLogo -NoProfile -NonInteractive -File .\tools\release\make-package-manifests.ps1
winget validate --manifest .\winget\manifests\p\Paulmann\RDPDiagnosticTool\<version>
```

`make-package-manifests.ps1` reads the version from `RDP-Tool.ps1` and the SHA256 from
the release ZIP, so the manifest can never disagree with the shipped artifact.

## Submitting to winget-pkgs

winget installs packages from the community repository `microsoft/winget-pkgs`, so the
manifest set has to be merged there. The repository copy here is the source of truth so
the manifests stay reviewable in this project's history:

```powershell
# one-time
gh repo fork microsoft/winget-pkgs --clone=false

# per release: copy this directory to the fork and open a PR
gh repo clone <your-fork>/winget-pkgs
Copy-Item -Recurse -Force .\winget\manifests\* .\winget-pkgs\manifests\
cd .\winget-pkgs
git checkout -b Paulmann.RDPDiagnosticTool-<version>
git add manifests/p/Paulmann/RDPDiagnosticTool
git commit -m "New package: Paulmann.RDPDiagnosticTool version <version>"
git push -u origin Paulmann.RDPDiagnosticTool-<version>
gh pr create --repo microsoft/winget-pkgs --fill
```

Until that PR is merged, `winget install Paulmann.RDPDiagnosticTool` will not resolve —
local installs can be tested from the manifest directly with
`winget install --manifest .\winget\manifests\p\Paulmann\RDPDiagnosticTool\<version>`.
