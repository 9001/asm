## lat0-10.psfu.gz bugfix

the boxdrawing characters weren't in the designateds slots (176-223) so they rendered incorrectly (gap of one pixel between cells)

* reordered to match (in order of preference) default8x9, lat4-10, lat1-10
* filled the gaps in 176-223 with safe characters (rightmost column empty)
* and also made the dot inside zero bigger

remapper:

    cp /usr/lib/kbd/consolefonts/{default8x9,lat0-10,lat4-10}.psfu.gz . 
    for f in *.gz; do gzip -d $f; done; for f in *.psfu; do psf2txt $f ${f%.*}.txt; done
    for f in *.psfu; do awk -vf=$f '/Character/{c=$3}/Unicode/{gsub(/\];\[/,"|");gsub(/[][]/," ");print c" "$2" "f}' <${f%.*}.txt >${f%.*}.ord; done
    head -n6 <lat0-10.txt >lat0-10-asm.txt; rm -f ord; cat lat0-10.ord | while read n u f; do grep -E "$u" <default8x9.ord >o && head -n1 o >>ord && continue; done; cat lat0-10.ord | while read n u f; do grep -qE "$u" <ord && continue; n2=$(awk "/$u/{print\$1;exit}" lat4-10.ord); [ $n2 ] || n2=$n; [ $n2 ] && grep -qE "^$n2 " <ord && n2=$n; grep -qE "^$n2 " <ord && n2=999 && f=; echo "$n2 $u $f" >>ord; done; cat ord | sort -n | while read n u f; do grep -E "$u" -B12 lat0-10.txt | sed -r 's/( Character ).*/\1'"$n ($f)/"; done >>lat0-10-asm.txt; wc -l lat0-10-asm.txt lat0-10.txt
    txt2psf lat0-10-asm.txt a.psfu && pigz -c11 -I8000 <a.psfu >../../etc/cfnt/lat0-10.psfu.gz 
