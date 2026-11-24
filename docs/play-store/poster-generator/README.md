# Play Store screenshot posters

Renders the 8 store screenshots (1080×1920) from raw phone screenshots, using headless Chrome and Pillow.

```bash
WORK=$(mktemp -d)
cp dist/play-store/screenshot/*.jpg assets/logo.png "$WORK"/
python3 docs/play-store/poster-generator/make_posters.py "$WORK" dist/play-store/screenshots-final
```

Edit the `slides` list in `make_posters.py` to change the order, headlines or which screenshot each slide uses.
