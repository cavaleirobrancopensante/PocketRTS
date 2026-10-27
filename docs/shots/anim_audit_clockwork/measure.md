# Clockwork animation measurements

Made by tools/anim_audit/measure_clockwork.py. Frames are 1-based.

## winder
cell [76, 49], anchor [38.0, 43.0]
walk: {'speed': 74.0, 'frames': 4, 'fps': 8.0, 'cycle_s': 0.5, 'ground_per_cycle': 37.0, 'foot_spread_range': 8, 'slide_k': 2.31}
attack: {'attack': {'frames': 4, 'fps': 9.0, 'hit_frame': 3, 'strip_s': 0.44, 'aim': 0.25}}
- attack_e (4): height pops 6 px between frames
- attack_n (4): height pops 12 px between frames
- attack_ne (4): height pops 9 px between frames
- attack_s (4): height pops 10 px between frames
- attack_se (4): height pops 6 px between frames
- death_e (6): 1 stray specks
- death_n (6): 1 stray specks
- death_ne (6): 2 stray specks
- death_s (6): 1 stray specks
- death_se (6): 2 stray specks

## clock_soldier
cell [78, 66], anchor [39.0, 56.0]
walk: {'speed': 68.0, 'frames': 6, 'fps': 10.0, 'cycle_s': 0.6, 'ground_per_cycle': 40.8, 'foot_spread_range': 1, 'slide_k': 20.4}
attack: {'attack': {'frames': 6, 'fps': 9.0, 'hit_frame': 3, 'strip_s': 0.67, 'aim': 0.33}}
- s: switching idle/walk/attack/guard pops (heights [42, 43, 38, 42], foot lines [55, 55, 55, 55], centre x [38, 38, 39, 36])
- n: switching idle/walk/attack/guard pops (heights [42, 45, 38, 43], foot lines [55, 55, 55, 55], centre x [38, 38, 38, 40])
- attack_e (6): height pops 10 px between frames
- attack_n (6): height pops 10 px between frames
- attack_ne (6): height pops 12 px between frames
- attack_nw (6): height pops 10 px between frames
- attack_s (6): foot line moves 4 px; height pops 9 px between frames
- attack_se (6): height pops 7 px between frames
- attack_sw (6): height pops 10 px between frames
- attack_w (6): height pops 15 px between frames
- death_ne (7): 1 stray specks
- idle_ne (4): loop seam 2.3x the mean frame change

## jack
cell [108, 80], anchor [54.0, 69.0]
walk: {'speed': 70.0, 'frames': 6, 'fps': 9.0, 'cycle_s': 0.67, 'ground_per_cycle': 46.7, 'foot_spread_range': 3, 'slide_k': 7.78}
attack: {'attack_r': {'frames': 6, 'fps': 9.0, 'hit_frame': 1, 'strip_s': 0.67, 'aim': 0.11}, 'attack_up': {'frames': 6, 'fps': 9.0, 'hit_frame': 1, 'strip_s': 0.67, 'aim': 0.11}}
- idle height differs by view: {'s': 59, 'se': 54, 'e': 56, 'ne': 53, 'n': 49}
- attack_l_e (6): duplicate frames ['6=1']
- attack_l_n (6): duplicate frames ['6=1']
- attack_l_ne (6): duplicate frames ['6=1']
- attack_l_s (6): duplicate frames ['6=1']
- attack_l_se (6): duplicate frames ['6=1']
- attack_r_e (6): duplicate frames ['6=1']
- attack_r_n (6): duplicate frames ['6=1']
- attack_r_ne (6): duplicate frames ['6=1']
- attack_r_s (6): duplicate frames ['6=1']
- attack_r_se (6): duplicate frames ['6=1']
- attack_up_e (6): duplicate frames ['5=1', '6=1']
- attack_up_n (6): duplicate frames ['5=1', '6=1']
- attack_up_ne (6): duplicate frames ['5=1', '6=1']
- attack_up_s (6): duplicate frames ['5=1', '6=1']
- attack_up_se (6): duplicate frames ['3=2', '4=1', '5=1', '6=1']
- idle_s (4): centre jumps 5.0 px between frames; body (team colour) jumps 7.5 px between frames; height pops 8 px between frames
- idle_se (4): body (team colour) jumps 4.0 px between frames
- walk_e (6): height pops 7 px between frames
- walk_n (6): height pops 7 px between frames
- walk_ne (6): height pops 8 px between frames
- walk_s (6): height pops 10 px between frames
- walk_se (6): height pops 8 px between frames

## cuckoo
cell [74, 55], anchor [37.0, 44.0]
attack: {'attack': {'frames': 6, 'fps': 9.0, 'hit_frame': 3, 'strip_s': 0.67, 'aim': 0.25}}
- s: switching idle/walk/attack pops (heights [37, 37, 26], foot lines [43, 43, 42], centre x [36, 36, 36])
- se: switching idle/walk/attack pops (heights [37, 37, 26], foot lines [43, 43, 43], centre x [37, 37, 40])
- e: switching idle/walk/attack pops (heights [34, 34, 26], foot lines [43, 43, 43], centre x [31, 31, 30])
- ne: switching idle/walk/attack pops (heights [34, 34, 28], foot lines [43, 43, 44], centre x [33, 33, 35])
- n: switching idle/walk/attack pops (heights [37, 37, 30], foot lines [42, 42, 44], centre x [33, 33, 33])
- attack_e (6): height pops 12 px between frames
- attack_ne (6): height pops 7 px between frames
- attack_s (6): height pops 11 px between frames
- attack_se (6): height pops 9 px between frames
- death_n (6): 3 stray specks
- death_ne (6): 1 stray specks
- death_s (6): 3 stray specks
- death_se (6): 4 stray specks
- idle_e (4): height pops 7 px between frames
- idle_n (4): centre jumps 4.8 px between frames; height pops 8 px between frames
- idle_ne (4): centre jumps 5.1 px between frames; height pops 7 px between frames
- idle_s (4): centre jumps 4.5 px between frames; height pops 9 px between frames
- idle_se (4): centre jumps 4.2 px between frames; height pops 11 px between frames
- walk_e (4): height pops 7 px between frames
- walk_n (4): height pops 8 px between frames
- walk_ne (4): height pops 7 px between frames
- walk_s (4): height pops 9 px between frames
- walk_se (4): height pops 11 px between frames

## ticking_owl
cell [94, 81], anchor [47.0, 69.0]
attack: {'attack': {'frames': 6, 'fps': 9.0, 'hit_frame': 3, 'strip_s': 0.67, 'aim': 0.25}}
- s: switching idle/walk/attack pops (heights [54, 54, 46], foot lines [68, 68, 66], centre x [43, 43, 43])
- se: switching idle/walk/attack pops (heights [50, 50, 46], foot lines [68, 68, 70], centre x [41, 41, 46])
- e: switching idle/walk/attack pops (heights [48, 48, 45], foot lines [68, 68, 68], centre x [39, 39, 35])
- ne: switching idle/walk/attack pops (heights [49, 49, 44], foot lines [68, 68, 69], centre x [42, 42, 46])
- n: switching idle/walk/attack pops (heights [55, 55, 47], foot lines [68, 68, 68], centre x [45, 45, 46])
- idle height differs by view: {'s': 54, 'se': 50, 'e': 48, 'ne': 49, 'n': 55}
- attack_e (6): duplicate frames ['6=1']; height pops 12 px between frames
- attack_n (6): duplicate frames ['6=1']; height pops 6 px between frames
- attack_ne (6): duplicate frames ['6=1']; height pops 8 px between frames
- attack_s (6): duplicate frames ['6=1']; height pops 9 px between frames
- attack_se (6): duplicate frames ['6=1']; height pops 10 px between frames
- bomb_e (6): duplicate frames ['6=1']
- bomb_n (6): duplicate frames ['6=1']
- bomb_ne (6): duplicate frames ['6=1']
- bomb_s (6): duplicate frames ['6=1']
- bomb_se (6): duplicate frames ['6=1']
- death_e (6): 1 stray specks
- death_n (6): 9 stray specks
- death_ne (6): 4 stray specks
- death_s (6): 2 stray specks
- death_se (6): 4 stray specks
- idle_e (4): centre jumps 4.2 px between frames
- idle_n (4): centre jumps 5.1 px between frames; height pops 7 px between frames
- idle_ne (4): centre jumps 6.5 px between frames; height pops 5 px between frames
- idle_s (4): height pops 7 px between frames
- idle_se (4): centre jumps 5.0 px between frames
- walk_n (4): height pops 7 px between frames
- walk_ne (4): height pops 5 px between frames
- walk_s (4): height pops 7 px between frames

## pendulum
cell [130, 91], anchor [65.0, 84.0]
walk: {'speed': 46.0, 'frames': 8, 'fps': 7.2, 'cycle_s': 1.11, 'ground_per_cycle': 51.1, 'foot_spread_range': 16, 'slide_k': 1.6}
attack: {'attack_r': {'frames': 6, 'fps': 9.0, 'hit_frame': 4, 'strip_s': 0.67, 'aim': 0.35}}
- attack_l_e (6): height pops 5 px between frames
- attack_l_n (6): height pops 5 px between frames
- attack_l_s (6): height pops 6 px between frames
- attack_l_se (6): height pops 5 px between frames
- attack_r_e (6): height pops 5 px between frames
- attack_r_n (6): height pops 5 px between frames
- attack_r_s (6): height pops 6 px between frames
- attack_r_se (6): height pops 5 px between frames
- death_e (6): 4 stray specks
- death_n (6): 8 stray specks
- death_ne (6): 4 stray specks
- death_s (6): 2 stray specks
- death_se (6): 10 stray specks
- idle_e (4): duplicate frames ['3=1']
- idle_n (4): duplicate frames ['3=1']
- idle_ne (4): duplicate frames ['3=1']
- idle_se (4): duplicate frames ['3=1']

## netter
cell [84, 58], anchor [42.0, 54.0]
walk: {'speed': 54.0, 'frames': 8, 'fps': 14.0, 'cycle_s': 0.57, 'ground_per_cycle': 30.9, 'foot_spread_range': 8, 'slide_k': 1.93}
attack: {'attack': {'frames': 6, 'fps': 9.0, 'hit_frame': 1, 'strip_s': 0.67, 'aim': 0.11}}
- idle height differs by view: {'s': 45, 'se': 40, 'e': 37, 'ne': 45, 'n': 43}
- attack_e (6): duplicate frames ['6=1']
- attack_n (6): duplicate frames ['6=1']
- attack_ne (6): duplicate frames ['6=1']
- attack_s (6): duplicate frames ['6=1']
- attack_se (6): duplicate frames ['6=1']
- death_s (5): 2 stray specks
- death_se (5): 1 stray specks

## gearknight (old roster, retired in gear mode)
cell [94, 67], anchor [47.0, 65.0]
attack: {'attack': {'frames': 8, 'fps': 9.0, 'hit_frame': 3, 'strip_s': 0.89, 'aim': 0.25}}
- e: switching walk/attack pops (heights [50, 65], foot lines [65, 65], centre x [47, 53])
- attack_e (8): height pops 13 px between frames

## bolt (old roster, retired in gear mode)
cell [118, 45], anchor [59.0, 43.0]
attack: {'attack': {'frames': 4, 'fps': 9.0, 'hit_frame': 3, 'strip_s': 0.44, 'aim': 0.25}}
- e: switching walk/attack pops (heights [39, 42], foot lines [43, 43], centre x [58, 70])

## steam_walker (old roster, retired in gear mode)
cell [228, 110], anchor [114.0, 108.0]
walk: {'speed': 44.0, 'frames': 6, 'fps': 8.0, 'cycle_s': 0.75, 'ground_per_cycle': 33.0, 'foot_spread_range': 41, 'slide_k': 0.4}
attack: {'attack': {'frames': 5, 'fps': 9.0, 'hit_frame': 3, 'strip_s': 0.56, 'aim': 0.3}}
- e: switching idle/walk/attack pops (heights [94, 99, 82], foot lines [108, 108, 108], centre x [112, 124, 128])
- attack_e (5): height pops 6 px between frames
- walk_e (6): height pops 18 px between frames

## stormcaller (old roster, retired in gear mode)
cell [66, 72], anchor [33.0, 69.0]
walk: {'speed': 56.0, 'frames': 5, 'fps': 8.0, 'cycle_s': 0.62, 'ground_per_cycle': 35.0, 'foot_spread_range': 5, 'slide_k': 3.5}
attack: {'attack': {'frames': 3, 'fps': 9.0, 'hit_frame': 3, 'strip_s': 0.33, 'aim': 0.25}}
- attack_e (3): half-transparent fringe 13% of the body
- attack_n (3): half-transparent fringe 14% of the body
- attack_ne (3): half-transparent fringe 14% of the body
- attack_s (3): half-transparent fringe 9% of the body
- attack_se (3): half-transparent fringe 14% of the body
- cast_e (4): duplicate frames ['4=2']; height pops 16 px between frames; half-transparent fringe 16% of the body
- cast_n (4): height pops 14 px between frames; half-transparent fringe 23% of the body
- cast_ne (4): height pops 14 px between frames; half-transparent fringe 23% of the body
- cast_s (4): height pops 16 px between frames; half-transparent fringe 19% of the body
- cast_se (4): height pops 12 px between frames; half-transparent fringe 20% of the body
- death_n (3): half-transparent fringe 7% of the body
- death_ne (3): half-transparent fringe 7% of the body
- death_se (3): 3 stray specks; half-transparent fringe 7% of the body
- idle_s (3): feet slide 3 px sideways

## tesla_cart (old roster, retired in gear mode)
cell [70, 59], anchor [35.0, 53.0]
walk: {'speed': 50.0, 'frames': 8, 'fps': 8.0, 'cycle_s': 1.0, 'ground_per_cycle': 50.0, 'foot_spread_range': 42, 'slide_k': 0.6}
attack: {'attack': {'frames': 5, 'fps': 9.0, 'hit_frame': 2, 'strip_s': 0.56, 'aim': 0.2}}
- s: switching idle/walk/attack pops (heights [49, 48, 56], foot lines [52, 52, 52], centre x [35, 36, 34])
- se: switching idle/walk/attack pops (heights [47, 51, 54], foot lines [52, 52, 52], centre x [36, 35, 34])
- e: switching idle/walk/attack pops (heights [45, 48, 69], foot lines [52, 52, 52], centre x [34, 35, 40])
- ne: switching idle/walk/attack pops (heights [48, 50, 72], foot lines [52, 52, 52], centre x [35, 37, 41])
- n: switching idle/walk/attack pops (heights [52, 52, 74], foot lines [52, 52, 52], centre x [36, 37, 34])
- idle height differs by view: {'s': 49, 'se': 47, 'e': 45, 'ne': 48, 'n': 52}
- attack_e (5): strip width 351 is not a whole number of 70 px cells; art_data says 3 frames, the file has 5; foot line moves 4 px; height pops 20 px between frames; 1 stray specks; half-transparent fringe 8% of the body; feet -3 px from the anchor
- attack_n (5): strip width 351 is not a whole number of 70 px cells; art_data says 3 frames, the file has 5; height pops 81 px between frames; 1 stray specks; team colour missing in frames [2]
- attack_ne (5): strip width 351 is not a whole number of 70 px cells; art_data says 3 frames, the file has 5; foot line moves 8 px; height pops 26 px between frames; half-transparent fringe 12% of the body; feet -3 px from the anchor; team colour missing in frames [2]
- attack_s (6): strip width 468 is not a whole number of 70 px cells; art_data says 4 frames, the file has 6; height pops 17 px between frames; half-transparent fringe 7% of the body
- attack_se (6): strip width 468 is not a whole number of 70 px cells; art_data says 4 frames, the file has 6; height pops 18 px between frames; team colour missing in frames [2]
- death_e (6): strip width 468 is not a whole number of 70 px cells; art_data says 4 frames, the file has 6; 3 stray specks; team colour missing in frames [2, 5]
- death_n (6): strip width 468 is not a whole number of 70 px cells; art_data says 4 frames, the file has 6; 1 stray specks; team colour missing in frames [2]
- death_ne (6): strip width 468 is not a whole number of 70 px cells; art_data says 4 frames, the file has 6; 3 stray specks; team colour missing in frames [2, 5]
- death_s (6): strip width 468 is not a whole number of 70 px cells; art_data says 4 frames, the file has 6; team colour missing in frames [2]
- death_se (6): strip width 468 is not a whole number of 70 px cells; art_data says 4 frames, the file has 6; 4 stray specks; team colour missing in frames [2, 5]
- deploy_e (6): strip width 468 is not a whole number of 70 px cells; art_data says 4 frames, the file has 6; foot line moves 10 px; height pops 39 px between frames; 2 stray specks; team colour missing in frames [2]
- deploy_n (8): strip width 585 is not a whole number of 70 px cells; art_data says 5 frames, the file has 8; empty frames [2]; foot line moves 11 px; height pops 65 px between frames; team colour missing in frames [6]
- deploy_ne (6): strip width 468 is not a whole number of 70 px cells; art_data says 4 frames, the file has 6; foot line moves 17 px; height pops 51 px between frames; team colour missing in frames [2]
- deploy_s (8): strip width 585 is not a whole number of 70 px cells; art_data says 5 frames, the file has 8; foot line moves 6 px; height pops 69 px between frames; team colour missing in frames [2, 7]
- deploy_se (8): strip width 585 is not a whole number of 70 px cells; art_data says 5 frames, the file has 8; empty frames [2]; foot line moves 11 px; height pops 64 px between frames; team colour missing in frames [6]
- deployed_e (6): strip width 468 is not a whole number of 70 px cells; art_data says 4 frames, the file has 6; height pops 30 px between frames; 1 stray specks; team colour missing in frames [2]
- deployed_n (6): strip width 468 is not a whole number of 70 px cells; art_data says 4 frames, the file has 6; height pops 36 px between frames
- deployed_ne (6): strip width 468 is not a whole number of 70 px cells; art_data says 4 frames, the file has 6; height pops 38 px between frames
- deployed_s (6): strip width 468 is not a whole number of 70 px cells; art_data says 4 frames, the file has 6; height pops 35 px between frames; team colour missing in frames [2]
- deployed_se (6): strip width 468 is not a whole number of 70 px cells; art_data says 4 frames, the file has 6; height pops 35 px between frames
- idle_e (5): strip width 351 is not a whole number of 70 px cells; art_data says 3 frames, the file has 5; feet slide 64 px sideways; centre jumps 54.4 px between frames; body (team colour) jumps 44.0 px between frames; height pops 9 px between frames
- idle_n (5): strip width 351 is not a whole number of 70 px cells; art_data says 3 frames, the file has 5; feet slide 66 px sideways; centre jumps 55.6 px between frames; body (team colour) jumps 57.6 px between frames; height pops 21 px between frames; 1 stray specks
- idle_ne (5): strip width 351 is not a whole number of 70 px cells; art_data says 3 frames, the file has 5; feet slide 64 px sideways; centre jumps 55.0 px between frames; body (team colour) jumps 58.7 px between frames; height pops 18 px between frames; 1 stray specks; team colour missing in frames [2]
- idle_s (5): strip width 351 is not a whole number of 70 px cells; art_data says 3 frames, the file has 5; feet slide 67 px sideways; centre jumps 56.3 px between frames; body (team colour) jumps 57.9 px between frames; height pops 18 px between frames; team colour missing in frames [2]
- idle_se (5): strip width 351 is not a whole number of 70 px cells; art_data says 3 frames, the file has 5; feet slide 66 px sideways; centre jumps 55.6 px between frames; body (team colour) jumps 58.3 px between frames; height pops 16 px between frames
- walk_e (8): strip width 585 is not a whole number of 70 px cells; art_data says 5 frames, the file has 8; height pops 8 px between frames; 2 stray specks
- walk_n (10): strip width 702 is not a whole number of 70 px cells; art_data says 6 frames, the file has 10; height pops 43 px between frames; 2 stray specks; team colour missing in frames [2, 7]
- walk_ne (8): strip width 585 is not a whole number of 70 px cells; art_data says 5 frames, the file has 8; height pops 12 px between frames; team colour missing in frames [2]
- walk_s (10): strip width 702 is not a whole number of 70 px cells; art_data says 6 frames, the file has 10; height pops 17 px between frames; 4 stray specks; team colour missing in frames [2, 7]
- walk_se (10): strip width 702 is not a whole number of 70 px cells; art_data says 6 frames, the file has 10; height pops 19 px between frames; 1 stray specks; team colour missing in frames [2, 7]

## ornithopter (old roster, retired in gear mode)
cell [48, 50], anchor [24.0, 35.0]
attack: {'attack': {'frames': 4, 'fps': 9.0, 'hit_frame': 2, 'strip_s': 0.44, 'aim': 0.2}}
- s: switching idle/walk/attack pops (heights [26, 32, 34], foot lines [35, 40, 38], centre x [23, 24, 23])
- ne: switching idle/walk/attack pops (heights [27, 28, 31], foot lines [34, 34, 37], centre x [23, 23, 24])
- attack_e (4): height pops 5 px between frames; half-transparent fringe 14% of the body
- attack_n (4): duplicate frames ['4=2']; half-transparent fringe 12% of the body
- attack_ne (4): duplicate frames ['4=2']; half-transparent fringe 11% of the body
- attack_s (4): half-transparent fringe 13% of the body
- attack_se (4): half-transparent fringe 16% of the body
- death_e (5): 2 stray specks
- death_n (5): 2 stray specks
- death_ne (5): 3 stray specks
- death_s (5): 1 stray specks
- death_se (5): 4 stray specks
- idle_n (4): body (team colour) jumps 3.0 px between frames
- idle_ne (4): body (team colour) jumps 3.2 px between frames
- idle_se (4): body (team colour) jumps 5.0 px between frames
- walk_s (7): loop seam 2.6x the mean frame change
- walk_se (7): 1 stray specks

## arc_thrower (old roster, retired in gear mode)
cell [66, 54], anchor [33.0, 51.0]
walk: {'speed': 54.0, 'frames': 6, 'fps': 10.0, 'cycle_s': 0.6, 'ground_per_cycle': 32.4, 'foot_spread_range': 4, 'slide_k': 4.05}
attack: {'attack': {'frames': 5, 'fps': 9.0, 'hit_frame': 4, 'strip_s': 0.56, 'aim': 0.4}}
- s: switching idle/walk/attack pops (heights [46, 46, 46], foot lines [50, 50, 50], centre x [30, 32, 34])
- death_e (5): 2 stray specks; team colour missing in frames [5]
- death_n (5): 2 stray specks
- death_ne (5): 4 stray specks
- death_s (5): team colour missing in frames [5]
- death_se (5): 2 stray specks; team colour missing in frames [5]
- idle_ne (3): body (team colour) jumps 2.6 px between frames
- idle_s (3): feet slide 4 px sideways; body (team colour) jumps 3.1 px between frames
- idle_se (3): body (team colour) jumps 2.8 px between frames

## thresher (old roster, retired in gear mode)
cell [76, 55], anchor [38.0, 52.0]
walk: {'speed': 54.0, 'frames': 6, 'fps': 10.0, 'cycle_s': 0.6, 'ground_per_cycle': 32.4, 'foot_spread_range': 5, 'slide_k': 3.24}
attack: {'attack': {'frames': 4, 'fps': 9.0, 'hit_frame': 2, 'strip_s': 0.44, 'aim': 0.2}}
- s: switching idle/walk/attack pops (heights [46, 48, 44], foot lines [51, 51, 51], centre x [38, 37, 42])
- n: switching idle/walk/attack pops (heights [47, 47, 44], foot lines [51, 51, 51], centre x [38, 38, 43])
- death_e (5): 2 stray specks; half-transparent fringe 6% of the body
- death_n (5): 3 stray specks
- death_ne (5): 1 stray specks; half-transparent fringe 7% of the body
- death_s (5): 2 stray specks; half-transparent fringe 7% of the body
- death_se (5): 1 stray specks; half-transparent fringe 8% of the body
- idle_se (3): feet slide 5 px sideways

## bulwark (old roster, retired in gear mode)
cell [68, 58], anchor [34.0, 54.0]
walk: {'speed': 46.0, 'frames': 6, 'fps': 8.0, 'cycle_s': 0.75, 'ground_per_cycle': 34.5, 'foot_spread_range': 5, 'slide_k': 3.45}
attack: {'attack': {'frames': 3, 'fps': 9.0, 'hit_frame': 3, 'strip_s': 0.33, 'aim': 0.3}}
- braced_hit_n (4): foot line moves 3 px
- braced_hit_ne (4): 1 stray specks
- braced_hit_s (4): 1 stray specks
- death_n (5): 1 stray specks
- death_s (5): 1 stray specks
- death_se (5): 3 stray specks

## windup_soldier (old roster, retired in gear mode)
cell [36, 30], anchor [18.0, 27.0]
walk: {'speed': 66.0, 'frames': 6, 'fps': 12.0, 'cycle_s': 0.5, 'ground_per_cycle': 33.0, 'foot_spread_range': 8, 'slide_k': 2.06}
attack: {'attack': {'frames': 5, 'fps': 9.0, 'hit_frame': 2, 'strip_s': 0.56, 'aim': 0.15}}

## spring_catapult
- throw_s (12): up to 161 red px the team shader misses
- throw_se (12): up to 142 red px the team shader misses
- throw_e (12): up to 111 red px the team shader misses
- throw_ne (12): up to 138 red px the team shader misses
- throw_n (12): up to 226 red px the team shader misses
- move_s (8): up to 161 red px the team shader misses
- move_se (8): up to 142 red px the team shader misses
- move_e (8): up to 112 red px the team shader misses
- move_ne (8): up to 141 red px the team shader misses
- move_n (8): up to 225 red px the team shader misses

## great_winder
- walk_s (12): up to 130 red px the team shader misses
- walk_se (12): up to 109 red px the team shader misses
- walk_e (12): up to 98 red px the team shader misses
- walk_ne (12): up to 95 red px the team shader misses
- walk_n (12): up to 104 red px the team shader misses
- wind_s (12): duplicate frames ['8=4', '9=5', '10=6']; up to 127 red px the team shader misses
- wind_se (12): duplicate frames ['8=4', '9=5', '10=6']; up to 106 red px the team shader misses
- wind_e (12): duplicate frames ['8=4', '9=5', '10=6']; up to 96 red px the team shader misses
- wind_ne (12): duplicate frames ['8=4', '9=5', '10=6']; up to 89 red px the team shader misses
- wind_n (12): duplicate frames ['8=4', '9=5', '10=6']; up to 100 red px the team shader misses
- sweep_s (8): up to 127 red px the team shader misses
- sweep_se (8): up to 106 red px the team shader misses
- sweep_e (8): up to 97 red px the team shader misses
- sweep_ne (8): up to 95 red px the team shader misses
- sweep_n (8): duplicate frames ['5=1']; up to 106 red px the team shader misses

## building clocktower
- built: {'w': 128, 'h': 192, 'foot': 191, 'px': 12991, 'specks': 2, 'fringe': 0, 'key1': 239, 'key2': 187, 'near': 0, 'size': [128, 192], 'fringe_pct': 0.0, 'foot_from_bottom': 0}
- construction: {'w': 135, 'h': 164, 'foot': 163, 'px': 12596, 'specks': 0, 'fringe': 0, 'key1': 0, 'key2': 3, 'near': 0, 'size': [135, 164], 'fringe_pct': 0.0, 'foot_from_bottom': 0}
- damaged: {'w': 127, 'h': 175, 'foot': 175, 'px': 12723, 'specks': 3, 'fringe': 0, 'key1': 154, 'key2': 134, 'near': 0, 'size': [127, 176], 'fringe_pct': 0.0, 'foot_from_bottom': 0}
- destroyed: {'w': 157, 'h': 137, 'foot': 136, 'px': 9854, 'specks': 0, 'fringe': 0, 'key1': 65, 'key2': 61, 'near': 0, 'size': [157, 137], 'fringe_pct': 0.0, 'foot_from_bottom': 0}
- FLAG built: 2 stray specks at [(35, 52, 1), (32, 54, 3)]
- FLAG damaged: 3 stray specks at [(94, 3, 6), (96, 7, 5), (94, 10, 1)]

## building cog_press
- built: {'w': 102, 'h': 122, 'foot': 138, 'px': 8870, 'specks': 0, 'fringe': 1037, 'key1': 4, 'key2': 6, 'near': 30, 'size': [116, 140], 'fringe_pct': 11.7, 'foot_from_bottom': 1}
- construction: {'w': 109, 'h': 128, 'foot': 138, 'px': 10489, 'specks': 0, 'fringe': 1429, 'key1': 12, 'key2': 2, 'near': 21, 'size': [116, 140], 'fringe_pct': 13.6, 'foot_from_bottom': 1}
- damaged: {'w': 104, 'h': 139, 'foot': 138, 'px': 9294, 'specks': 0, 'fringe': 1379, 'key1': 5, 'key2': 0, 'near': 19, 'size': [116, 140], 'fringe_pct': 14.8, 'foot_from_bottom': 1}
- destroyed: {'w': 116, 'h': 97, 'foot': 138, 'px': 7380, 'specks': 0, 'fringe': 1009, 'key1': 8, 'key2': 0, 'near': 0, 'size': [116, 140], 'fringe_pct': 13.7, 'foot_from_bottom': 1}
- work: 8 frames, step % [3.47, 3.83, 4.26, 17.29, 16.27, 4.82, 4.86, 4.54], seam 0.44, vs built % [6.32, 7.84, 8.66, 20.54, 9.56, 9.48, 8.88, 7.6], h_rng 0, c_jump 0.4, specks 0
- FLAG work frames all differ from built by >= 6.3% of px (start/stop pop)

## building mainspring
- built: {'w': 106, 'h': 110, 'foot': 143, 'px': 7681, 'specks': 0, 'fringe': 1480, 'key1': 12, 'key2': 30, 'near': 97, 'size': [121, 145], 'fringe_pct': 19.3, 'foot_from_bottom': 1}
- construction: {'w': 109, 'h': 121, 'foot': 143, 'px': 9625, 'specks': 0, 'fringe': 1309, 'key1': 7, 'key2': 7, 'near': 67, 'size': [121, 145], 'fringe_pct': 13.6, 'foot_from_bottom': 1}
- damaged: {'w': 103, 'h': 144, 'foot': 143, 'px': 8373, 'specks': 3, 'fringe': 1981, 'key1': 14, 'key2': 22, 'near': 138, 'size': [121, 145], 'fringe_pct': 23.7, 'foot_from_bottom': 1}
- destroyed: {'w': 121, 'h': 96, 'foot': 143, 'px': 7682, 'specks': 0, 'fringe': 1326, 'key1': 10, 'key2': 15, 'near': 81, 'size': [121, 145], 'fringe_pct': 17.3, 'foot_from_bottom': 1}
- work: 8 frames, step % [18.3, 5.42, 5.28, 5.04, 4.63, 4.51, 6.23, 18.12], seam 2.6, vs built % [7.37, 6.73, 5.67, 6.37, 6.83, 6.38, 6.38, 17.82], h_rng 0, c_jump 0.7, specks 10
- FLAG damaged: 3 stray specks at [(120, 112, 1), (118, 115, 3), (120, 115, 4)]
- FLAG work loop seam 2.6x the mean frame change
- FLAG work: 10 stray specks
- FLAG work frames all differ from built by >= 5.7% of px (start/stop pop)

## building escapement
- built: {'w': 112, 'h': 117, 'foot': 137, 'px': 8727, 'specks': 0, 'fringe': 926, 'key1': 0, 'key2': 0, 'near': 187, 'size': [116, 139], 'fringe_pct': 10.6, 'foot_from_bottom': 1}
- construction: {'w': 110, 'h': 120, 'foot': 137, 'px': 9501, 'specks': 0, 'fringe': 2151, 'key1': 0, 'key2': 0, 'near': 149, 'size': [116, 139], 'fringe_pct': 22.6, 'foot_from_bottom': 1}
- damaged: {'w': 112, 'h': 138, 'foot': 137, 'px': 8922, 'specks': 0, 'fringe': 2190, 'key1': 0, 'key2': 0, 'near': 170, 'size': [116, 139], 'fringe_pct': 24.5, 'foot_from_bottom': 1}
- destroyed: {'w': 116, 'h': 96, 'foot': 137, 'px': 7904, 'specks': 0, 'fringe': 1692, 'key1': 0, 'key2': 0, 'near': 239, 'size': [116, 139], 'fringe_pct': 21.4, 'foot_from_bottom': 1}
- work: 24 frames, step % [1.95, 1.95, 8.7, 3.09, 1.95, 1.95, 8.73, 3.05, 1.92, 1.92, 8.6, 3.09, 1.99, 1.99, 8.74, 3.05, 1.95, 1.95, 8.63, 3.12, 1.92, 1.92, 8.73, 3.05], seam 0.49, vs built % [3.42, 2.91, 5.86, 8.73, 9.0, 8.73, 2.83, 5.58, 6.05, 5.58, 2.98, 6.0, 6.33, 6.0, 2.88, 5.68, 6.12, 5.68, 5.8, 8.71, 8.97, 8.71, 0.0, 2.91], h_rng 0, c_jump 0.2, specks 0
- FLAG work: duplicate frames ['6=4', '10=8', '14=12', '18=16', '22=20', '24=2']

## building movement_works
- built: {'w': 118, 'h': 128, 'foot': 132, 'px': 9564, 'specks': 0, 'fringe': 1545, 'key1': 20, 'key2': 60, 'near': 229, 'size': [118, 134], 'fringe_pct': 16.2, 'foot_from_bottom': 1}
- construction: {'w': 115, 'h': 119, 'foot': 132, 'px': 9365, 'specks': 0, 'fringe': 1723, 'key1': 6, 'key2': 31, 'near': 129, 'size': [118, 134], 'fringe_pct': 18.4, 'foot_from_bottom': 1}
- damaged: {'w': 114, 'h': 133, 'foot': 132, 'px': 9469, 'specks': 0, 'fringe': 1841, 'key1': 9, 'key2': 55, 'near': 214, 'size': [118, 134], 'fringe_pct': 19.4, 'foot_from_bottom': 1}
- destroyed: {'w': 116, 'h': 100, 'foot': 132, 'px': 7369, 'specks': 0, 'fringe': 1378, 'key1': 5, 'key2': 22, 'near': 81, 'size': [118, 134], 'fringe_pct': 18.7, 'foot_from_bottom': 1}
- work: 8 frames, step % [8.24, 2.99, 3.62, 3.74, 1.92, 6.57, 8.37, 10.1], seam 1.55, vs built % [4.35, 4.53, 4.59, 2.68, 2.49, 6.53, 7.59, 8.45], h_rng 0, c_jump 1.1, specks 0

## building cuckoo_house
- built: {'w': 62, 'h': 139, 'foot': 142, 'px': 5930, 'specks': 0, 'fringe': 925, 'key1': 0, 'key2': 0, 'near': 280, 'size': [138, 144], 'fringe_pct': 15.6, 'foot_from_bottom': 1}
- construction: {'w': 74, 'h': 134, 'foot': 142, 'px': 7648, 'specks': 0, 'fringe': 1308, 'key1': 0, 'key2': 0, 'near': 144, 'size': [138, 144], 'fringe_pct': 17.1, 'foot_from_bottom': 1}
- damaged: {'w': 101, 'h': 143, 'foot': 142, 'px': 6860, 'specks': 1, 'fringe': 1389, 'key1': 0, 'key2': 0, 'near': 194, 'size': [138, 144], 'fringe_pct': 20.2, 'foot_from_bottom': 1}
- destroyed: {'w': 107, 'h': 85, 'foot': 142, 'px': 5998, 'specks': 0, 'fringe': 1031, 'key1': 0, 'key2': 0, 'near': 182, 'size': [138, 144], 'fringe_pct': 17.2, 'foot_from_bottom': 1}
- work: 4 frames, step % [5.11, 3.5, 2.74, 4.45], seam 1.43, vs built % [0.81, 3.69, 3.78, 5.18], h_rng 0, c_jump 2.9, specks 0
- FLAG damaged: 1 stray specks at [(134, 118, 6)]

## building regulator
- built: {'w': 65, 'h': 91, 'foot': 111, 'px': 3729, 'specks': 0, 'fringe': 627, 'key1': 5, 'key2': 28, 'near': 66, 'size': [95, 113], 'fringe_pct': 16.8, 'foot_from_bottom': 1}
- construction: {'w': 83, 'h': 97, 'foot': 111, 'px': 5507, 'specks': 0, 'fringe': 921, 'key1': 6, 'key2': 0, 'near': 22, 'size': [95, 113], 'fringe_pct': 16.7, 'foot_from_bottom': 1}
- damaged: {'w': 80, 'h': 112, 'foot': 111, 'px': 4718, 'specks': 0, 'fringe': 1082, 'key1': 15, 'key2': 31, 'near': 77, 'size': [95, 113], 'fringe_pct': 22.9, 'foot_from_bottom': 1}
- destroyed: {'w': 95, 'h': 69, 'foot': 111, 'px': 3885, 'specks': 0, 'fringe': 744, 'key1': 12, 'key2': 23, 'near': 108, 'size': [95, 113], 'fringe_pct': 19.2, 'foot_from_bottom': 1}
- work: 8 frames, step % [0.84, 0.87, 0.66, 0.66, 0.87, 0.84, 0.73, 0.73], seam 1.1, vs built % [0.0, 0.87, 1.05, 0.87, 0.0, 0.84, 1.09, 0.84], h_rng 0, c_jump 0.0, specks 0
- FLAG work: duplicate frames ['4=2', '5=1', '8=6']

## building ratchet_turret
- built: {'w': 68, 'h': 77, 'foot': 100, 'px': 3636, 'specks': 0, 'fringe': 562, 'key1': 3, 'key2': 40, 'near': 146, 'size': [88, 102], 'fringe_pct': 15.5, 'foot_from_bottom': 1}
- construction: {'w': 80, 'h': 88, 'foot': 100, 'px': 4906, 'specks': 0, 'fringe': 870, 'key1': 9, 'key2': 2, 'near': 23, 'size': [88, 102], 'fringe_pct': 17.7, 'foot_from_bottom': 1}
- damaged: {'w': 74, 'h': 101, 'foot': 100, 'px': 4158, 'specks': 0, 'fringe': 990, 'key1': 8, 'key2': 54, 'near': 130, 'size': [88, 102], 'fringe_pct': 23.8, 'foot_from_bottom': 1}
- destroyed: {'w': 88, 'h': 65, 'foot': 100, 'px': 3591, 'specks': 0, 'fringe': 832, 'key1': 3, 'key2': 12, 'near': 119, 'size': [88, 102], 'fringe_pct': 23.2, 'foot_from_bottom': 1}
