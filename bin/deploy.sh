# Generate one lua script with all dependencies.


#
# Filed initialization
#

#OUTPUT_FILE="./bin/telem_cat.lua" 
OUTPUT_FILE=/Users/lucianip/Documents/workspace/lua/LuacTester/sdcard/SCRIPTS/TELEMETRY/telem.lua
COMPILED_FILE=/Users/lucianip/Documents/workspace/lua/LuacTester/sdcard/SCRIPTS/TELEMETRY/telem.luac
SOURCE_FILES=" ../kissfc-tx-lua-scripts/src/common/KissProtocolSPort.lua ./src/telem.lua"

#
# Delete output existintg files
#

if test -e "$OUTPUT_FILE"; then
    rm $OUTPUT_FILE
    echo '\nDeleted' $OUTPUT_FILE
fi

if test -e "$COMPILED_FILE"; then
    rm $COMPILED_FILE
    echo '\nDeleted' $COMPILED_FILE
fi

#
# Append lua script
#

cat $SOURCE_FILES >> $OUTPUT_FILE

#
# Show Result
#

if test -e "$OUTPUT_FILE";then
	CHMOD 777 $OUTPUT_FILE
	
	echo '\nGenerated file' $OUTPUT_FILE '\n'
	
    cat $OUTPUT_FILE
else
	echo '\n' $OUTPUT_FILE '\n NOT created!!!!'
fi

echo 'Task finished'


