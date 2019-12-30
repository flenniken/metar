
# Test that re-direction goes to the file.
if [[ "$OSTYPE" == "linux-gnu" ]]; then

  # Linux
  if [ "$1" == "release" ]; then
      program='bin/linux/metar'
  else
      program='bin/linux/debug/metar'
  fi

elif [[ "$OSTYPE" == "darwin"* ]]; then

  # Mac OSX
  if [ "$1" == "release" ]; then
      program='bin/mac/metar'
  else
      program='bin/mac/debug/metar'
  fi

else
    # Not tested platform.
    program='ls'

fi

$program testfiles/image.jpg > t.txt

size=$(wc -c <t.txt | sed -e 's/\ //g')

for last; do true; done
# echo "last = $last"

if [ "$last" == "release" ]; then
    rel="release"
else
    rel="debug"
fi

if [ $size -gt 1000 ]; then
    printf "\e[1;32m  [OK]\e[00m test redirection $rel\n"
    rm t.txt
else
    printf "\e[1;31m  [FAILED]\e[00m test redirection $rel\n"
    echo "Re-direction to the file t.txt failed"
fi
