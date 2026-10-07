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

## Environment variables

Configured in `.env.example`. For production the values are read from
**GitHub Actions repository variables** at build time (Settings → Secrets
and variables → Actions → Variables).

| Variable | Purpose | Default |
| --- | --- | --- |
| `PUBLIC_LMS_URL` | Student sign-in URL for the VAI Learning Management System. Update to the final URL once confirmed with the IT team (Omer / Faisal). | `https://learn.vai.vet/login` |
| `VAI_PUBMED_CONTACT_EMAIL` | VAI Pulse. Operational mailbox sent to NCBI (PubMed) as the contact for this software. Build-time only, never in the site. The deploy workflow defaults to `vai@vai.vet`; a repository **variable** of the same name overrides it. | `vai@vai.vet` (in CI) |
| `NCBI_API_KEY` | VAI Pulse. Optional NCBI API key (3 -> 10 requests/second; not needed). Set as a repository **secret**. | unset |
| `PUBLIC_LMS_ENABLED` | When `true`, the **Login** button is rendered in the main nav and mobile menu. When `false` (default), it is not rendered. Flip to `true` in the production repo variables once the LMS is publicly reachable. | `false` |

## Pages

```
/                       — homepage
/about                  — what VAI is, who we serve, relationship to Academia Europa
/programmes             — five programme directions
/veterinary-longevity   — flagship direction, five pillars
/faculty                — teach with VAI
/academic-standards     — programme docs, evidence hierarchy, ethics
/contact                — enquiry pathways
/pulse/                 — VAI Pulse: what's new in veterinary medicine (public, no login)
/pulse/guidelines/      — VAI Pulse, Guidelines & Consensus
/pulse/{view}/{discipline}/{period}/ — every filter combination (noindex)
```

## VAI Pulse

Public literature feature at `/pulse/` and a highlights section on the homepage. The site is static, so **there is no server cache**: each build takes ONE
snapshot of PubMed (official NCBI E-utilities, no LLM, no scraping) and pre-renders all 120 view x discipline x period pages as plain HTML. The workflow
rebuilds every 3 hours. The last good snapshot is kept in the Actions cache (`.pulse-cache/`); if PubMed is down the build falls back to it and the page
says so. `scripts/verify-pulse-build.mjs` runs after every build and blocks the deploy if the output is unsound (manual override: run the workflow with
`allow_degraded`).

`src/lib/pulse/engine/` is a **generated copy** of the Scientific Radar engine from the `vai-app` repo (`scripts/sync-pulse-engine.mjs` there). Do not edit it
here: change `vai-app`, re-sync, and commit the result. `npm test` fails if the copy was edited by hand.

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
