#!/bin/bash

BASEDIR=$(dirname "$0")
MACRO_PATH="$BASEDIR/macros/"
MACRO_NAME="macro"
DEVICE_SPECIFIER=""

add_to_device_script() {
    echo -e "$1" >> "$MACRO_PATH/$MACRO_NAME"
}

hex_to_decimal() {
    hex_value=$(echo "$1" | grep -oE '[0-9a-fA-F]+')
    printf "%d\n" "$((16#$hex_value))"
}

record_macro() {
    tmp_file="$BASEDIR/output.txt"
    echo "Recording '$MACRO_NAME'... Press CTRL+C when finished."
    adb $DEVICE_SPECIFIER shell getevent -t > $tmp_file
    # Remove first 8 lines that is headers
    sed -i '1,8d' $tmp_file
    create_macro_script $tmp_file
    rm $tmp_file
}

play_macro() {
    adb $DEVICE_SPECIFIER root
    adb $DEVICE_SPECIFIER push "$MACRO_PATH/$MACRO_NAME" /mnt/sdcard/
    adb $DEVICE_SPECIFIER shell sh /mnt/sdcard/$MACRO_NAME
    adb $DEVICE_SPECIFIER shell rm /mnt/sdcard/$MACRO_NAME
}

create_macro_script() {
    file=$1
    last_timestamp=""
    echo "Creating script file..."
    while read input; do
        # Extracting the timestamp
        timestamp=$(echo "$input" | sed -E 's/^\[\s*([^]]+)\].*/\1/')

        # Extracting the remaining string
        input_str=$(echo "$input" | awk -F'] ' '{print $2}')
        input_str=$(echo $input_str | sed -e 's/://g')

        if [ ! -z $last_timestamp ]; then
            time_difference=$(awk "BEGIN {print $timestamp - $last_timestamp}")
            if [[ "$time_difference*10" > 0 ]]; then
                add_to_device_script "sleep $time_difference"
            fi 
        fi

        last_timestamp=$timestamp

        # Split the values into separate variables
        read var1 var2 var3 var4 var5 <<< "$input_str X"

        #convert var 2 3 and 4 to int
        var2="$(hex_to_decimal $var2)"
        var3="$(hex_to_decimal $var3)"
        var4="$(hex_to_decimal $var4)"

        args="$var1 $var2 $var3 $var4"
        add_to_device_script "sendevent $args"
    done <$file
    echo "Script ready"
}

displayUsage() {
    echo $1
    echo ""
    echo "Usage: adb-recorder"
    echo -e "\t--record: Record new macro"
    echo -e "\t--play: Play existing macro on device"
    echo -e "\t--name <NAME>: Define name of macro to be recorded/played"
    echo -e "\t--device <DEVICE_ID>: Define device identifier to run on"
}

if [ $# = 0 ]; then
    displayUsage
fi

# GET ARGUMENTS
while (( "$#" )); do

    case "$1" in
        # Options with additionnal args 
        "--name")
            MACRO_NAME=$2
            shift
            ;;
        "--device")
            DEVICE_SPECIFIER="-s $2"
            shift
            ;;
        # Options without args
        "--record")
            record=1
            ;;
        "--play")
            play=1
            ;;
        "--remove")
            remove=1
            ;;
        "--list")
            list=1
            ;;
        *)
            displayUsage
            exit 1
            ;;
    esac
    
    shift
done


# if [ ! -z $remove ]; then
#     # To be implemented
# fi

# if [ ! -z $list ]; then
#     # To be implemented
# fi

if [ ! -z $record ]; then
    record_macro
fi

if [ ! -z $play ]; then
    play_macro
fi