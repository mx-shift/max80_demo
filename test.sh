#!/bin/sh
# Tests the demo in the emulator with -B, which draws each
# character as the beam passes it. Builds first. Each check saves
# a frame at a time and reads the raced bitmap back from it: it must be
# one of the pictures dot for dot, or in the real-time part, the text
# and a moving sphere of dots (tools/checkrt.py). The emulator's
# default stretch is the 1.02 T an access measured on the machine
#; -V adds 0 to N more: -V 0, 2 (up to 3 T, the old default
# margin) and 5 (up to 6 T, twice that).
# Needs lobo_max80 checked out beside this one, or where MAX80 points,
# with `make` run in its emu/.
cd "$(dirname "$0")" || exit 1
sh build.sh >/dev/null || exit 1
: "${MAX80:=../lobo_max80}"
R=$MAX80
RAW="$R/emu/max80 -r $R/reference/rom/max80.e12"
# The checks' times count from the end of the load, as the demo's own
# clock does: the load ends at 14.4140 s on the 8-inch disk and
# 14.9070 s on the 5.25-inch one, so every -t gets that less 1.8757 s
# added
emu() {
	case "$*" in
	*demo_525.imd*) add=13.0313 ;;
	*) add=12.5383 ;;
	esac
	n=$#
	while [ $n -gt 0 ]; do
		a=$1
		shift
		n=$((n - 1))
		if [ "$a" = -t ] && [ $n -gt 0 ]; then
			set -- "$@" -t $(awk "BEGIN { print $1 + $add }")
			shift
			n=$((n - 1))
		else
			set -- "$@" "$a"
		fi
	done
	$RAW "$@"
}
EMU=emu
[ -x $R/emu/max80 ] || { echo "build the emulator first: make in $R/emu"; exit 1; }
T=$(mktemp -d) || exit 1
trap 'rm -rf "$T"' EXIT
fail=0

# shows V SECONDS WANT: the frame at SECONDS is picture WANT, or with
# WANT spin, one of the spinning sphere's
shows() {
	rm -f $T/f.pgm
	$EMU -B -V $1 -f -a build/demo.imd -t $2 -p $T/f.pgm >/dev/null 2>&1
	got=$(python3 tools/frame2pic.py $T/f.pgm build/pics/*.pbm)
	case "$got" in
	$3*.pbm) echo "ok   -V $1, $2 s: $got" ;;
	*) echo "FAIL -V $1, $2 s: want $3, got $got"; fail=1 ;;
	esac
}

# the boot sector's message while the rest loads: lit dots in rows 10
# to 12 only, 8 lines a row, and enough of them for the two lines
rm -f $T/m.pgm
$RAW -B -f -a build/demo.imd -t 3 -p $T/m.pgm >/dev/null 2>&1
if python3 - $T/m.pgm <<'PY'
import sys
d = open(sys.argv[1], 'rb').read().split(b'\n', 4)
x0, y0 = int(d[1].split()[2]), int(d[1].split()[3])
w, h = map(int, d[2].split())
lit = [i // w - y0 for i, b in enumerate(d[4]) if b]
sys.exit(not (len(lit) > 500 and min(lit) >= 80 and max(lit) < 104))
PY
then echo "ok   the loading message"
else echo "FAIL the loading message"; fail=1
fi

# the raster bars, the opening: 7 seconds after the load
for v in 0 5; do
	for t in 4 4.3; do
		rm -f $T/b$t.pgm
		$EMU -B -V $v -f -a build/demo.imd -t $t -p $T/b$t.pgm >/dev/null 2>&1
	done
	if python3 tools/checkbars.py $T/b4.pgm $T/b4.3.pgm > $T/bars.txt; then
		echo "ok   -V $v, the raster bars"
	else
		echo "FAIL -V $v, the raster bars:"; cat $T/bars.txt; fail=1
	fi
done

# the split screen, 10 seconds after the bars
for v in 0 2; do
	for t in 12 12.3; do
		rm -f $T/s$t.pgm
		$EMU -B -V $v -f -a build/demo.imd -t $t -p $T/s$t.pgm >/dev/null 2>&1
	done
	if python3 tools/checksplit.py $T/s12.pgm $T/s12.3.pgm > $T/split.txt; then
		echo "ok   -V $v, the split screen"
	else
		echo "FAIL -V $v, the split screen:"; cat $T/split.txt; fail=1
	fi
done

# the spin, after the split screen
for v in 0 2 5; do
	shows $v 20 spin
	shows $v 21 spin
	shows $v 21.4 spin
done
# the real-time part: the sphere of dots, moving, with -V 0 and 5
for v in 0 5; do
	for t in 32 32.4; do
		rm -f $T/r$t.pgm
		$EMU -B -V $v -f -a build/demo.imd -t $t -p $T/r$t.pgm >/dev/null 2>&1
	done
	if python3 tools/checkrt.py $T/r32.pgm $T/r32.4.pgm > $T/rt.txt; then
		echo "ok   -V $v, the real-time sphere"
	else
		echo "FAIL -V $v, the real-time sphere:"; cat $T/rt.txt; fail=1
	fi
done
# the spin lasts about 9 seconds, so it is still spinning at 26
shows 0 26 spin
# the overscan finale after the real-time part
for t in 46 46.3; do
	rm -f $T/e$t.pgm
	$EMU -B -f -a build/demo.imd -t $t -p $T/e$t.pgm >/dev/null 2>&1
done
python3 tools/checkfin.py $T/e46.pgm $T/e46.3.pgm || fail=1
# into the finale: its CRTC set at line 0, so the screen does not roll
# with no vsync. Frames 20 ms apart from the real-time part (40 x 16
# cells) into the finale (92 x 22): each a new one, none held
prev=; same=0; first=; last=
for i in 44 46 48 50 52 54 56 58 60 62; do
	rm -f $T/v.pgm
	$EMU -B -f -a build/demo.imd -t 38.$i -p $T/v.pgm >/dev/null 2>&1
	sum=$(md5sum < $T/v.pgm)
	[ "$sum" = "$prev" ] && same=$((same + 1))
	prev=$sum
	cells=$(sed -n 2p $T/v.pgm | awk '{ print $7, $8 }')
	[ -z "$first" ] && first=$cells
	last=$cells
done
if [ "$first" = "40 16" ] && [ "$last" = "92 22" ] && [ $same = 0 ]; then
	echo "ok   into the finale: a new frame every 20 ms, no roll"
else
	echo "FAIL into the finale: from $first to $last, $same frames held"; fail=1
fi
# the ripple-out at the finale's end, which starts at 59 s
# (the frames were before it, and the plain finale passed)
for t in 59.75 60.25; do
	rm -f $T/r$t.pgm
	$EMU -B -f -a build/demo.imd -t $t -p $T/r$t.pgm >/dev/null 2>&1
done
python3 tools/checkrip.py $T/r59.75.pgm $T/r60.25.pgm || fail=1
# round again: the bars, the split screen, the pictures
shows 0 81 spin
# the 5.25-inch disk boots too, from DIP switch setting 1
rm -f $T/f.pgm
$EMU -B -V 2 -D 1 -f -a build/demo_525.imd -t 21 -p $T/f.pgm >/dev/null 2>&1
got=$(python3 tools/frame2pic.py $T/f.pgm build/pics/*.pbm)
case "$got" in
spin*.pbm) echo "ok   the 5.25-inch disk: $got" ;;
*) echo "FAIL the 5.25-inch disk: $got"; fail=1 ;;
esac
exit $fail
