
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

# Check that the program exists.
if [ ! -s "$program" ]; then
  echo "  Skipping: metar exe is missing: $program"
  exit
fi


$program testfiles/image.jpg > tshell.txt

size=$(wc -c <tshell.txt | sed -e 's/\ //g')

for last; do true; done
# echo "last = $last"

if [ "$last" == "release" ]; then
    rel="release"
else
    rel="debug"
fi

if [ $size -gt 1000 ]; then
    printf "\e[1;32m  [OK]\e[00m test redirection $rel\n"
    rm tshell.txt
else
    printf "\e[1;31m  [FAILED]\e[00m test redirection $rel\n"
    echo "Re-direction to the file tshell.txt failed"
fi
