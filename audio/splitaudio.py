#!/usr/bin/env python

# pip install pydub
# brew install ffmpeg --with-libvorbis --with-sdl2 --with-theora

from pydub import AudioSegment
import sys
import math
import os.path

default_ticks = 60 * 60 * 1000 # 1h in milliseconds

def verbose(message):
    sys.stderr.write('%s\n' % message)

def splitaudio(filename, ticks):
    pathname, extension = os.path.splitext(filename)
    filetype = extension[1:]

    verbose('Decoding %s...' % filename)

    audio = AudioSegment.from_file(filename, filetype)
    segments = math.ceil(len(audio) / float(ticks))

    verbose('Exporting %d segments...' % segments)

    n = 0
    while audio:
        n += 1
        number = ('%0' + '%d' % len('%d' % segments) + 'd') % n
        outfile = ('%s-%s%s') % (pathname, number, extension)
        segment, audio = audio[:ticks], audio[ticks:]
        segment.export(outfile, format=filetype)
        verbose(outfile)

for filename in sys.argv[1:]:
    splitaudio(filename, default_ticks)
