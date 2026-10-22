#!/bin/sh
# The Town Hall's select sound: ONE short low trumpet note from the designer's medieval trumpet
# recording (art/audio/medieval_trumpet.mp3, 40 s): 7.38-7.80 s, softened (low-pass 3.2 kHz),
# 10 ms fade in, 0.18 s fade out. The hall is clicked for every worker, so its answer has to be
# short and soft enough to hear a hundred times. Then re-level with make_mix.py.
cd "$(dirname "$0")/../.."
ffmpeg -y -loglevel error -ss 7.38 -t 0.42 -i art/audio/medieval_trumpet.mp3 -ac 1 -ar 44100 \
	-af "lowpass=f=3200,afade=t=in:d=0.01,afade=t=out:st=0.24:d=0.18" -c:a pcm_s16le assets/audio/select/town_hall.wav
