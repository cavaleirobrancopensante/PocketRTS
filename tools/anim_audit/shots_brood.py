"""Before / after pictures of the Brood animation audit's fixes (docs/shots/anim_audit_brood/fix_*.gif|png).
"Before" is read from git (BASE, default origin/main at the audit), "after" from the working tree.
Usage (repo root): python3 tools/anim_audit/shots_brood.py [BASE]
"""
import io
import os
import subprocess
import sys

import numpy as np
from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import measure_brood as m  # noqa: E402

ROOT = m.ROOT
OUT = m.OUT
BASE = sys.argv[1] if len(sys.argv) > 1 else "a9d1dac"


def old(rel):
    return np.array(Image.open(io.BytesIO(subprocess.check_output(["git", "show", "%s:%s" % (BASE, rel)], cwd=ROOT))).convert("RGBA"))


def new(rel):
    return np.array(Image.open(os.path.join(ROOT, rel)).convert("RGBA"))


def frames(a, n):
    w = a.shape[1] // n
    return [a[:, i * w:(i + 1) * w] for i in range(n)]


def place(canvas, f, x, y_feet, anchor, cell_h):
    """f drawn with its anchor at (x, y_feet), as the game does (taller strips move up by the extra rows)."""
    yoff = f.shape[0] - cell_h
    im = Image.fromarray(m.team(f))
    canvas.alpha_composite(im, (int(x - anchor[0]), int(y_feet - anchor[1] - yoff)))


def label(c, txt, x=4, y=4):
    ImageDraw.Draw(c).text((x, y), txt, fill=(255, 255, 210))


def save_gif(path, ims, ms):
    ims = [i.convert("RGB") for i in ims]
    ims[0].save(path, save_all=True, append_images=ims[1:], duration=ms, loop=0)


def scale(im, k):
    return im.resize((im.width * k, im.height * k), Image.NEAREST)


def turn_gif(kind, name):
    """walk_e, then walk_s, then idle_s, on one ground line: before (the hop up and down) | after."""
    u = m.art_data()[kind]
    cw, ch = u["cell"]
    seq = [("walk_e", i) for i in range(6)] + [("walk_s", i) for i in range(6)] + [("walk_se", i) for i in range(6)] + [("idle_s", 0)] * 3
    outs = []
    for key, i in seq:
        c = m.bg(2 * cw + 20, ch + 18)
        d = ImageDraw.Draw(c)
        gy = ch + 4
        for j, src in enumerate((old, new)):
            n = u["frames"][key]
            f = frames(src("assets/units/%s/%s.png" % (kind, key)), n)[i % n]
            x0 = 10 + j * cw
            d.line([(x0, gy), (x0 + cw - 4, gy)], fill=(90, 210, 230))
            place(c, f, x0 + cw / 2, gy, u["anchor"], ch)
        label(c, "before", 4, 2)
        label(c, "after", 14 + cw, 2)
        outs.append(scale(c, 3))
    save_gif(os.path.join(OUT, name), outs, 125)


def strip_pair(kind, key, n, name, k=4):
    """the whole strip, before over after."""
    a, b = old("assets/units/%s/%s.png" % (kind, key)), new("assets/units/%s/%s.png" % (kind, key))
    c = m.bg(a.shape[1] + 50, a.shape[0] * 2 + 6)
    c.alpha_composite(Image.fromarray(m.team(a)), (50, 0))
    c.alpha_composite(Image.fromarray(m.team(b)), (50, a.shape[0] + 6))
    label(c, "before", 2, 4)
    label(c, "after", 2, a.shape[0] + 10)
    scale(c, k).save(os.path.join(OUT, name))


def picture_pair(rels, name, k=4):
    ims = []
    for rel in rels:
        for src in (old, new):
            ims.append(Image.fromarray(m.team(src(rel))))
    w = sum(i.width for i in ims) + 10 * len(ims)
    h = max(i.height for i in ims) + 14
    c = m.bg(w, h)
    x = 0
    for j, i in enumerate(ims):
        c.alpha_composite(i, (x, 14))
        label(c, "before" if j % 2 == 0 else "after", x + 2, 1)
        x += i.width + 10
    scale(c, k).save(os.path.join(OUT, name))


def toad_death():
    """the Mist Toad's death as the game showed it (stopped on frame 11 when the body came to rest at 1.5 s) and now."""
    u = m.art_data()["mist_toad"]
    n = u["frames"]["death_e"]
    f = frames(new("assets/units/mist_toad/death_e.png"), n)
    outs = []
    for t in range(30):          # 15 Hz ticks over 2 s
        sec = t / 15.0
        i_new = min(int(sec * 7.0), n - 1)
        i_old = min(i_new, int(1.5 * 7.0))
        c = m.bg(2 * f[0].shape[1] + 10, f[0].shape[0] + 14)
        c.alpha_composite(Image.fromarray(m.team(f[i_old])), (0, 14))
        c.alpha_composite(Image.fromarray(m.team(f[i_new])), (f[0].shape[1] + 10, 14))
        label(c, "before: frame %d" % (i_old + 1), 2, 1)
        label(c, "after: frame %d" % (i_new + 1), f[0].shape[1] + 12, 1)
        outs.append(scale(c, 3))
    durs = [66] * len(outs)
    durs[-1] = 1500
    outs[0].save(os.path.join(OUT, "fix_mist_toad_death.gif"), save_all=True, append_images=[o.convert("RGB") for o in outs[1:]],
                 duration=durs, loop=0)


def rate_gif(kind, key, fps_old, fps_new, name, move=0.0):
    """the same strip at the old and the new frame rate (15 Hz ticks), side by side; `move` px/s walks it over
    the ground (marks every 16 px) so foot slide shows."""
    u = m.art_data()[kind]
    n = u["frames"][key]
    f = frames(new("assets/units/%s/%s.png" % (kind, key)), n)
    cw, ch = u["cell"]
    span = int(move * 2.0) + cw + 10
    outs = []
    for t in range(30):
        sec = t / 15.0
        c = m.bg(span, 2 * ch + 30)
        d = ImageDraw.Draw(c)
        for j, fps in enumerate((fps_old, fps_new)):
            gy = 14 + ch * (j + 1) + j * 14 - 2
            off = 0.0 if move == 0 else (move * sec) % 16
            for x in range(-16, span + 16, 16):
                d.line([(x - off + cw / 2 + move * sec, gy + 1), (x - off + cw / 2 + move * sec, gy + 3)], fill=(120, 150, 110))
            i = int(sec * fps) % n
            place(c, f[i], cw / 2 + 4 + move * sec, gy, u["anchor"], ch)
            label(c, "%.0f fps" % fps, 2, gy - ch - 10)
        outs.append(scale(c, 3))
    save_gif(os.path.join(OUT, name), outs, 66)


NAVY = (0, 22, 48, 255)
# the reference pictures the doc's redraw prompts attach: prompt id -> [(file, unit, [strips]) or (file, building png)]
REFS = {
    "B1_grub_carry": [("1_grub_walk_idle.png", "grub", ["walk_e", "walk_s", "walk_n", "idle_e"]),
                      ("2_current_carry_cocoon.png", "grub", ["carry_cocoon_e", "carry_cocoon_s", "carry_cocoon_n"]),
                      ("3_cocoon_and_wrap.png", "grub", ["wrap_e", "idle_cocoon_e"])],
    "B2_grub_wrap": [("1_grub_walk_idle.png", "grub", ["walk_e", "walk_se", "idle_e"]),
                     ("2_current_wrap.png", "grub", ["wrap_e", "wrap_s", "wrap_n"]),
                     ("3_grub_death_cocoon.png", "grub", ["death_cocoon_e"])],
    "B3_brute_walk": [("1_brute_walk_e.png", "brute", ["walk_e"]),
                      ("2_brute_idle_views.png", "brute", ["idle_s", "idle_se", "idle_n"]),
                      ("3_brute_charge_e.png", "brute", ["charge_e"])],
    "B4_brute_idle_attack": [("1_brute_idle_now.png", "brute", ["idle_e"]),
                             ("2_brute_attack_now.png", "brute", ["attack_e"]),
                             ("3_brute_walk_e.png", "brute", ["walk_e"])],
    "B5_spitter_walk": [("1_spitter_walk_e.png", "spitter", ["walk_e"]),
                        ("2_spitter_idle_views.png", "spitter", ["idle_s", "idle_se", "idle_n"]),
                        ("3_spitter_attack_e.png", "spitter", ["attack_e"])],
    "B6_mist_toad_walk": [("1_toad_walk_e.png", "mist_toad", ["walk_e"]),
                          ("2_toad_idle_views.png", "mist_toad", ["idle_s", "idle_se", "idle_n"]),
                          ("3_toad_idle_e.png", "mist_toad", ["idle_e"])],
    "B7_bloater_deflate": [("1_bloater_idle.png", "bloater", ["idle_e", "idle_s"]),
                           ("2_bloater_deflate_now.png", "bloater", ["deflate_e", "dwalk_e"]),
                           ("3_bloater_death.png", "bloater", ["death_e"])],
    "B8_skywing_hover_attack": [("1_skywing_flight.png", "skywing", ["walk_e", "walk_s", "idle_s"]),
                                ("2_skywing_attack.png", "skywing", ["attack_e", "attack_se"]),
                                ("3_skywing_land.png", "skywing", ["land_e"])],
    "B9_spore_mother_ne": [("1_spore_mother_e.png", "spore_mother", ["walk_e", "idle_e"]),
                           ("2_spore_mother_n.png", "spore_mother", ["walk_n", "idle_n"]),
                           ("3_spore_mother_se.png", "spore_mother", ["walk_se"])],
    "B10_queen_idle": [("1_queen.png", "assets/buildings/brood_queen.png"),
                       ("2_burrow_built.png", "assets/buildings/hive_built.png"),
                       ("3_grub_idle.png", "grub", ["idle_e", "walk_e"])],
    "B11_hatch": [("1_burrow_built.png", "assets/buildings/hive_built.png"),
                  ("2_raptor_grub.png", "raptor", ["idle_e", "walk_s"]),
                  ("3_grub_cocoon_death.png", "grub", ["death_cocoon_e"])],
    "B12_remains": [("1_deaths_now.png", "bloater", ["death_e"]),
                    ("2_spore_mother_death.png", "spore_mother", ["death_e"]),
                    ("3_spitter_death.png", "spitter", ["death_e"])],
}


def refs():
    u = m.art_data()
    for pid, items in REFS.items():
        d = os.path.join(OUT, "refs", pid)
        os.makedirs(d, exist_ok=True)
        for it in items:
            if len(it) == 2:
                a = new(it[1])
                rows = [[a]]
            else:
                rows = []
                for key in it[2]:
                    n = u[it[1]]["frames"][key]
                    rows.append(frames(new("assets/units/%s/%s.png" % (it[1], key)), n))
            cw = max(f.shape[1] for r in rows for f in r)
            ch = max(f.shape[0] for r in rows for f in r)
            W = max(len(r) for r in rows) * (cw + 6) + 6
            H = len(rows) * (ch + 6) + 6
            c = Image.new("RGBA", (W, H), NAVY)
            for j, r in enumerate(rows):
                for i, f in enumerate(r):
                    c.alpha_composite(Image.fromarray(f), (6 + i * (cw + 6), 6 + j * (ch + 6) + ch - f.shape[0]))
            scale(c, 4).save(os.path.join(d, it[0]))


def wrap_timing():
    """the grub wrapping a small body (0.8 s) and a big one (3 s): the frame on show every 0.2 s, before (always 1.2 s)
    and after (the strip spread over the real wrapping time); the last cell is the moment it walks off."""
    u = m.art_data()["grub"]
    f = frames(new("assets/units/grub/wrap_e.png"), 5)
    cw, chh = f[0].shape[1], f[0].shape[0]
    rows = []
    for T in (0.8, 3.0):
        for fps in (5.0 / 1.2, 5.0 / T):
            ts = [i * 0.2 for i in range(int(T / 0.2) + 1)]
            rows.append(("%.1f s body, %s" % (T, "before" if fps == 5.0 / 1.2 else "after"), [min(int(t * fps), 4) for t in ts]))
    W = 120 + max(len(r[1]) for r in rows) * (cw + 2)
    c = m.bg(W, len(rows) * (chh + 4))
    for j, (lab, idx) in enumerate(rows):
        label(c, lab, 2, j * (chh + 4) + 10)
        for i, k in enumerate(idx):
            c.alpha_composite(Image.fromarray(m.team(f[k])), (120 + i * (cw + 2), j * (chh + 4)))
    scale(c, 2).save(os.path.join(OUT, "fix_grub_wrap_timing.png"))


def main():
    turn_gif("raptor", "fix_raptor_turn_feet.gif")
    turn_gif("grub", "fix_grub_turn_feet.gif")
    strip_pair("skywing", "attack_e", 3, "fix_skywing_attack_e.png", 5)
    picture_pair(["assets/buildings/brood_queen.png", "assets/buildings/clutch_mound_built.png"], "fix_queen_clutch_team.png", 4)
    strip_pair("brute", "charge_e", 5, "fix_brute_charge_keyreds.png", 3)
    toad_death()
    rate_gif("skywing", "idle_s", 2.0, 6.0, "fix_skywing_hover_fps.gif")
    rate_gif("raptor", "walk_e", 8.0, 12.0, "fix_raptor_walk_fps.gif", move=108.0)
    wrap_timing()
    refs()


if __name__ == "__main__":
    main()
