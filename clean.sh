#!/bin/sh

# https://www.commandlinefu.com/commands/view/11560/delete-all-non-printing-characters-from-a-file
# http://www.skybert.net/bash/adding-utf-8-bom-from-the-command-line/

# Remove non-printable ASCII characters 
tr -cd '[:print:]\n\r' < ./Experts/JsonAPI.mq5 > ./Experts/JsonAPI.clean.mq5
# Add UTF-8 BOM
sed -i '1s/^/\xef\xbb\xbf/' ./Experts/JsonAPI.clean.mq5
mv ./Experts/JsonAPI.clean.mq5 ./Experts/JsonAPI.mq5


