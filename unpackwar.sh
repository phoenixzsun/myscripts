#!/bin/bash
#############################################################################################
#                                                                                           # 
#    $1 -- war file name                                                                    # 
#    $2 -- the path of the war file                                                         # 
#    $3 -- the jetty home directory                                                         # 
#    $4 -- ftp ip address                                                                   # 
#    $5 -- ftp username                                                                     # 
#    $6 -- ftp password                                                                     # 
#    $7 -- check url                                                                        # 
#                                                                                           # 
#    Note:                                                                                  # 
#        the path of the war file is like this:                                             # 
#                                                                                           # 
#            ~/project                                                                      # 
#                                                                                           # 
#############################################################################################

FTPFUNC()
{
        if [ -e $5 ]; then
           echo "Things go well."
        else
           echo "The path specified doesn't exist!"
           mkdir -p $5
           echo "It exisits now!"
        fi
	cd $5
	if [ -f "$4" ]; then
            rm $4
	fi
	ftp -in $1 << SCRIPTEND
	user $2 $3
	binary
	cd ~/project
	lcd $5
	get $4
	bye
SCRIPTEND
	cd $5
	if [ -f "$4" ]; then
		echo "Filedownloaded."
	else
		echo "ftpfilenotexsits"
                exit 1
	fi
}
REMOVELASTVERSION()
{
    cd $1
    if [ -d "$2" ]; then
	rm -rf $2
    fi
}
UNPACKCURRENTVERSION()
{
    cd $1
    if [ ! -d "$3" ]; then
        echo "dir not exists!"
        mkdir $3
    fi
    mv $2 $3
    cd $3
    jar -xvf $2
    RE=`echo $?`
    if [ $RE != '0' ]; then
        echo "unpackwrong"
        rm $2
        exit 1
    fi
    rm $2
}
RESTARTJETTY()
{
    cd $1/bin
    ./jetty.sh restart
}
WAITFORAPPTOSTART()
{
	while [ $(expr $SECONDS - $2) -lt $STARTTIMEOUT ]; do
		sleep $STARTSLEEPTIME
		HTTPCODE=$(expr $(curl -s -o /dev/null -m 10 --connect-timeout 5 "$1" -w %{http_code}))
		if [ $(expr $HTTPCODE) -eq 302 -o $(expr $HTTPCODE) -eq 200 ]; then
			echo "wearehappynow"
			exit
		fi
	done

	echo "nothappywiththat"
}
WARFILE=$1
WARFILEPATH=$2
JETTYHPATH=$3
FTPIP=$4
FTPUSERNAME=$5
FTPPASSWORD=$6
APPABBR=${WARFILE%%.*}
WARPATH=$2/$APPABBR
CHECKURL=$7
STARTTIMEOUT=30
STARTSLEEPTIME=2
# step 0 get file through ftp
FTPFUNC $FTPIP $FTPUSERNAME $FTPPASSWORD $WARFILE $WARFILEPATH
# step 1 remove the last version
REMOVELASTVERSION $WARFILEPATH $APPABBR
# step 2 unpack the current version
UNPACKCURRENTVERSION $WARFILEPATH $WARFILE $APPABBR
# step 3 restart jetty
RESTARTJETTY $JETTYHPATH
# step 4 check if app is available
CURRENTUSEDTIME=$SECONDS
WAITFORAPPTOSTART $CHECKURL $CURRENTUSEDTIME
