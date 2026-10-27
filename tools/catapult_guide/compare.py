"""Old vs new GIFs for a code animation's sheets (5 direction rows): each GIF frame shows the old sheet's frame for
the 5 directions on top and the new one under it, at 2x, bottom-aligned on the anchor line, animations one after
the other.
  python3 tools/catapult_guide/compare.py OUT.gif K "label" OLD.png:CW:CH NEW.png:CW:CH:AX:AY:OAX:OAY [ms] [more pairs ...]
(see the bottom of the file: the two calls used for art/redraws/catapult_parts_compare.gif and
great_winder_parts_compare.gif; 'facing' for catapult_facing_compare.gif)"""
import sys
from PIL import Image, ImageDraw

NAVY = (0, 22, 48)


def frames(path, cw, ch):
    im = Image.open(path).convert('RGB')
    n = im.width // cw
    return [[im.crop((c * cw, r * ch, (c + 1) * cw, (r + 1) * ch)) for r in range(5)] for c in range(n)]


def compare(out, pairs, k=2, label=('old', 'new')):
    """pairs: [(old (path, cw, ch, ax, ay), new (path, cw, ch, ax, ay), ms)]: old and new cells drawn with their
    anchors (ax, ay) on one point, so the change of size shows"""
    CW = max(max(o[1], n[1]) for o, n, _ in pairs)
    CH = max(max(o[2], n[2]) for o, n, _ in pairs)
    AX = max(max(o[3], n[3]) for o, n, _ in pairs)
    AY = max(max(o[4], n[4]) for o, n, _ in pairs)
    W, H = 5 * CW, 2 * CH + 14
    gif, dur = [], []
    for o, n, ms in pairs:
        fo, fn = frames(*o[:3]), frames(*n[:3])
        for i in range(max(len(fo), len(fn))):
            cv = Image.new('RGB', (W, H), NAVY)
            for row, (fr, spec) in enumerate(((fo, o), (fn, n))):
                f = fr[i % len(fr)]
                for d in range(5):
                    cv.paste(f[d], (d * CW + AX - spec[3], row * (CH + 14) + 14 * (1 - row) + AY - spec[4]))
            dr = ImageDraw.Draw(cv)
            dr.text((3, 1), label[0], fill=(200, 200, 200))
            dr.text((3, CH + 15), label[1], fill=(255, 220, 90))
            gif.append(cv.resize((W * k, H * k), Image.NEAREST))
            dur.append(ms[i % len(ms)] if isinstance(ms, list) else ms)
    gif[0].save(out, save_all=True, append_images=gif[1:], duration=dur, loop=0)


if __name__ == '__main__':
    import json
    which = sys.argv[1]
    old = sys.argv[2]          # a folder with the old sheets (e.g. from git show)
    if which == 'catapult':
        sys.path.insert(0, 'tools/catapult_guide')
        cell = json.load(open('art/redraws/catapult_cup.json'))['cell']
        THROW_MS = [300, 160, 60, 50, 50, 70, 90, 110, 110, 110, 130, 260]
        compare('art/redraws/catapult_parts_compare.gif', [
            ((old + '/catapult_throw.png', 112, 106, 56, 104), ('art/redraws/catapult_throw.png',) + tuple(cell), THROW_MS),
            ((old + '/catapult_move.png', 112, 106, 56, 104), ('art/redraws/catapult_move.png',) + tuple(cell), 110),
            ((old + '/catapult_move.png', 112, 106, 56, 104), ('art/redraws/catapult_move.png',) + tuple(cell), 110)],
            label=('old (0.26)', 'new: painted cog wheels, S/N arm poses, 1.5x the Netter, smaller payload'))
    elif which == 'facing':
        # (art/redraws/catapult_facing_compare.gif: the cw-anim-parts sheets (cell 154x141, anchor 77,139) against the
        # facing fixes)
        cell = json.load(open('art/redraws/catapult_cup.json'))['cell']
        THROW_MS = [300, 160, 60, 50, 50, 70, 90, 110, 110, 110, 130, 260]
        compare('art/redraws/catapult_facing_compare.gif', [
            ((old + '/catapult_throw.png', 154, 141, 77, 139), ('art/redraws/catapult_throw.png',) + tuple(cell), THROW_MS),
            ((old + '/catapult_move.png', 154, 141, 77, 139), ('art/redraws/catapult_move.png',) + tuple(cell), 110),
            ((old + '/catapult_move.png', 154, 141, 77, 139), ('art/redraws/catapult_move.png',) + tuple(cell), 110)],
            label=('old', 'new: S wheels edge-on, SE wheels squashed, N/NE cup shows its back past vertical'))
    elif which == 'legs':
        # python3 tools/catapult_guide/compare.py legs OLD_DIR  (OLD_DIR: the strips before great-winder-legs: walk
        # on 194x95, anchor (97, 84); wind and sweep on 204x107, anchor (102, 89))
        cell_n = [int(v) for v in sys.argv[3].split(',')] if len(sys.argv) > 3 else [182, 107, 91, 104]
        compare('art/redraws/great_winder_legs_compare.gif', [
            ((old + '/great_winder_walk.png', 194, 95, 97, 84), ('art/redraws/great_winder_walk.png',) + tuple(cell_n), 130),
            ((old + '/great_winder_wind.png', 204, 107, 102, 89), ('art/redraws/great_winder_wind.png',) + tuple(cell_n), 110),
            ((old + '/great_winder_sweep.png', 204, 107, 102, 89), ('art/redraws/great_winder_sweep.png',) + tuple(cell_n), 100)],
            label=('old', 'new: ChatGPT painted legs, 4 legs, body raised'))
    else:
        cell_o = [int(v) for v in sys.argv[3].split(',')]
        cell_n = [int(v) for v in sys.argv[4].split(',')]
        compare('art/redraws/great_winder_parts_compare.gif', [
            ((old + '/great_winder_wind.png',) + tuple(cell_o), ('art/redraws/great_winder_wind.png',) + tuple(cell_n), 110),
            ((old + '/great_winder_sweep.png',) + tuple(cell_o), ('art/redraws/great_winder_sweep.png',) + tuple(cell_n), 100),
            ((old + '/great_winder_sweep.png',) + tuple(cell_o), ('art/redraws/great_winder_sweep.png',) + tuple(cell_n), 100)],
            label=('old', 'new: painted key turn and coarse brush rollers'))
