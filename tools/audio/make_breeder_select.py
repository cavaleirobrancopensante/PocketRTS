"""The Horse Breeder's select sound (the owner, 2026-10-27: "the sound of hooves + horses"):
a short run of hooves from the user's gallop recording with a horse neighing over it, three
takes (select/horse_breeder.wav, _1, _2: the game picks one at random). From the user's
recordings in art/audio_src/city/, like make_market_horse.py (whose recruit sound is the long
gallop + neigh1; these use the other neighs, so picking the Breeder and getting a horse sound
different). Run: python3 tools/audio/make_breeder_select.py, then add the files' levels to
scripts/sound_mix.gd (tools/audio/make_mix.py, or the same sum by hand)."""
import os
import numpy as np
from make_market_horse import rd, fade, save, SR, A

# (gallop start s, length s, neigh file, neigh starts at s, neigh length s (None: all), neigh fade-out s)
TAKES = [(1.0, 1.5, "neigh2.mp3", 0.55, None, 0.25),
         (3.3, 1.5, "neigh3.mp3", 0.50, None, 0.30),
         (5.6, 1.5, "neigh4.mp3", 0.45, 1.25, 0.35)]
HOOVES = 1.4       # the hooves against the neigh at 1.0 (both levelled to their peaks first): hoof
                   # beats are short clicks, so they need the higher peak to sound as loud


def level(x):
    return x / (np.abs(x).max() + 1e-9)


def main():
    out = os.path.join(A, "audio", "select")
    for i, (g0, gl, nf, at, nl, nfade) in enumerate(TAKES):
        g = level(fade(rd("6dff7504-galop.mp3", g0, gl), 0.04, 0.6))
        n = level(fade(rd(nf, 0.0, nl), 0.01, nfade))
        o = np.zeros(max(len(g), int(at * SR) + len(n)) + int(0.05 * SR))
        o[:len(g)] += g * HOOVES
        o[int(at * SR): int(at * SR) + len(n)] += n
        name = "horse_breeder.wav" if i == 0 else "horse_breeder_%d.wav" % i
        save(os.path.join(out, name), o)
        print(name, "%.2f s" % (len(o) / SR))


if __name__ == "__main__":
    main()
