#!/bin/bash
show_help () {
    echo "Delete oldest files in volume or directory until used space threshold is reached"
    echo
    echo "Usage: bash chomper.sh -d [directory under that to reduce] /media/computer/mypartition 90 2"
    echo "/media/computer/mypartition = the mount point to be checked for capacity and directory to be limited if -d is not set"
    echo "90: the percentage of the total partition this directory is allowed to use"
    echo "2: the number of files to be deleted every time the script loops (while $USAGE > $Max_Directory_Usage)"
    echo "options:"
    echo "-d    The directory to be limited. If not supplied, files are deleted from the 1st positional argument (mount point)"
    echo "-h    Show this help message"
    echo "-v    Display the version"
}

# for usage in cron
# 30 * * * * bash ${HOME}/chomper.sh -d ${HOME}/Downloads/ / 80 1 >> ${HOME}/chomper_logs/chomper-`date "+\%Y-\%m-\%d"`.log 2>&1

VERSION=3.0.2

PIDFILE=./chomper.pid

#
# Failsafe mechanism. Delete a maximum of MAX_CYCLES files, raise an error after
# that. Prevents possible runaway script. Disable by choosing a high value.
#
MAX_CYCLES=100

while getopts "d:hv" flag
do
    case "$flag" in
        d) DIRECTORY=$OPTARG;;
        h) HELP=true;;
        v) echo "$VERSION"; exit 0;;
    esac
done

if [[ $HELP = true ]]; then
    show_help
    exit 0
fi

if [ $(( $# - $OPTIND )) -lt 2 ]; then
    echo "Usage: $0 [options] <mountpoint> <threshold> <delete_by_number>"
    exit 1
fi

ARG1=${@:$OPTIND:1}
ARG2=${@:$OPTIND+1:1}
ARG3=${@:$OPTIND+2:1}


show_header () {
    echo "-----------------------------------------------------"
    echo "CHOMPER v$VERSION"
    echo "$(date +%H:%M:%S): Checking volume capacity usage..."
    echo
}

show_footer () {
    echo
    echo "$(date +%H:%M:%S): Script complete"
    echo "------------------------------------------------------"
    echo
}

reset () {
    CYCLES=0
    OLDEST_FILE=""
    OLDEST_DATE=0
    ARCH=$(uname)
}

set_arguments () {
    if [ -z "$ARG1" ] || [ ! -e "$ARG1" ] || [ ! -d "$ARG1" ] || [ -z "$ARG2" ] || [ -z "$ARG3" ]
    then
        echo "Usage: $0 <mountpoint> <threshold> <delete_by_number>"
        echo "Where threshold is a percentage."
        echo
        echo "Example: $0 /storage 90 3"
        echo "If disk usage of /storage exceeds 90% the oldest"
        echo "3 file(s) will be deleted until usage is below 90%."
        echo
        echo "Wrong command line arguments or another error:"
        echo
        echo "- Directory not provided as argument or"
        echo "- Directory does not exist or"
        echo "- Argument is not a directory or"
        echo "- no/wrong percentage supplied as argument."
        echo
        exit 1
    fi
    # Directory to limit
    MOUNT=$ARG1
    if [ -z $DIRECTORY ]
    then
        echo "Directory to limit=$MOUNT"
        DIRECTORY=$MOUNT
    else
        echo "Directory to limit=$DIRECTORY"
    fi

    # Percentage of partition this directory is allowed to use
    MAX_USAGE=$ARG2
    echo "Percentage of partition this directory is allowed to use="$MAX_USAGE"%"

    # Current size of this directory
    # Directory_Size=$( du -sk "$MOUNT" | cut -f1 )
    # echo "Current size of this directory="$Directory_Size"b"

    # Total space of the partition = Used+Available
    # Disk_Size=$(( $(df $MOUNT | tail -n 1 | awk '{print $3}')+$(df $MOUNT | tail -n 1 | awk '{print $4}') ))       
    # echo "Total space of the partition="$Disk_Size"b"

    # number of files to be deleted every time the script loops (can be set to "1" if you want to be very accurate but the script is slower)
    Number_Files_Deleted_Each_Loop=$ARG3
    echo "number of files to be deleted every time the script loops="$Number_Files_Deleted_Each_Loop
}

check_capacity () {
    if ! USAGE=$(df -Pk $MOUNT | sed 1d | grep -v used | awk '{ print $5 "\t" }' | sed 's/%//g; s/[[:space:]]//g')
    then
        echo "Error: mountpoint $MOUNT not found in df output."
        exit 1
    fi

    if [ -z "$USAGE" ]
    then
        echo "Didn't get usage information of $MOUNT"
        echo "Mountpoint does not exist or please remove trailing slash."
        exit 1
    fi

    if [ "$USAGE" -gt "$MAX_USAGE" ]
    then
        echo "Usage of $USAGE% exceeded limit of $MAX_USAGE percent."
        return 0
    else
        echo "Usage of $USAGE% is within limit of $MAX_USAGE percent."
        return 1
    fi
}

process_file () {
    if [ ! -d $DIRECTORY ]
    then
        echo "$DIRECTORY does not exist"
        echo "Ending chomper.sh"
        rm $PIDFILE
        exit 1
    else
        echo "Deleting $Number_Files_Deleted_Each_Loop oldest files from \"$DIRECTORY\":"
        # we delete the files
        find $DIRECTORY -type f -not -path '*/\.*' -printf "%T@ %p\n" | sort -nr | tail -$Number_Files_Deleted_Each_Loop | cut -d' ' -f 2- | xargs -I % sh -c 'echo %; rm "%";'
        # we delete the empty directories
        EMPTY=$(find $DIRECTORY -type d -not -name 'lost+found' -empty | sed 's/ /\\ /g')
        if [ ! -z "$EMPTY" ]
        then
            if [ "$EMPTY" = "$DIRECTORY" ]
            then
                echo "$DIRECTORY is now empty"
                rm $PIDFILE
                exit 1
            else
                echo $EMPTY | xargs -t rm -rf
            fi
        fi
    fi
}

delete_loop () {
    while check_capacity
    do
        if [ "$CYCLES" -gt "$MAX_CYCLES" ]
        then
            echo "Error: after $MAX_CYCLES deleted files still not enough free space."
            exit 1
        fi

        reset

        process_file
        ((CYCLES++))
    done
}

set_arguments $ARG1 $ARG2 $ARG3
show_header
reset

if [ -f $PIDFILE ]
then
    PID=$(cat $PIDFILE)
    ps -p $PID > /dev/null 2>&1
    if [ $? -eq 0 ]
    then
        echo "An existing cron job is running for this script (PIDFILE exists). Not executing."
        exit 1
    else
        ## Process not found - assume not running
        echo $$ > $PIDFILE
        if [ $? -ne 0 ]
        then
          echo "Could not create PID file"
          exit 1
        fi
        delete_loop
    fi
else
    echo $$ > $PIDFILE
    if [ $? -ne 0 ]
    then
        echo "Could not create PID file"
        exit 1
    fi
    delete_loop
fi

show_footer
rm $PIDFILE
