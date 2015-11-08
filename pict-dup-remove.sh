#!/bin/bash

MAX_THREAD_NUM=3

DIFF_PICT_NAME="__tmp_diff"

CACHE_PATH="./"

IFS=$(echo -en "\n\b")

usage_exit() {
    echo "Usage: $0 -d move_dir -t threshold_val [-c cache_path] directory_path" 1>&2
    exit 1
}


while getopts d:t:c:h OPT
do
    case $OPT in
        d) MOVE_PATH=$OPTARG'/'
            ;;
        t) THRESHOLD=$OPTARG
            ;;
        c) CACHE_PATH=$OPTARG'/'
            ;;
        h) usage_exit
            ;;
        \?) usage_exit
            ;;
    esac
done

if [[ $OPTIND -eq 1 ]]; then
    usage_exit
fi

if [[ -z ${MOVE_PATH+x} ]]; then
    echo "Please set move directory path." 1>&2
    usage_exit
fi

if [[ -z ${THRESHOLD+x} ]]; then
    echo "Please set threshold value (used in comparison among pictures)." 1>&2
    usage_exit
fi

if ! [[ ${THRESHOLD} =~ ^[0-9]+$ ]]; then
    echo "Please set a number in threshold value option"
    usage_exit
fi

shift $((OPTIND - 1))

if [[ -z "$1" ]]; then
    echo "Please set picture's directory path." 1>&2
    usage_exit
fi

raw_list=`find $1 -maxdepth 1 -type f -regex ".*\.\(GIF\|PNG\|JPG\|jpg\|png\|gif\)$"`

list=( ${raw_list} )


# comparision between two pictures. and if $1 equals to $2 (in other words, the result is less than or equal to THRESHOLD variable), then $2 move to $MOVE_PATH.
# @param $1 target picture
# @param $2 compared picture
# @param $3 index value
#
comparison() {
    equiv_val=`composite -compose difference $1 $2 ${CACHE_PATH}${DIFF_PICT_NAME}$3 && identify -format "%[mean]" ${CACHE_PATH}${DIFF_PICT_NAME}$3 && rm ${CACHE_PATH}${DIFF_PICT_NAME}$3`
    if [[ ${equiv_val} =~ ^[\.0-9]+$ ]]; then

        comp_reslt=`echo "${equiv_val} <= ${THRESHOLD}" | bc -l`

        if [[ ${comp_reslt} -eq 1 ]]; then
            echo "$1 $2" > ${MOVE_PATH}'log'$3
            #mv $2 ${MOVE_PATH}
        fi
    fi

}

#
# has not any params.
move_by_log() {
    log_list=`find ${MOVE_PATH} -maxdepth 1 -type f -regex "log[0-9]+$"`

    for entry in ${log_list}
    do
        while read file1 file2
        do
            if [[ -f ${file2} ]]; then
                mv ${file2} ${MOVE_PATH}
            fi
        done < ${entry}
    done
}


total_cnt=`seq -s "+" 1 ${#list[@]} | bc`
current_cnt=0

# main loop
for j in ${!list[@]}
do
    last_index=`expr ${#list[@]} - 1`
    for i in `seq $j $last_index`
    do
        #echo "$i ${last_index}"
        if [[ ${list[$j]} != ${list[$i]} ]]; then
            #echo "${list[$j]} ${list[$i]}"

            if [[ -f ${list[$j]} && -f ${list[$i]} ]]; then
                comparison ${list[$j]} ${list[$i]} ${current_cnt} &
            fi
        fi
        
        current_cnt=$((current_cnt+1))
        echo -ne `echo 'scale=2; 100 * '${current_cnt}' / '${total_cnt} | bc -l`'%\r'

        if [ `echo "scale=0; ${current_cnt} % ${MAX_THREAD_NUM}" | bc -l` -eq 0 ]; then
            wait
        fi

    done

done

wait

echo

move_by_log
#composite -compose difference __tmp_diff.jpg && identify -format "%[mean]" __tmp_diff.jpg && rm __tmp_diff.jpg
