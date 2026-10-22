#!/bin/sh
# The Town Hall's select sound: a short call cut from the designer's medieval trumpet recording
# (art/audio/medieval_trumpet.mp3, 40 s): 37.88-39.00 s, the closing flourish (a short note,
# then the held top note), 12 ms fade in, 0.22 s fade out. Then re-level with make_mix.py.
cd "$(dirname "$0")/../.."
ffmpeg -y -loglevel error -ss 37.88 -t 1.12 -i art/audio/medieval_trumpet.mp3 -ac 1 -ar 44100 \
	-af "afade=t=in:d=0.012,afade=t=out:st=0.9:d=0.22" -c:a pcm_s16le assets/audio/select/town_hall.wav
