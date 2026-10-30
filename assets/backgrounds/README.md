# Adding store backgrounds later

Place the supplied background image directly in this directory. Add an item to
`catalog.json`, using an ID that will never change after players purchase it:

```json
{
  "id": "forest_home",
  "name": {"en": "Forest home", "zh_CN": "森林小屋"},
  "price": 80,
  "asset": "assets/backgrounds/forest_home.png",
  "colors": ["DCEFE3", "F2F6DA"]
}
```

`price` is game coins, not RM. The image uses BoxFit.cover, so keep the lower
middle area free for the walking monster and allow cropping around the edges.
The current free Mint meadow uses the supplied `assets/videos/background.png`,
also shown behind the post-intro monster reveal. The gradient remains a fallback.
No paid background artwork has been invented. Items with missing bundled image paths are not listed for sale.
Rebuild the app after adding bundled files or editing the catalog.

Background purchases and selection persist in the ledger and backups, separately
from accessories. Each purchase stores the actual paid price, so future catalog
price edits do not change coins already spent. Removing an image/catalog entry
keeps ownership; the scene temporarily falls back to the free meadow. Returning
the same item ID restores its availability. This is a bundled-asset catalog,
not an in-app image-upload feature or a real-money payment system.
