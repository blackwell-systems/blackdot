# Docsify Documentation Site

This directory contains the Docsify-powered documentation website for the blackdot repository.

## 🌐 Live Site

**URL:** https://blackwell-systems.github.io/dotfiles/

(Configure this in GitHub Settings → Pages → Source: `main` branch, `/docs` folder)

## 🚀 Local Development

### Option 1: Using docsify-cli (Recommended)

```bash
# Install docsify-cli globally
npm install -g docsify-cli

# Serve docs locally
docsify serve docs

# Open browser to http://localhost:3000
```

### Option 2: Using Python

```bash
# Serve with Python's built-in server
cd docs
python3 -m http.server 8000

# Open browser to http://localhost:8000
```

### Option 3: Using any static server

```bash
# npx (no install needed)
npx serve docs

# Or use any static file server
```

## 📁 Structure

```
docs/
├── index.html          # Docsify configuration
├── _coverpage.md       # Landing page with logo and links
├── _sidebar.md         # Navigation sidebar
├── .nojekyll          # Tell GitHub Pages to skip Jekyll
├── README.md          # Main documentation (home page)
├── README-FULL.md     # Comprehensive documentation
├── vault-README.md    # Vault system documentation
├── macos-settings.md  # macOS settings guide
├── CONTRIBUTING.md    # Contribution guide
├── SECURITY.md        # Security policy
└── CHANGELOG.md       # Version history
```

## ✨ Features

- **No build step** – Pure markdown, rendered on-the-fly
- **Full-text search** – Search across all documentation
- **Responsive design** – Works on mobile, tablet, desktop
- **Syntax highlighting** – Bash, YAML, JSON, Docker, etc.
- **Copy code buttons** – One-click code copying
- **Pagination** – Previous/Next navigation
- **Tabs** – Organize related content
- **Zoom images** – Click images to enlarge
- **Theme color** – Custom purple (#8A2BE2) matching brand

## 🔧 Configuration

Edit `docs/index.html` to customize:

```javascript
window.$docsify = {
  name: 'Dotfiles',           // Site name in sidebar
  repo: 'user/repo',          // GitHub repo link
  themeColor: '#8A2BE2',      // Brand color
  loadSidebar: true,          // Use _sidebar.md
  coverpage: true,            // Use _coverpage.md
  // ... more options
}
```

## 📝 Adding Content

### New Page

1. Create a new `.md` file in `docs/`
2. Add link to `_sidebar.md`
3. Content is automatically rendered!

Example:
```markdown
<!-- docs/my-new-page.md -->
# My New Page

Content goes here...
```

```markdown
<!-- docs/_sidebar.md -->
- **My Section**
  - [My New Page](my-new-page.md)
```

### Update Navigation

Edit `docs/_sidebar.md` to modify the sidebar menu.

### Update Cover Page

Edit `docs/_coverpage.md` to change the landing page.

## 🎨 Customization

### Change Theme

Replace the theme CSS in `index.html`:

```html
<!-- Available themes -->
<link rel="stylesheet" href="//cdn.jsdelivr.net/npm/docsify@4/lib/themes/vue.css">
<link rel="stylesheet" href="//cdn.jsdelivr.net/npm/docsify@4/lib/themes/buble.css">
<link rel="stylesheet" href="//cdn.jsdelivr.net/npm/docsify@4/lib/themes/dark.css">
<link rel="stylesheet" href="//cdn.jsdelivr.net/npm/docsify@4/lib/themes/pure.css">
```

### Add Plugins

Browse available plugins: https://docsify.js.org/#/plugins

Add to `index.html`:
```html
<script src="//cdn.jsdelivr.net/npm/docsify-plugin-name"></script>
```

## 🚢 Deployment

### GitHub Pages Setup

1. Go to repository **Settings** → **Pages**
2. **Source:** Deploy from a branch
3. **Branch:** `main` (or `master`)
4. **Folder:** `/docs`
5. Click **Save**

GitHub will automatically deploy your site to:
```
https://blackwell-systems.github.io/dotfiles/
```

### Custom Domain (Optional)

1. Add `CNAME` file to `docs/`:
   ```
   docs.example.com
   ```

2. Configure DNS:
   ```
   CNAME record: docs → blackwell-systems.github.io
   ```

3. Enable HTTPS in GitHub Pages settings

## 📚 Resources

- **Docsify Documentation:** https://docsify.js.org/
- **Docsify Plugins:** https://docsify.js.org/#/plugins
- **GitHub Pages:** https://pages.github.com/
- **Markdown Guide:** https://www.markdownguide.org/

## 🐛 Troubleshooting

### Site not loading on GitHub Pages

- Ensure `.nojekyll` file exists in `docs/`
- Check GitHub Pages settings (Settings → Pages)
- Wait 2-3 minutes after pushing changes
- Check Actions tab for deployment status

### 404 on navigation

- Ensure file paths in `_sidebar.md` are correct
- Use relative paths: `my-page.md` not `/my-page.md`
- File names are case-sensitive

### Search not working

- Search requires files to be served via HTTP (not `file://`)
- Use `docsify serve` or any web server for local development

### Styles not loading

- Check browser console for CDN errors
- Ensure you have internet connection (CDN-based)
- Consider self-hosting assets for offline development

---

**Need help?** [Open an issue](https://github.com/blackwell-systems/blackdot/issues)
