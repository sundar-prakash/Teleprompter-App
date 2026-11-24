# Deploying the website to Vercel at teleprompter.sundarprakash.in

This is a plain static site: no build step and no dependencies. Vercel serves this `website/` folder as-is. `vercel.json` adds clean URLs (`/privacy`, `/terms`, `/support`), redirects and security headers.

## Option A: Vercel dashboard (deploys automatically on every push)

1. Push this folder to GitHub (it's part of `sundar-prakash/Teleprompter-App`).
2. https://vercel.com/new → **Import** `Teleprompter-App`.
3. Configure:
   - **Root Directory:** `website`
   - **Framework Preset:** Other
   - **Build Command:** leave empty / override to nothing
   - **Output Directory:** `.` (leave default)
4. **Deploy.** Check the `*.vercel.app` URL.

## Option B: Vercel CLI (deploy from this machine, no push needed)

```bash
cd website
npx vercel@latest login
npx vercel@latest          # first time: link a new project, accept defaults
npx vercel@latest --prod
```

## Connect the subdomain

1. Vercel → Project → **Settings → Domains → Add** → `teleprompter.sundarprakash.in`.
2. Vercel shows a CNAME target (usually `cname.vercel-dns.com`, or a project-specific `*.vercel-dns-0xx.com`; use exactly what it shows).
3. Cloudflare → `sundarprakash.in` → **DNS → Records → Add record**:
   - Type: `CNAME`
   - Name: `teleprompter`
   - Target: *(value from Vercel)*
   - Proxy status: **DNS only (grey cloud)**, so Vercel can issue the HTTPS certificate
4. Wait for Vercel to show **Valid Configuration** (usually a few minutes).

## Check before submitting to Play

- https://teleprompter.sundarprakash.in loads over HTTPS
- https://teleprompter.sundarprakash.in/privacy loads (this is the Play privacy-policy URL)
- https://teleprompter.sundarprakash.in/support and `/terms` load

After the app is live, the "Get it on Google Play" buttons work automatically (they link to `in.sundarprakash.teleprompter`). Until then they show Play's "not found" page.
