#!/bin/sh
# Builds the demo disk: ray-traces the pictures, turns them into
# frame code, assembles and writes build/demo.imd and build/demo_525.imd.
# Needs Python 3 and sjasmplus.
set -e
cd "$(dirname "$0")"
# FONT: xcpmz80's 8 x 8 font, font.bin beside this file unless set.
: "${FONT:=font.bin}"
mkdir -p build/pics
cp "$FONT" build/font.bin
if [ ! -f build/pics/still.pbm ] || [ tools/scene.py -nt build/pics/still.pbm ]; then
	python3 tools/scene.py build/pics
fi
python3 tools/sequence.py build/pics > build/pics/seq.txt
python3 tools/racegen.py build build/pics/seq.txt
python3 tools/wingen.py build
python3 tools/barsgen.py build/bars.inc
python3 tools/splitgen.py build/font.bin build/split.inc
python3 tools/bootmsg.py build/font.bin build/bootmsg.inc
(cd src && sjasmplus --nologo --msg=war --lst=../build/demo.lst --raw=../build/demo.sys demo.asm)
python3 tools/mkdisk.py build/demo.sys build build/demo.imd
python3 tools/mkdisk.py build/demo.sys build build/demo_525.imd --525
