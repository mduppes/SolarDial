# Sundial landing page

Buildless HTML, CSS and JavaScript. `dist/` contains the source that is served directly, with no frameworks, remote fonts, analytics, or third-party scripts. The illustrative product scene contains no real location or screen data. The interactive schedule uses the same mired-space blending model as the native app with explicitly illustrative times.

## Preview

From the repository root:

```sh
python3 -m http.server 8765 --directory website/dist --bind 127.0.0.1
```

Visit http://127.0.0.1:8765. Any static host can serve `website/dist` with no build command.

## Refresh the preview download

```sh
./scripts/build-app.sh
./scripts/package-download.sh
```

The download is the actual Apple silicon build, ad-hoc signed and not notarized. Keep version/architecture labels and installation notes in `dist/index.html` accurate when changing the release. Download artifacts are ignored by the app repository, but must be included when deploying the site. `package-download.sh` packages the bundle and writes a checksum.

## Support and source links

The existing TokenTracking Stripe Payment Link is reused: https://donate.stripe.com/6oU28k9KFap37yN5tIgnK00. Donate links open Stripe-hosted checkout in a new tab; the site has no payment keys, embeds or backend. Creator links also follow TokenTracking. GitHub links currently point to `mduppes/Flux`, the existing repository, until it is renamed.

## Sites publication

`.openai/hosting.json` records the Sites project identity. Publish from a separate staged checkout using the Sites source workflow so the app's repository never gains an embedded Git repository. Include `dist/downloads` when staging. New Sites use owner-private access by default; public access is a separate hosting setting. Preserve the project ID on subsequent edits.
