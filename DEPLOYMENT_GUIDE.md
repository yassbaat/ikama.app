# Iqamah Deployment Guide

## 🚀 Creating a Release (3 Methods)

### Method 1: Manual (One-time)
1. Go to https://github.com/yassbaat/ikama.app/releases
2. Click "Draft a new release"
3. Create tag: `v1.0.0`
4. Upload files from `src-tauri/target/release/bundle/`
5. Publish

### Method 2: PowerShell Script (Local)
```powershell
# Build first
npm run tauri build

# Create release
./release.ps1
```

### Method 3: GitHub Actions (Automated - Recommended)
```bash
# Just push a tag
git tag v1.0.0
git push origin v1.0.0

# GitHub Actions automatically builds and releases!
```

---

## 🌐 Hosting Options Comparison

| Option | Cost | Custom Domain | SSL | Best For |
|--------|------|---------------|-----|----------|
| **GitHub Pages** | Free | ✅ Yes | ✅ Yes | Simple landing page |
| **Cloudflare Pages** | Free | ✅ Yes | ✅ Yes | Better performance, analytics |
| **Vercel** | Free tier | ✅ Yes | ✅ Yes | React apps, serverless functions |
| **Netlify** | Free tier | ✅ Yes | ✅ Yes | Jamstack, forms, CMS |
| **Traditional Hosting** | $5-10/mo | ✅ Yes | ❌ Usually extra | Full control |

### 🏆 My Recommendation: GitHub Pages

**Why:**
- ✅ **100% Free** - No limits on bandwidth
- ✅ **Already integrated** - Same account as your code
- ✅ **Custom domain support** - Can use your own domain
- ✅ **Automatic HTTPS** - SSL certificate included
- ✅ **Simple** - Just HTML/CSS/JS, no build process needed

### Setup GitHub Pages (5 minutes)

1. Create `index.html` in root of repo
2. Go to Settings → Pages
3. Source: Deploy from branch → `main` → `/ (root)`
4. Your site is live at: `https://yassbaat.github.io/ikamah.app/`

### Custom Domain (Optional)
1. Buy domain (Namecheap ~$10/year)
2. Add to GitHub Pages settings
3. Add DNS record: `CNAME` → `yassbaat.github.io`

---

## 📋 Release Checklist

Before each release:
- [ ] Update version in `src-tauri/Cargo.toml`
- [ ] Update version in `package.json`
- [ ] Update `RELEASE_NOTES.md`
- [ ] Test the app locally
- [ ] Build: `npm run tauri build`
- [ ] Create tag: `git tag vX.X.X`
- [ ] Push tag: `git push origin vX.X.X`
- [ ] Verify GitHub Actions completed
- [ ] Edit release notes on GitHub
- [ ] Publish release

---

## 📱 Adding Mobile Support (Future)

### Option A: Flutter (Existing code in /lib)
The repo has Flutter code already. To release:
```bash
cd android
flutter build apk --release
# Upload build/app/outputs/flutter-apk/app-release.apk to GitHub
```

### Option B: Tauri v2 (When stable)
Tauri v2 beta has mobile support. When released:
- iOS: Build via Xcode
- Android: Build APK via Android Studio
- Same codebase as desktop!

---

## 🔗 Useful Links for Landing Page

### Direct Download Links
After release, these URLs work:

**Latest Release Page:**
```
https://github.com/yassbaat/ikama.app/releases/latest
```

**Specific File (example):**
```
https://github.com/yassbaat/ikama.app/releases/download/v1.0.0/iqamah_1.0.0_x64-setup.exe
```

**Badge for README:**
```markdown
![Version](https://img.shields.io/github/v/release/yassbaat/ikama.app)
![Downloads](https://img.shields.io/github/downloads/yassbaat/ikama.app/total)
```

---

## 💰 Cost Summary

| Service | Cost |
|---------|------|
| GitHub (code + releases) | Free |
| GitHub Pages (hosting) | Free |
| Domain (optional) | ~$10/year |
| **Total** | **$0-10/year** |
