# Upload Checklist

- Create or sign in to your KDE Store publisher account
- Build a fresh package with `./package-release.sh`
- Confirm `contents/config/local.json` is not inside the `.plasmoid` file
- Confirm the widget installs locally from the packaged `.plasmoid`
- Capture at least 2-3 final screenshots of:
  - widget browser entry
  - widget settings dialog
  - widget running on the desktop
- Upload `com.mrod.k-unsplashwidget.plasmoid`
- Use the title and description from `STORE-LISTING.md`
- Paste `RELEASE-NOTES.md` content into the release/changelog field
- Set license to `MIT`
- Add tags like `plasma`, `plasmoid`, `wallpaper`, `unsplash`, `plasma6`
- Mention that users need their own Unsplash access key
- After publishing, verify the listing appears through Plasma's `Get New Widgets`
