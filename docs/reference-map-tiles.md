# Map tile usage

Tripline currently renders roadmap tiles from `tile.openstreetmap.org` through `flutter_map`.

Production requirements:

- Keep `userAgentPackageName: 'com.raychiu.tripline'` on every `TileLayer`.
- Keep the visible OpenStreetMap attribution rendered by `RichAttributionWidget`.
- Do not add bulk download, prefetch, or offline caching against the public tile service.
- Review the [OpenStreetMap tile usage policy](https://operations.osmfoundation.org/policies/tiles/) before each public release.
- Move to a dedicated tile provider before traffic, caching, or availability requirements exceed the public service policy.

The `flutter_map` debug warning is an intentional policy reminder even when the User-Agent and attribution are configured correctly.
