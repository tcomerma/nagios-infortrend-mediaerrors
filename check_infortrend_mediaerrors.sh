#!/bin/bash
# check_infortrend_mediaerrors.sh
# Nagios plugin to check for media errors in infortrend devices
#
#
# Usage: 
#
# Nov 2012
# Toni Comerma

# You have to change this to match your preferences
DIR=/usr/local/groundwork/nagios/var/check_infortrend_mediaerrors

# Variables
STATUSLINE=""
STATUS_W=0
STATUS_E=0
warning=5
critical=10
verbose=0
spawn=0

STATE_OK=0
STATE_WARNING=1
STATE_CRITICAL=2
STATE_UNKNOWN=3
SLEEP_TIME=2

# Set help
print_help () {
	echo ""
	echo "Usage: check_infortrend_mediaerrors -H <host> -w <warning> -c <critical> -v -h"
	echo "     -v Verbose"
	echo "     -H <host> Storage device address"
	echo "     -w <warning> Raise warning if more than <warning> number of errors per drive. Default: $warning"
	echo "     -c <critical> Raise warning if more than <critical> number of errors per drive. Default: $critical"
	echo "     -s Spawn check process. Usefull for slow devices when used from nagios, to avoid timeouts"
	echo "     -x Clear stored errors for host"
	echo "     -h This message"
	echo ""
	exit 0
}

get_errors () {
 # Loop event table for media errors
 eventlog=`snmptable -v 2c -m ALL -c public $host allEvtTable 2>/dev/null | grep 'Media Error'`
 while read line;
  do
    [ $verbose -eq 1 ] && echo "$line"
    # Parse error
	 evtSource=`echo $line | cut -d '"' -f 2`
	 evtSeverity=`echo $line | cut -d '"' -f 4`
	 evtIndex=`echo $line | cut -d '"' -f 5`
	 evtType=`echo $line | cut -d '"' -f 6`
	 evtCode=`echo $line | cut -d '"' -f 8`
	 evtTime=`echo $line | cut -d '"' -f 10`
    # Get info	
	date=${evtTime// /}
	date=${date//\//}
	date=${date//:/}
	slot=`expr match "$evtCode" '\([a-z,A-Z,0-9]*\)'`
	position=`expr match "$evtCode" '.*\(0x.*\) '`
	if [ ! -z "$slot" ]
	then
	  # Save it
	  touch $DIR/${host}_${slot}_${position}_${date}
	fi
  done <<<  "$eventlog"	
}

# Begin
# Parameters
if [ $# -lt 1 ]
  then 
    print_help
	exit $STATE_OK
  fi

while getopts "h:H:w:c:v:s:x" c; do
    case $c in
         h)      print_help
		         exit $STATE_OK
				 ;;
		 H)		 host=$OPTARG
				 ;;
	     w)      warning=$OPTARG
		         ;;
	     c)      critical=$OPTARG
		         ;;				 
	     v)      verbose=1
		         ;;				 
	     s)      spawn=1
		         ;;				 
		 x)      rm -f $DIR/${host}_*
		         echo "OK: cleared"
		         exit $STATE_OK
				 ;;
         *)      print_help
		         exit $STATE_ERROR
				 ;;
    esac
done


  # Launch check
  if [ $spawn = "1" ]
  then
    get_errors &
    sleep $SLEEP_TIME
  else
    get_errors
  fi
  
  # Check if it's necessary to raise an alarm
  history=`cd $DIR; find . -name "${host}_*" | cut -f 1,2 -d "_" | sort | uniq -c `
  while read num drive ;
  do
    if [ ! -z "$drive" ]
    then 
    	if [ "$num" -ge $warning -a "$num" -lt $critical ]
	  then
	    STATUS_W=$((STATUS_W + 1))
	  fi
	  if  [ "$num" -ge $critical ]
	   then
	    STATUS_E=$((STATUS_E + 1))
	   fi
	    slot=`echo $drive | cut -f 2 -d "_"`
	    STATUSLINE="$STATUSLINE $slot:$num "
	fi
  done <<< "$history"


# ending...  
if [ $STATUS_E -ge 1 ]
  then
    echo "ERROR: $STATUSLINE "
    exit $STATE_CRITICAL
  fi
if [ $STATUS_W -ge 1 ]
  then
    echo "WARNING: $STATUSLINE "
    exit $STATE_WARNING
  fi
  
echo "OK: $STATUSLINE"  
exit $STATE_OK