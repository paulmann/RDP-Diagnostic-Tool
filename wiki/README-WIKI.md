# Wiki Maintainer Guide

This directory contains the source files for the [RDP Diagnostic Tool GitHub Wiki](https://github.com/paulmann/RDP-Diagnostic-Tool/wiki).

## 📁 File Structure

```
wiki/
├── Home.md                  # Landing page
├── Installation.md
├── Configuration.md
├── Usage.md
├── Architecture.md
├── Troubleshooting.md
├── Advanced-Diagnostics.md
├── Security.md
├── Performance.md
├── Enhancement-Roadmap.md
├── Contributing.md
├── Changelog.md
├── _Sidebar.md              # Persistent sidebar navigation
├── _Footer.md               # Persistent footer
└── README-WIKI.md           # This file
```

## 🔄 Deploying to GitHub Wiki

The GitHub Actions workflow `.github/workflows/deploy-wiki.yml` automatically deploys changes to the GitHub Wiki whenever files in `wiki/` are updated on the `main` branch.

### Manual Deployment

```bash
# Clone the wiki repo
git clone https://github.com/paulmann/RDP-Diagnostic-Tool.wiki.git wiki-repo

# Copy updated pages
cp wiki/*.md wiki-repo/

# Push to wiki
cd wiki-repo
git add .
git commit -m "docs: update wiki from source"
git push origin master
```

## ✏️ Editing Guidelines

- Update the `<!-- Last Updated: -->` comment at the top of each file when making changes
- Update `Changelog.md` for every release
- Maintain `_Sidebar.md` when adding new pages
- All internal links use `[[Page Name]]` syntax
- Test Mermaid diagrams at [mermaid.live](https://mermaid.live) before committing

## 📋 Adding a New Page

1. Create `wiki/NewPage.md` with proper header comment and `[[Home]] › NewPage` breadcrumb
2. Add entry to `wiki/_Sidebar.md`
3. Add cross-links from related pages
4. Update `wiki/Home.md` documentation roadmap table
