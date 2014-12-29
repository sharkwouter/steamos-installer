#!/bin/bash
WM="steamcompmgr"
DEBUGOPT="-v"
export DISPLAY=:0.0

if [[ "$(ps ax|grep ${WM}|head -1|cut -d":" -f2|cut -d" " -f2-)" == "$WM" ]]; then
	killall ${WM}
	${WM} -d ${DISPLAY} ${DEBUGOPT}
else
	killall ${WM}
	${WM} -d ${DISPLAY}
fi
