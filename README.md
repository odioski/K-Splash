# K-Unsplash Widget

Plasma 6 wallpaper widget that fetches random photos from the Unsplash API.

## Features

- Uses an Unsplash developer access key
- Supports a category or custom query such as `dark`, `fun`, `skyline`, and `happy`
- Lets users choose how often the wallpaper refreshes
- Can change the KDE desktop wallpaper automatically
- Shows photographer attribution with Unsplash referral links

## Settings

The widget settings page includes:

- `Unsplash Access Key`
- `Category / query`
- `Refresh interval (minutes)`
- `Change wallpaper after each refresh`
- target `Resolution width` and `Resolution height`

## Package

Build a clean upload package with:

```bash
./package-release.sh
```

This excludes Git metadata, Codex files, and `contents/config/local.json`.

## Publishing

Files prepared for store upload:

- `STORE-LISTING.md`
- `RELEASE-NOTES.md`
- `UPLOAD-CHECKLIST.md`

## License

MIT. See `LICENSE`.
