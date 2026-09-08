# The Transmogrifier: studio website redesign

The website now presents the app as a considered independent design tool: warm paper, ink, vermilion, editorial typography and a photographic botanical specimen. The visual direction follows Danny's request for a boutique design studio sensibility and the vault's Clear pH editorial typography precedent, with a separate identity for this product.

## Design and behavior

- Instrument Serif, including the true italic, provides the display voice. DM Sans handles practical text. Both are hosted locally; their SIL Open Font Licenses are included under `website/public/fonts/`.
- Font sources: [Instrument Serif](https://github.com/google/fonts/tree/main/ofl/instrumentserif), [DM Sans](https://github.com/google/fonts/tree/main/ofl/dmsans).
- The homepage follows one image through its presentation, a real app preview, responsive-pack illustrations and reusable export workflows.
- All six public routes share the new identity. Documentation keeps its twelve existing sections. Four published app releases keep their historical feature and fix notes. The existing privacy policy text is preserved.
- Pricing remains $9.99 with the existing one-time purchase and v1.x update policy. Dated speculative version prices, delivery dates and competitor comparisons were removed. Download buttons describe the existing direct GitHub download destination accurately.
- The existing Buttondown subscription destination and Google Analytics configuration are preserved. The email field now has an explicit visible label.
- Navigation includes keyboard focus styles, a skip link, an accessible mobile toggle and Escape dismissal. Native disclosure controls handle pricing questions. Motion honors reduced-motion preferences.
- App version and download URL are centralized in `website/src/data/product.ts`. This is a website release; the native app remains v1.2.0.

## Assets

- `website/public/images/anthurium.webp` and its 480/960px variants: optimized botanical specimen.
- `docs/design/anthurium-source.png`: original generated specimen, 1536 × 1024.
- `website/public/images/app-preview.webp`: actual CUA capture of the current export-workflow interface, 1054 × 768. Source capture is `docs/design/app-preview.png`.
- The app screenshot uses the isolated review app with the same released export-workflow code, rather than exposing user history or client images. The 2.2 MB → 67 KB caption reports that preview, not a universal savings claim.
- `website/public/images/social-cover.jpg`: 1200 × 630 link-sharing image captured from `docs/design/social-cover.html`; source capture is `docs/design/social-cover.png`. To recapture, temporarily serve the HTML from the website public directory, set a 1200 × 630 browser viewport, wait for fonts and image loading, then capture through CUA. Remove the temporary public HTML afterward.

The specimen was generated with the built-in image generation tool. Final prompt:

> Create a single extraordinary editorial botanical still-life photograph for an independent boutique design studio's software website. Landscape aspect ratio 3:2. One large sculptural glossy deep vermilion-red anthurium flower with its pale yellow spadix and one sweeping dark green stem and curled green leaf, in a simple small cobalt blue glass cylinder vase, against seamless soft muted peach-pink studio backdrop and ground. Hard direct side sunlight casts a beautifully defined large elongated botanical shadow onto the backdrop to the right. Flower slightly left of center, plenty of breathing room, graphic but organic, warm analog print feeling, subtle fine film grain, tactile leaf veins and natural imperfections, striking restrained art direction like a contemporary floral still-life in an art magazine. Camera straight on, close enough flower dominates. No text, lettering, typography, logos, UI, people, frames, watermarks or gradients. Professional still-life photographic realism, not 3D render.

## Verification

Astro production build, browser checks at 320, 390, 768, 1280 and 1440 pixels, one primary heading per page, image loading, documentation anchors, mobile navigation, pricing disclosures, email field validation, download destinations and browser console checks. Small-screen feature-page overflow was fixed by limiting endnote body sizing to its content column. Subscription submission is intentionally not tested with a real address.

GitHub pushes deploy branch previews to the existing Cloudflare Pages project; merging to master deploys production. No hosting or DNS changes are required.
