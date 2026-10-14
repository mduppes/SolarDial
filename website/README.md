# SolarDial landing page

Plain HTML, CSS and JavaScript built with Vite through npm. Source lives in `website/index.html`, `style.css`, `app.js`, and `public/assets/`; `website/dist/` is generated and ignored. No frameworks, remote fonts, analytics, or third-party runtime scripts. The illustrative product scene contains no real location or screen data. The interactive schedule uses the same mired-space blending model as the native app with explicitly illustrative times.

## Preview

From the repository root:

```sh
nvm use # optional, selects Node 22 from .nvmrc
npm ci
npm run dev
```

Open the local URL printed by Vite. Requires Node 22.12+ (Node 22 is selected for Netlify).

```sh
npm run build
npm run preview
```

The production build goes to `website/dist`; preview serves that build locally. Run all npm commands from the repository root. Commit `package-lock.json` when dependencies change so `npm ci` installs the locked versions.

## Refresh the preview download

```sh
./scripts/build-app.sh
./scripts/package-download.sh
```

The download is the actual Apple silicon build, ad-hoc signed and not notarized. Keep version/architecture labels and installation notes in `index.html` accurate when changing the release. Download artifacts live in `website/downloads/`, outside the build output so Vite builds do not erase them. They are ignored by the app repository and uploaded to the GitHub release. Landing-page downloads point to the v0.1.0 GitHub release so both Sites and Netlify work without generated ZIPs in Git. `package-download.sh` packages the bundle and writes a checksum.

## Donation icon

Use `Resources/SolarDial-donation-icon.png` (relative to the repository root) for a manual donation-page image upload. It is the existing SolarDial sunset icon exported as a 1024 × 1024 PNG.

## Support and source links

SolarDial uses its own Stripe Payment Link: https://buy.stripe.com/28EfZae0V54J7yNaO2gnK01. Donate links open Stripe-hosted checkout in a new tab; the site has no payment keys, embeds or backend. Creator links also follow TokenTracking, with local GitHub SVG brand marks beside their labels and matching donation hearts. Future edits must retain this icon treatment (`.cursor/rules/website-icons.mdc`). GitHub links point to the active `mduppes/SolarDial` repository. The previous `mduppes/Flux` repository is retired.

## Sites publication

`.openai/hosting.json` records the Sites project identity. Run `npm run build` from the repository root, then stage the built `dist/` and this manifest. Publish from a separate staged checkout using the Sites source workflow so the app's repository never gains an embedded Git repository. Generated downloads may be omitted when staging because links use the GitHub release. New Sites use owner-private access by default; public access is a separate hosting setting. Preserve the project ID on subsequent edits.


## Netlify

Connect `mduppes/SolarDial` and deploy `main`. The root `netlify.toml` supplies these settings:

- Base directory: repository root (leave blank).
- Build command: `npm run build`.
- Publish directory: `website/dist`.
- Node version: `22`.

Netlify installs npm dependencies from the root package and lockfile before building. Clear any previous UI overrides for the base/build/publish settings. The site uses no backend or environment variables. Release links and checksums must match the actual GitHub release when changing versions.
