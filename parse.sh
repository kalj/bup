#!/bin/bash

conffile="$1"

target_list=()

while read -r line ;
do

    if [[ "$line" == \[* ]] ; then
        a="$(echo "$line" | sed 's/\[\s*\(.*\)\s*\]/\1/')"

        if [[ "$a" == target* ]] ;
        then

            trg="$(echo "$a" | sed 's/.*\"\(.*\)\"/\1/')"

            target_list+=("${trg}")

            currentsection="target_${trg}"
        else
            currentsection="$a"
        fi
    elif echo "$line" | grep '=' &>/dev/null ;
    then

        read var val < <(echo "$line" | sed 's|\s*\(.*\)\s*=\s*\(.*\)\s*|\1 \2|')


        declare "${currentsection}_$var=$val"

        if [ "$var" == exclusions ] ;
        then

            declare "${currentsection}_exclude+= --exclude $val"
        else
            declare "${currentsection}_$var=$val"
        fi

    # else
        # echo "found something else: $line"
    fi
done < <(cat "$conffile" )




echo "[core]"
for v in backup_host backup_interval ; do

    printf "    %-20s" "${v}"
    eval str=\"\$core_$v\"
    echo $str

done


for a in "${target_list[@]}" ;
do
    echo "[$a]"
    for v in source destination previous_link exclude ; do

        printf "    %-20s" "${v}"
        eval str=\"\$target_${a}_$v\"
        echo $str
    done
done
