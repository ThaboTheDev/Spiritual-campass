# Bundled fonts

`google_fonts` is configured with `allowRuntimeFetching = false`, so the app
never downloads fonts. The families below must be present here before
`flutter build`; run `bash tool/fetch_fonts.sh` once to fetch them.

| File | Family / weight | Used for |
| --- | --- | --- |
| IBMPlexSans-Regular.ttf | IBM Plex Sans 400 | body text |
| IBMPlexSans-Medium.ttf | IBM Plex Sans 500 | labels |
| IBMPlexSans-SemiBold.ttf | IBM Plex Sans 600 | buttons, values |
| IBMPlexSans-Bold.ttf | IBM Plex Sans 700 | section headers |
| IBMPlexMono-Regular.ttf | IBM Plex Mono 400 | coordinates |
| IBMPlexMono-Medium.ttf | IBM Plex Mono 500 | coordinates |
| SourceSerif4-Regular.ttf | Source Serif 4 400 | titles |
| SourceSerif4-SemiBold.ttf | Source Serif 4 600 | titles |

`google_fonts` finds a bundled font by matching the asset basename
(`<Family><Variant>.ttf`) declared in `pubspec.yaml`, so the names above must
not change. If a file is missing the theme falls back to the platform sans
serif instead of crashing.

Licences: IBM Plex and Source Serif 4 are released under the SIL Open Font
License 1.1 (see the upstream repositories).
