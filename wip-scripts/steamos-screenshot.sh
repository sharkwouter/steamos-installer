#!/bin/bash

#set variables
DIR=~/Pictures
STARTNAME=Screenshot
FORMAT=png
RES="`xrandr -d :0 --prop|grep \ connected|head -1|awk '{print $3}'`"
WID="`xwininfo -tree -display :0 -root|grep $RES|head -1|awk '{print $1}'`"

# make screenshot directory if it doesn't exist yet
if [ ! -d ${DIR} ] 
then
	mkdir $DIR
fi

# set name of the screenshot
NUMBER=1
while [ -f $DIR/$STARTNAME$NUMBER.$FORMAT ]
do
	NUMBER=$(($NUMBER+1))
done
NAME=$STARTNAME$NUMBER

#take the screenshot
import -display :0 -window $WID $DIR/$NAME.$FORMAT
