#!/usr/bin/env python

# pip install pydub
# brew install ffmpeg --with-libvorbis --with-sdl2 --with-theora

from pydub import AudioSegment
import sys
import math
import os.path
import argparse

sys.excepthook = lambda exctype, value, traceback: sys.stderr.write('%s\n' % value)

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

def main():
    parser = argparse.ArgumentParser(description='Split audio into segments of a given length.')
    parser.add_argument('files', metavar='FILE', nargs='+', help='an input file containing audio')
    parser.add_argument('-t', '--ticks', metavar='N', type=int, default=default_ticks,
                        help='split audio every N milliseconds (default: %d)' % default_ticks)

    args = parser.parse_args()
    for filename in args.files:
        splitaudio(filename, args.ticks)

if __name__ == '__main__':
    main()
