# The Transmogrifier Website

Marketing website for The Transmogrifier - built with Astro, Tailwind CSS, and StoryBrand messaging framework.

## Tech Stack

- **Astro** - Static site generator
- **Tailwind CSS** - Styling with app's exact color palette
- **StoryBrand Framework** - Customer-centric messaging
- **Cloudflare Pages** - Hosting & deployment

## Local Development

Install dependencies:
```bash
npm install
```

Start dev server:
```bash
npm run dev
```

Visit http://localhost:4321

## Build for Production

```bash
npm run build
```

Preview production build:
```bash
npm run preview
```

## Deployment to Cloudflare Pages

### One-Time Setup

1. Go to [Cloudflare Dashboard](https://dash.cloudflare.com)
2. Navigate to **Workers & Pages**
3. Click **Create application** → **Pages** tab
4. Click **Connect to Git**
5. Authorize Cloudflare to access your GitHub
6. Select repository: `dbreck/the-transmogrifier`

### Build Configuration

- **Framework preset:** Astro
- **Build command:** `cd website && npm install && npm run build`
- **Build output directory:** `website/dist`
- **Root directory:** `/`
- **Environment variables:** None needed

### Custom Domain

1. After first deployment, go to your Pages project settings
2. Click **Custom domains**
3. Add `thetransmogrifier.app`
4. Cloudflare will auto-configure DNS (since your domain is already on Cloudflare)
5. SSL certificate will be provisioned automatically

### Auto-Deployment

Every push to `master` branch automatically triggers a new deployment.

## Project Structure

```
website/
├── src/
│   ├── layouts/
│   │   └── BaseLayout.astro      # Base layout with nav/footer
│   ├── pages/
│   │   ├── index.astro            # Landing page (StoryBrand)
│   │   ├── features.astro         # Feature details
│   │   ├── pricing.astro          # Pricing (free)
│   │   ├── docs.astro             # Documentation
│   │   └── changelog.astro        # Version history
│   └── components/                # Reusable components (add as needed)
├── public/
│   └── images/                    # Screenshots & assets
├── astro.config.mjs               # Astro configuration
├── tailwind.config.mjs            # Tailwind with app colors
├── package.json                   # Dependencies
└── README.md                      # This file
```

## Design System

Colors match the app exactly:
- Background: `#1a1d29` (gray-900)
- Cards: `#242938` (gray-800)
- Primary Blue: `#4f7df7` (blue-600)
- Accent Green: `#22b14c`
- Accent Red: `#ef4444`
- Accent Yellow: `#eac328`

## Adding Screenshots

1. Add screenshots to `/public/images/`
2. Reference in pages: `<img src="/images/your-screenshot.png" alt="..." />`
3. Screenshots are already copied from `/Screenshots` directory

## Updating Content

- **Landing page copy:** Edit `src/pages/index.astro`
- **Features:** Edit `src/pages/features.astro`
- **Docs:** Edit `src/pages/docs.astro`
- **Changelog:** Edit `src/pages/changelog.astro` (add new releases)
- **Navigation:** Edit `src/layouts/BaseLayout.astro`

## StoryBrand Framework

The site follows the 7-part StoryBrand framework:
1. **Character:** Web designers/developers
2. **Problem:** Manual image conversion, slow workflows
3. **Guide:** The Transmogrifier
4. **Plan:** 3-step workflow (drag → choose → process)
5. **CTA:** Download buttons throughout
6. **Failure:** Slow sites, wasted time
7. **Success:** 30-second workflows, faster sites

## Performance

- Static site = instant page loads
- Global CDN via Cloudflare
- Optimized assets
- Zero JavaScript for content pages

## Support

- Issues: [GitHub Issues](https://github.com/dbreck/the-transmogrifier/issues)
- Docs: See `/docs` page on live site
