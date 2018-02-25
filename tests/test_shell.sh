
# Test that re-direction goes to the file.
bin/metar testfiles/image.jpg > t.txt

size=$(wc -c <t.txt | sed -e 's/\ //g')

if [ $size -gt 1000 ]; then
    printf "\e[1;32m  [OK]\e[00m test redirection\n"
    rm t.txt
else
    printf "\e[1;31m  [FAILED]\e[00m test redirection\n"
    echo "Re-direction to the file t.txt failed"
fi
