f=$1; shift
convert $f -channel rgb -brightness-contrast 80,-50 +channel -alpha set -channel a -evaluate multiply 0.8 +channel ${f%.png}-ghost.png
