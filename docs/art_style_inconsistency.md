# Code-edited art that must be redrawn by ChatGPT for a uniform style (owner decision 2026-10-24)

The legs and tools below were rebuilt IN CODE (hard pixels, the unit's own palette) to give a real gait
or a different tool. They work, but their drawing style differs a little from the ChatGPT-drawn bodies
above them (leg shape and shading, boot shape, outline weight). When the art rework resumes, each entry
gets a ChatGPT redraw of the WHOLE strip (a full body, not just legs), then the code pass is retired
(the importer entry in tools/rebuild_art.sh is removed and the source sheet installed instead).
Source snapshots of the pristine strips are in `art/redraws/gait_src/`.

## A. Legs rebuilt in code (the gait passes)

| unit | strips / views | script (tools/) | notes |
| --- | --- | --- | --- |
| Labourer | walk, carry (gold sack), carry_keg: e, se, ne (west mirrored), 6 frames each | import_labourer_gait.py | stride built from contact / down / passing, near leg light, far leg dark |
| Labourer | walk: s and n (synthetic legs in n: the sheet drew the left boot raised in every frame), also the e/se/ne rebuild after the second ChatGPT round | import_labourer_v2.py (walk_frames) | runs LAST of the labourer passes |
| Missionary | walk, all five views | import_gait_missionary.py | robe-black wide trousers + boots under the hem |
| Windup Soldier (Clockwork) | walk, all five views | import_gait_windup_soldier.py | |
| Winder (Clockwork) | walk, all five views | import_gait_winder.py | |
| Armoured Musketeer (Guardsman) | walk, all five views | import_gait_musketeer_armoured.py | prompt 16 (guardsman_walk) also covers a redraw |
| Raptor (Brood) | walk: s, se, ne, n (walk_e kept: a real run already) | import_gait_raptor.py | stride is small in front/back views; prompt 18 |

Shared code: tools/gait_lib.py. Audit and ranking: docs/animation_gait_audit.md (tools/audit_walk_gait.py).

## B. Tools and poses drawn or composed in code (not legs)

| what | where | script | notes |
| --- | --- | --- | --- |
| Labourer farm hoe (the pickaxe replaced by a hoe, soil debris, weight shift) | mine_s/se/e/ne/n, 4 frames | import_labourer_hoe.py | the owner liked it; ChatGPT candidate labourer_hoe_v2.png exists (not installed) |
| Labourer shovel at the Powder Mill (3 loads x 4 frames) | shovel_s/se/e/ne/n | import_labourer_shovel.py | shovel and loads drawn on the hoe bodies |
| Labourer bury, north row (repaired in code: the sheet repeated the standing back view) | bury_n | import_labourer_v2.py (REPAIRS) | crouch + soil pile, no shovel |
| Labourer walk/idle/death repairs listed in docs/animation_audit_labourer.md | various | import_labourer_redraw.py / import_labourer_v2.py | |
| Officer and Armoured Officer idle / aim / fire / death (rotated standing body, pistol drawn in code) | branch wt-officer-pose, NOT merged yet | import_officer_poses.py | owner has not approved; prompts 10-13 exist |

## C. Still to prompt (new ids when the art rework resumes)

- Missionary walk (new prompt), Windup Soldier walk, Winder walk (new prompts; Armoured Musketeer = 16, Raptor = 18, Labourer walk/carry/keg = 07, 08, 09).
- For each, attach the CURRENT strip (the code-legged one) as the only 'what to keep: body, outfit, proportions' reference, and say: draw the whole figure including legs in one consistent style, with a real alternating gait.
