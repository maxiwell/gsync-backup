#!/bin/bash
# crontab 7 a.m. everyday
# 0 7 * * * backup.sh


# files
FILTER_FILE="$HOME/.rsync-filter"
LOG_FILE="/tmp/backup.log"

# programs
RSYNC="rsync -Rrazpt -v  --delete"
RCLONE="rclone --delete-excluded"
GIT="git"

# environment
RED='\033[0;31m'
YELLOW='\033[1;33m'
PURPLE='\e[0;35m' 
GREEN='\e[32m'
NC='\033[0m' # No Color
ENABLE_GIT=false

usage () {
    echo -ne "Usage:\n"
    echo -ne "\t$0 [--enable-git] /path/to/config.bkp\n"
}

print_header () {
    echo -e "-------------------------------------------------------------------"
    echo -e " GSync Backup v0.1"
    echo -e "-------------------------------------------------------------------"
    echo -e "$GREEN[INFO]$NC Using $FILTER_FILE as default rsync exclude"
    echo -e "$GREEN[INFO]$NC To details about your backup, see $LOG_FILE"
    echo -e "$GREEN[INFO]$NC See the config.bkp file to write your configuration" 
    echo -e "-------------------------------------------------------------------"
}

# $1: error message
error_and_die () {
    usage
    echo -ne "\n${RED}[ERROR]${NC} $1\n\n"
    exit 1;
}

# $1: Server:folder to commit
commit_changes () {
    local _SERVER=`echo $1 | cut -d ":" -f1`
    local _FOLDER=`echo $1 | cut -d ":" -f2`
    if [ "$_SERVER" == "$_FOLDER" ]; then
        (cd $_FOLDER &&
            $GIT init   &&
            $GIT add .  &&
            $GIT commit -a -m "dummy") &>> $LOG_FILE
    else 
        ssh $_SERVER "
        cd $_FOLDER &&
            $GIT init   &&
            $GIT add .  &&
            $GIT commit -a -m \"dummy\" " &>> $LOG_FILE
    fi
}

# $1: exclude list
# $2: exclude file
exclude_file () {
    EXCLUDE_LIST=$1
    FILE=$2
    for x in $EXCLUDE_LIST
    do
        echo $x >> $FILE
    done
}

# $1: string with args
build_args () {
    args=$1
    FAIL=false

    for i in $args; do
        case $i in
            --exclude)
                EXCLIST=`echo "$args" | awk -F '--exclude' '{print $2}' | awk -F '--' '{print $1}'`
                echo $EXCLIST | tr ' ' '\n' &>> $EXCLUDE_FILE
                ;;
            -exclude)
                echo -e "$RED[ERROR]$NC Invalid argument $i, try --exclude"
                echo -e "[ERROR] Use --exclude" &>> $LOG_FILE
                FAIL=true
                ;;
            --*)
                echo -e "$RED[ERROR]$NC Invalid argument $i"
                echo -e "Invalid argument $i" &>> $LOG_FILE
                FAIL=true
                ;;
        esac
    done

    if [ $FAIL == true ]; then
        exit 2;
    fi
}

# ----------
# main
#-----------

print_header


if [ "$1" == "--enable-git" ]; then
    ENABLE_GIT=true;
    INPUT_FILE=$2;
else
    INPUT_FILE=$1;
fi

[[ -f ${INPUT_FILE} ]] || error_and_die "Backup config file don't found"
[[ $ENABLE_GIT = true ]] && echo -e "$YELLOW[WARN]$NC Experimental git versioning enabled"

rm -f $LOG_FILE

while read line
do
    [[ $line == \#* ]] && continue
    [[  -z $line    ]] && continue
    if [[ $line == \[* ]]; then 
        SERVER=`echo $line | cut -d "[" -f2 | cut -d "]" -f1`
        CLOUD=""
        continue
    elif [[ $line == \{* ]]; then
        CLOUD=`echo $line | cut -d "{" -f2 | cut -d "}" -f1`
        SERVER=""
        continue
    fi

    DIR=`echo $line | cut -d\  -f1 | sed 's@(\(.*\))@\1@g'`
    if [ ! -e $DIR ]; then
        echo -e "$YELLOW[WARN]$NC The path '$line' don't exists\n"
        continue
    fi

    DIR_ON_SERVER=`echo $line | cut -d\  -f1 | sed 's@(\(.*\))@@g'`

    EXCLUDE_FILE=/tmp/excluded.txt && rm -f $EXCLUDE_FILE && touch $EXCLUDE_FILE
    ARGS_LINE=`echo $line | cut -d\  -f2-`
    build_args "${ARGS_LINE}"

    if [ $CLOUD ]; then
        echo -e "$YELLOW[RCLONE]$NC $DIR -> $CLOUD"
        echo -e "[RCLONE] $line -> $CLOUD" &>> $LOG_FILE
        echo -e "Excluding:\n`cat $EXCLUDE_FILE`" &>> $LOG_FILE

        CLOUD_SERVER=`echo $CLOUD | cut -d: -f1`
        CLOUD_DIR=$(readlink -m "`echo $CLOUD | cut -d: -f2-`/$DIR_ON_SERVER")

        $RCLONE sync --exclude-from $EXCLUDE_FILE $DIR "$CLOUD_SERVER:$CLOUD_DIR" &>> $LOG_FILE
        RET=`echo $?`

        # Fix the problem with Cloud Server that not support symlinks, like OneDrive:
        # A __symlinks__ file is generated with the symlink annotations
        # It must be after the sync instead of it will erase the file
        cd $DIR
        find . -type l -exec tar -rvf /tmp/__symlinks__.tar {} \; &>> $LOG_FILE
        if [ -s /tmp/__symlinks__.tar ]; then
            $RCLONE copy /tmp/__symlinks__.tar "$CLOUD_SERVER:$CLOUD_DIR" &>> $LOG_FILE
            echo "[ INFO ] Symlink was found"
        fi
        rm -f /tmp/__symlinks__.tar
        cd - &> /dev/null 

    else
        echo -e "$YELLOW[RSYNC]$NC $DIR -> $SERVER "
        echo -e "[RSYNC] $line -> $SERVER " &>> $LOG_FILE
        echo -e "Excluding:\n`cat $EXCLUDE_FILE`" &>> $LOG_FILE
        $RSYNC --exclude-from $EXCLUDE_FILE --exclude-from="$FILTER_FILE" -e ssh $DIR $SERVER &>> $LOG_FILE 
        RET=`echo $?`
    fi
    [[ $RET != 0 ]] && echo -e "Errors was found. See /tmp/backup.log"
    [[ $ENABLE_GIT = true ]] && commit_changes ${SERVER}
    rm $EXCLUDE_FILE

done < "$INPUT_FILE"


