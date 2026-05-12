# VAI — Veterinary Academy International

Public website for **Veterinary Academy International** — the veterinary academy of Academia Europa.

- **Production domain:** [vai.vet](https://vai.vet)
- **Parent institution:** [Academia Europa](https://academiaeuropa.com)
- **Stack:** Astro 5 · Tailwind v4 · MDX · GitHub Pages
- **Operating entity:** Solex Education Unipessoal LDA, Portugal

## Local development

```bash
npm install
npm run dev      # http://localhost:4321
npm run build    # static output to ./dist
npm run preview
```

## Deployment

Deploys to **GitHub Pages** on every push to `main` via `.github/workflows/deploy.yml`.

### One-time setup

1. Push this repo to GitHub.
2. **Settings → Pages → Source = GitHub Actions**.
3. **Settings → Pages → Custom domain** = `vai.vet`. Enforce HTTPS.
4. DNS at your registrar (`vai.vet`):
   - `A` apex → `185.199.108.153`, `185.199.109.153`, `185.199.110.153`, `185.199.111.153`
   - `CNAME` `www` → `<org>.github.io`

`public/CNAME` persists the custom domain across deploys.

## Pages

```
/                       — homepage
/about                  — what VAI is, who we serve, relationship to Academia Europa
/programmes             — five programme directions
/veterinary-longevity   — flagship direction, five pillars
/faculty                — teach with VAI
/academic-standards     — programme docs, evidence hierarchy, ethics
/contact                — enquiry pathways
```

## Relationship to Academia Europa

VAI is positioned **inside** Academia Europa, never alongside it. Every page carries:

- An **institutional bar** at the top: *"A specialised academy of Academia Europa."*
- Reciprocal linkage to `academiaeuropa.com` in the nav, footer, and contact page.
- The same design language (palette, type, tone) as Academia Europa, with a slightly warmer navy.

When the Academia Europa site activates the live `Visit VAI →` external link, this site is ready to receive that traffic.

## Notes

- Do not link to or reference Noble Veterinary Clinic.
- Do not claim accreditation that has not been formally granted.
- Use the founder's institutional phrasing only (mirrors Academia Europa).
