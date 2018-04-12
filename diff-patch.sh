#!/bin/bash

##### make diff patch for GOAL on BASE, and make rollback patch backwards at the same time

BASE=path/to/base
GOAL=path/to/goal

makediff(){
    local OUT FROM TO LOG SH
    OUT=$1
    FROM=$2
    TO=$3
    LOG=$1.log
    SH=$1.sh
    
    echo "========== ${1} #${BASE_BUILD_NUMBER} -> #${TARGET_BUILD_NUMBER} =========="

    # if output dir existed, remove and make again, copy files of this build to it
    if [ -d $OUT ];then
        rm -rf $OUT
    fi

    mkdir $OUT
    cp -r $TO/* $OUT/
    
    echo "# ========== ${1}-build ==========" >> $OUT/jenkins_build
    echo "${1}-build url : ${BUILD_URL}" >> $OUT/jenkins_build

    echo "===== remove the files that not changed from output dir ====="
    find $OUT -type f -print0 | while read -d $'\0' tofile
    do
        #echo $tofile
        fromfile=`echo "$tofile" | sed "s/$OUT/$FROM/"`
        outfile=`echo "$tofile" | sed "s/$OUT/\./"`
        if [ -f "$fromfile" ];then
            diff "$fromfile" "$tofile" >> /dev/null
            # $? is the last return(diff result), 0 means no diff
            if [ $? -eq 0 ];then
                # echo "no diff, rm -f $tofile"
                rm -vf "$tofile"
            else
                echo "M:$outfile" >> $OUT/$LOG
            fi
        else
            echo "+:$outfile" >> $OUT/$LOG
        fi
    done

    echo "===== add rm cmd into script for those removed files in target build ====="
    find $FROM -type f -print0 | while read -d $'\0' fromfile
    do
        tofile=`echo "$fromfile" | sed "s/$FROM/$TO/"`
        # the from file not exist in target build
        if [ ! -f "$tofile" ];then
            delfile=`echo "$fromfile" | sed "s/$FROM/\./"`
            echo "rm -vf '$delfile'" >> $OUT/$SH
            echo "-:$delfile" >> $OUT/$LOG
        fi
    done

    echo "+ for new file, - for deleted file, M for modified file." >> $OUT/$LOG

    echo "rm -vf $LOG" >> $OUT/$SH
    echo "rm -vf $SH" >> $OUT/$SH

    chmod +x $OUT/$SH
}

makediff patch ${BASE} ${GOAL}
makediff rollback ${GOAL} ${BASE}