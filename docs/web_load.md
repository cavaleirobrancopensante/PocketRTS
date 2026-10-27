# Web version: what it downloads and why it loads faster (0.14.33)

The owner asked: "this game load screen before the game loads is taking too long, can long loading be fixed?"
Before 0.14.33 a player downloaded the whole game behind Godot's splash, on the first visit and again after every update.

## What was in the download (0.14.32)

The GitHub Pages artifact was 264 MB. About 118 MB of that is `Holdfast.apk`, which only Android players download. The web game was:

| file | size | what |
|---|---|---|
| `index.pck` | 105.7 MB | everything the game has |
| `index.wasm` | 39.5 MB | the Godot engine (10.1 MB gzipped) |
| `index.js`, `index.html`, icons | 0.3 MB | |

Inside `index.pck` (measured with `tools/web/pck_tool.py list`):

| | MB | |
|---|---|---|
| music (`assets/music`, 53 pieces) | 49.0 | Ogg, already compressed |
| unit, building, terrain and effect art | 30.6 | lossless WebP already (`.ctex`) |
| `docs/redraw_refs` | 7.4 | reference pictures for the art redraws, **exported by accident** (the presets only left out `art/` and `tools/`) |
| voices (en 4.7, pt 2.8, es 2.7) | 10.2 | Ogg |
| sound effects (`assets/audio`) | 4.5 | WAV imported as QOA already |
| code (`.gdc`), scenes, data, fonts | ~3 | |

So the art and sounds were already stored about as small as they go without changing how they look or sound. The waste was: the music in the first download, the accidental docs, and every update re-downloading all 106 MB because one file held both the code and the art.

## What changed

1. **Two packs.** The "Web" export preset now leaves out `assets/` (and `docs/`, `build/`): `index.pck` is the code, scenes and data, about 2 MB. A new preset "Web assets" exports the art, sounds and voices; `tools/web/pck_tool.py assets` keeps only those entries and writes them in a fixed order, so the same art always gives a byte-identical pack (checked after a full reimport from scratch: same hash). It is published as `assets.<hash>.pck`. `scripts/web_boot.gd` (the first autoload) mounts it before the game loads anything; on Android and the desktop it does nothing.
2. **Music on demand.** The music is not in either pack. The `.ogg` files sit next to the page in `music/`, listed (with a content hash) in the page; `scripts/music.gd` downloads a piece when it is first wanted (`HTTPRequest` + `AudioStreamOggVorbis.load_from_buffer`). The piece that was playing carries on until the new one has arrived; the next menu overture, the end-of-match stings and a fighting piece are fetched ahead while you play. Up to 6 downloaded pieces stay in memory. On Android everything is still inside the app (`ResourceLoader.exists` finds the music there first).
3. **Kept by the browser.** The loading page routes the engine, both packs and the music through the browser's Cache Storage, keyed by each file's content hash. A returning player loads everything unchanged from the cache without asking the server; after an update only the files whose hash changed are downloaded, and old copies are deleted a few seconds after the game starts. (Without Cache Storage, e.g. some private windows, the `?h=<hash>` in each URL still lets the normal browser cache work.)
4. **Engine gzipped.** `index.wasm.gz` (10.1 MB) is downloaded instead of `index.wasm` (39.5 MB) and unpacked in the browser (`DecompressionStream`, every current browser). It no longer depends on what the host compresses. Browsers without it, or a missing `.gz`, fall back to the plain file. The packs are not gzipped: their contents are compressed already (2.03 MB to 1.98 MB for the code pack).
5. **Docs left out** of the web build and of the Android app (7.4 MB smaller APK).
6. **A Holdfast loading screen** (`tools/web/shell.html`): the icon, HOLDFAST in Cinzel and a gold progress bar with the percentage, instead of Godot's splash.

## Before and after

| | before (0.14.32) | after (0.14.33) |
|---|---|---|
| first visit, before the menu | 145.5 MB (106 MB if the host gzips the `.wasm`) | **59.4 MB** (wasm.gz 10.1 + code 2.0 + art 47.1 + page 0.2) |
| music | in the first download (49 MB) | 0.1 to 1.5 MB per piece, when first played, then kept |
| next visit, nothing changed | revalidates or re-downloads from GitHub Pages (its cache lasts 10 minutes) | nothing downloaded (Cache Storage) |
| update that only changes code | 105.7 MB (the whole `index.pck`) | **about 2 MB** (`index.pck` + the page) |
| update that changes art or sounds | 105.7 MB | 47.1 MB (the art pack) + 2 MB |
| Godot upgrade | 39.5 + 105.7 MB | 10.1 + 2 MB |

Measured locally with the Godot 4.7 export templates; in a headless Chromium the menu came up and a skirmish ran with art and music, a second visit downloaded none of the big files, and a rebuild after a code change kept the same art pack hash. `tools/web/build_web.sh` prints the sizes; the CI job summary shows them too.

## How it is built

- `tools/web/build_web.sh` (CI runs it in `.github/workflows/web.yml`, then exports the Android app as before): exports "Web" and "Web assets", strips and hashes the art pack, copies the music, gzips the engine, and writes the file list (hashes, sizes, music URLs) into `index.html` in place of `/*HOLDFAST_FILES*/null`.
- To try it locally: `GODOT=/path/to/godot tools/web/build_web.sh`, then `python3 -m http.server -d build/web` and open http://localhost:8000. Cache Storage needs `localhost` or https.
- `python3 tools/web/pck_tool.py list build/web/assets.*.pck` shows what is in a pack by kind and folder.
- New top-level folders that the game needs go in `index.pck` by default. Anything under `assets/` goes in the art pack (except `assets/music`). Reference material belongs in `art/` or `docs/`, which no export includes.

## Hosting (GitHub Pages)

Nothing to change. GitHub Pages cannot be configured: it sends `Cache-Control: max-age=600` on every file and gzips only some types on the fly. That is why the page does its own caching (content hashes in Cache Storage) and its own gzip for the engine. One limit remains: for up to 10 minutes after a deploy a browser may still use the old `index.html` it fetched before. That was already true before 0.14.33, and the old page still finds its own files.

Possible next steps if needed: download the Portuguese and Spanish voices (5.5 MB) only for players using those languages; a smaller engine build (a custom template without 3D) would cut the 10 MB engine download, but it means building Godot ourselves.
