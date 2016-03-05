#!/bin/bash
# crontab 7 a.m. everyday
# 0 7 * * * backup.sh


# files
FILTER_FILE="$HOME/.rsync-filter"
LOG_FILE="/tmp/backup.log"

# programs
RSYNC="rsync -Rrazpt -v  --delete"
GIT="git"

# environment
set -e
_PWD=$PWD
RED='\033[0;31m'
YELLOW='\033[1;33m'
PURPLE='\e[0;35m' 
NC='\033[0m' # No Color
INPUT_FILE=$1

function usage {
    echo -ne "Usage:\n\t$0 /path/to/config.bkp\n"
}

function print_header {
    echo -e "-------------------------------------------------------------------"
    echo -e " GRSBackup v0.1"
    echo -e "-------------------------------------------------------------------"
    echo -e " - Using $FILTER_FILE as default rsync exclude"
    echo -e " - Versioning isn't implemented"
    echo -e " - To details about your backup, see $LOG_FILE"
    echo -e "-------------------------------------------------------------------"
}

# $1: error message
function error_and_die {
    usage
    echo -ne "\n${RED}[ERROR]${NC} $1\n\n"
    exit 1;
}

# ----------
# main
#-----------

print_header

[[ -f ${INPUT_FILE} ]] || error_and_die "Backup config file don't found"


rm -f $LOG_FILE
RSYNC_FILTER_STRING=$(cat .rsync-filter | sed 's/#.*$//g' | sed '/^$/d' | tr '\n' ' ')

while read line
do
    [[ $line == \#* ]] && continue
    [[  -z $line   ]] && continue
    [[ $line == \[* ]] && SERVER=`echo $line | cut -d "[" -f2 | cut -d "]" -f1` && continue

#    [[ $SERVER == "" ]] && error_and_die "Server ${SERVER} not found in ${INPUT_FILE} ($line)"
    if [ `echo $line | wc -w` -gt 1 ]; then
       P1=`echo $line | cut -d\  -f1`
       cd $P1 
       ARG=`echo $line | cut -d\  -f2`
       EXCLUDE_LIST=`echo $line | cut -d\  -f3-`
       if [ $ARG == "-exclude" ]; then 
            rm -f /tmp/excluded.txt  # just in case
            for x in $EXCLUDE_LIST
            do
                echo $x >> /tmp/excluded.txt
            done
            if [ -e "$P1" ]; then
                echo -e "\n[RSYNC] $P1 -> $SERVER $YELLOW [$FILTER_FILE] $NC $RED $RSYNC_FILTER_STRING $NC $yellow [$ARG] $NC $red  $EXCLUDE_LIST $NC"
                echo -e "\n[RSYNC] $P1 -> $SERVER [$FILTER_FILE] $RSYNC_FILTER_STRING [$ARG] $EXCLUDE_LIST" &>> $LOG_FILE
                # -C : Ignore like CVS
                $RSYNC --exclude-from /tmp/excluded.txt --exclude-from="$FILTER_FILE" -e ssh $P1 $SERVER &>> $LOG_FILE
                if [ $? != 0 ]; then
                    echo -e "Errors was found. See /tmp/backup.log"
                fi
            else
                echo -e "[WARN] The path '$line' don't exists\n"
            fi
            rm -f /tmp/excluded.txt
            cd $_PWD
       else 
            echo "Argument $ARG dont implemented in $line"
            continue
        fi
    
    elif [ -e "$line" ]; then
        echo -e "\n[RSYNC] $line -> $SERVER $YELLOW [$FILTER_FILE] $NC $RED $RSYNC_FILTER_STRING $NC"
        # -C : Ignore like CVS 
        $RSYNC --exclude-from="$FILTER_FILE" -e ssh $line $SERVER &>> $LOG_FILE
        if [ $? != 0 ]; then
            echo -e "Errors was found. See /tmp/backup.log"
        fi
    else
        echo -e "[WARN] The path '$line' don't exists\n"
    fi

done < "$INPUT_FILE"


