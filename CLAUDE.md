# VAI — Veterinary Academy International

Public website for Veterinary Academy International (vai.vet), the veterinary academy of Academia Europa. Operated by Solex Education Unipessoal LDA, Portugal.

## Tech stack

- **Framework:** Astro 5 (static site)
- **Styling:** Tailwind CSS v4 (via `@tailwindcss/vite`), plus hand-written CSS in `src/styles/global.css`
- **Content:** MDX (`@astrojs/mdx`)
- **Sitemap:** `@astrojs/sitemap`
- **Language:** TypeScript (`tsconfig.json`), Astro components (`.astro`)
- **Node:** v20 (per CI workflow)

## Folder structure

```
vai/
├── astro.config.mjs        # site config, integrations, Tailwind vite plugin
├── package.json             # scripts: dev, build, preview, astro
├── tsconfig.json
├── .env.example              # PUBLIC_LMS_URL, PUBLIC_LMS_ENABLED
├── .github/workflows/deploy.yml   # GitHub Pages deploy pipeline
├── public/
│   ├── CNAME                 # persists custom domain (vai.vet) across deploys
│   ├── favicon.svg, og-image.svg, vai-logo.svg
│   └── ...images (founder portrait, heritage plates)
└── src/
    ├── components/           # Nav, Footer, ContactForm, InstitutionalBar, PageHero, Section, etc.
    ├── layouts/Base.astro    # shared page layout
    ├── pages/                # route = file path (index, about, programmes, faculty, faq, contact, etc.)
    └── styles/global.css     # Tailwind theme tokens, brand colours, typography, components
```

Pages map directly to routes: `/`, `/about`, `/programmes`, `/veterinary-longevity`, `/faculty`, `/academic-standards`, `/certificate-policy`, `/cpd-ce-alignment`, `/faq`, `/contact`.

## Deployment

- Hosted on **GitHub Pages**, deployed via GitHub Actions (`.github/workflows/deploy.yml`) on every push to `main`.
- Build runs `npm install && npm run build`, uploads `./dist`, then deploys via `actions/deploy-pages`.
- Environment variables (`PUBLIC_LMS_URL`, `PUBLIC_LMS_ENABLED`) are injected at build time from **GitHub Actions repository variables**, not `.env` files in production.
- Custom domain `vai.vet` is persisted via `public/CNAME`. DNS: apex `A` records to GitHub Pages IPs, `www` `CNAME` to the GitHub Pages host.
- **This is not Vercel.** Pushing to `main` is what ships to production — there is no separate deploy step.

## Relationship to Academia Europa

VAI is positioned inside Academia Europa, never alongside it. Every page carries an institutional bar linking back to Academia Europa. Do not link to or reference Noble Veterinary Clinic. Do not claim accreditation that has not been formally granted.

## Brand and copy rules

**These rules apply to all work on this site — copy, design, and code.**

- **Colours:**
  - Navy `#0F1B2D`
  - Gold `#C8A46B`
  - Platinum `#8A9099`
  - Ivory `#F7F5F1`
  - Soft Grey `#D9D5CE`
- **Font:** Arial
- **Spelling:** British spelling throughout (e.g. "colour", "programme", "organisation")
- **Punctuation:** no em-dashes, no exclamation marks
- **Register:** peer-to-peer, never marketing or corporate language
