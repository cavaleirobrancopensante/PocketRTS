# Localisation (English, Brazilian Portuguese, Spanish)

The game text is written in English in the code. **The English string is the key**: `Loc.t("Some text")`
(scripts/loc.gd) returns it in the chosen language, or the English itself when there is no entry.
Godot's own controls (Label, Button, tooltips) translate by themselves through `LocTranslation`
(scripts/loc_translation.gd, registered with the TranslationServer), so most text needs no edit at all.
Text drawn by hand with `draw_string` must be wrapped: `draw_string(font, pos, Loc.t(text), ...)`.

## Where the translations live

- Authoring: `tools/i18n/*.txt`. One block per entry, blank line between blocks:

      > English text (\n for a line break)
      pt Texto em português
      es Texto en español

  Files: 01 menus, 02 HUD and game, 03 Defs (names, descriptions, research, factions), 04 misc, 05 help pages.
- Build: `python3 tools/i18n_build.py` writes `scripts/lang/lang_pt.gd` and `lang_es.gd` (generated, do not
  edit) and checks that `%s %d %f` placeholders match in all three languages. It also makes an UPPER-case twin
  of every short key, so names shown with `to_upper()` still translate.
- Patch notes: `tools/i18n/patch/notes.txt` (`version#item ;; pt ;; es`, items numbered in the order of
  `scripts/patch_notes.gd`), built by `python3 tools/i18n_patch_build.py` into `scripts/lang/patch_pt.gd` /
  `patch_es.gd`. English stays authoritative; a missing translation shows the English item.
- Voices: `assets/voice_pt/` and `assets/voice_es/` (Ogg Vorbis), made by
  `KOKORO_DIR=<models> python3 tools/audio/make_voices.py --lang pt|es` from the lines in
  `tools/audio/voice_lines.py`. `Sfx._find` looks in `assets/voice_<lang>/` first and falls back to the
  English `assets/voice/`, so a missing line plays in English. Creature calls and music are not spoken
  language and are shared.

## Patterns

A key with `%s`, `%d` or `%f` is also a pattern: the finished English text "Not enough gold." matches the
key "Not enough %s." and the captured piece is translated again if it has an entry. Long texts without a
direct entry are split on newlines and on " · ", "  ", ": " and " + " and translated piece by piece.

## Checks

- `godot --headless --script res://tools/test_i18n.gd`: both tables have the same keys, placeholders match,
  every Defs name / description, help paragraph and map description has a translation, and switching the
  language changes text (also through a Label).
- `tools/i18n_scan.py --missing` lists string literals in the scripts that look like player text but have
  no entry; `tools/i18n_dump.gd` prints the texts kept in data tables.
- `tools/shot_i18n.gd -- <outdir> <en|pt|es> [pc|mobile]` takes screenshots of the menus in a language, to
  look for text that no longer fits.

## Adding a language

1. `scripts/loc.gd`: add the code to `LANGS`, `LOCALE` (e.g. `"fr": "fr_FR"`) and `NATIVE` (its own name),
   and a `match` case in `table()` for its table class.
2. `tools/i18n_build.py`: add it to `LANGS` and give every block in `tools/i18n/*.txt` a `fr ...` line
   (the build lists what is missing). Do the same in `tools/i18n_patch_build.py` and the patch notes.
3. `scripts/loc_translation.gd` / `Loc.set_lang`: register a `LocTranslation` for the new locale.
4. `scripts/ui/flags.gd`: draw a flag (code-drawn; note it in docs/art_style_inconsistency.md) and add it to
   the flag rows in `scripts/main.gd` (`_flag_row`, `_corner_flags`).
5. Voices: add the language's Kokoro voices to `make_voices.py` and its lines to `voice_lines.py`.
6. Run `tools/test_i18n.gd`, take screenshots with `tools/shot_i18n.gd`, fix text that does not fit.

## Not translated on purpose

Match logs and AI/scout log text (developer tools), map names, music titles (proper names), the
developer-only screens. Translations were written by the AI and have not been reviewed by a native
speaker: expect small wording corrections.
