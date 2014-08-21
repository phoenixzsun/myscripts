#!/bin/sh
##########################################################################
# Prequist:                                                              #
#        1. the archieve is put in the home directory of the specified   #
#     user in the ftp server.                                            #
#                                                                        #
#                                                                        #
# Arguments:                                                             #
#                                                                        #
#       $1 the correspond tomcat home path                               #
#       $2 the application package will be deployed                      #
#       $3 the ip address of the ftp server                              #
#       $4 the account name of the ftp server                            #
#       $5 the password of the specified account in the ftp server       #
#       $6 the url used to testify if the server starts perfectly        #
#                                                                        #
#                                                                        #
# By the way:                                                            #
#       Whether the application archieve is packaged in the .war format  #
#    or the .zip format, this script will handle.                        #
#       the package will be downloaded to the ~/ftpdir directory         #
#                                                                        #
#                                                                        #
#                                                                        #
#                                                                        #
#                                                                        #
##########################################################################

getFileByFtp()
{
	cd ~
	homedir=`pwd`
	if [ ! -d "ftpdir" ]; then
		mkdir ftpdir
	fi
	ftp -in $1 << SCRIPTEND
	user $2 $3
	binary
	cd ~
	lcd $homedir/ftpdir
	get $4
	bye
SCRIPTEND
	cd ~/ftpdir
	if [ -f "$4" ]; then
		echo "Filedownloaded."
	else
		echo "FileNotFound."
	if
}

waitForTomcatToDie()
{
	PROCESSES=`ps auxwww | grep 'tomcat' | grep $1 | grep -v 'grep' |grep -v 'tomcat_deploy.sh'`
	while [ ! -z "$PROCESSES" ] && [ $SECONDS -lt $TIMELIMIT ] && [ $TIMELIMIT -ne 0 ]; do
		echo -n "."
		sleep $SLEEPTIME
		PROCESSES=`ps auxwww | grep 'tomcat' | grep $1 | grep -v 'grep' |grep -v 'tomcat_deploy.sh'`
	done
	echo ""
	if [ ! -z "$PROCESSES" ]; then
		PROCESS_ID=`echo $PROCESSES | awk '{ print $2 }'`
		echo "Killing process: $PROCESS_ID"
		kill -9 $PROCESS_ID
		if [ $? -eq 0 ]; then
			echo "BeenKilled!"
		fi
	else
		echo "tomcat shutdowns"
	fi
}

waitForTomcatToStart()
{
	while [ $(expr $SECONDS - $3) -lt $STARTTIMEOUT ]; do
		sleep $STARTSLEEPTIME
		HTTPCODE=$(expr $(curl -s -o /dev/null -m 10 --connect-timeout 5 "$2" -w %{http_code}))
		if [ $(expr $HTTPCODE) -eq 302 -o $(expr $HTTPCODE) -eq 200 ]; then
			echo "Started!!"
			break
		fi
	done
		
}

unpack()
{
	tmpname=$2
	appdir=${tmpname%%.*}
	echo $appdir
	cd ~
	homedir=`pwd`
	webappsdir=$1/webapps
	if [ "$3" == "" ]; then
		cd $webappsdir
		if [ ${tmpname##*.} == "war" ]; then
			if [ -d "$appdir" ]; then
				rm -rf $appdir
			fi
			cp $homedir/ftpdir/$2 $appdir.war
		fi
		if [ ${tmpname##*.} == "zip" ]; then
			if [ -d "$appdir" ]; then
				rm -rf $appdir
			fi
			unzip $homedir/ftpdir/$2 -d $appdir
		fi
	fi
	if [ -n "$3" ]; then
		cd $3
		if [ ${tmpname##*.} == "war" ]; then
			if [ -d "$appdir" ]; then
				rm -rf $appdir
			fi
			cp $homedir/ftpdir/$2 $appdir".war"
		fi
		if [ ${tmpname##*.} == "zip" ]; then
			if [ -d "$appdir" ]; then
				rm -rf $appdir
			fi
			unzip $homedir/ftpdir/$2 -d $appdir
		fi
	fi
}

############################ script starts from here ###############################
# set TIME OUT values
TIMELIMIT=10
STARTTIMEOUT=180
SLEEPTIME=1
STARTSLEEPTIME=3

# arguments sent by java 
THOME=$1 ##################### the correspond tomcat home path
ARCHIEVENAME=$2 ############## the application package will be deployed
FTPHOSTIP=$3 ################# the ip address of the ftp server
FTPUSERNAME=$4 ############### the account name of the ftp server
FTPPASSWORD=$5 ############### the password of the specified account
CHECKURL=$6 ################## the url will be curled
SPECIFICPATH ################# the external path where application will be deployed, 
# default is in the webapps directory which is underneath the tomcat home directory

################# 0. retrieve the archieve from the ftp server #####################

RESULT=`getFileByFtp $1 $2 $3 $4`
SIT1="Filedownloaded"
SIT2="FileNotFound"
REQ1=(`echo $RESULT | grep $SIT1`)
REQ2=(`echo $RESULT | grep $SIT2`)
if [ -n "$REQ1" ]; then
	echo "ftpgood"
fi
if [ -n "$REQ2" ];then
	echo "ftpwrong"
fi
 
########################### 1. stop the tomcat instance ############################
# Only the tomcat instance has been started, we stop the tomcat instance
PROCESSEXSITS=`ps auxwww | grep 'tomcat' | grep $1 | grep -v 'grep' |grep -v 'tomcat_deploy.sh'`
if [ -n "$PROCESSEXSITS" ]; then
	NOSHOW=`$THOME/bin/shutdown.sh`
	# Function to wait until all Tomcat processes are killed
	#waitForTomcatToDie $THOME
	RESULT=`waitForTomcatToDie $THOME`
	SIT1="shutdowns"
	SIT2="BeenKilled!"
	REQ1=(`echo $RESULT | grep $SIT1`)
	REQ2=(`echo $RESULT | grep $SIT2`)
	if [ -n "$REQ1" ]; then
		echo "shutdown"
	fi
	if [ -n "$REQ2" ]; then
		echo "killed--"
	fi
else
	echo "Tomcathasn'tstarted!"
fi

############################### 2. unpack the archieve #############################
unpack $THOME $ARCHIEVENAME $SPECIFICPATH
########################## 3. start the tomcat instance ############################
CURRENTUSEDTIME=$SECONDS
NOSHOW=`$THOME/bin/startup.sh`
waitForTomcatToStart $THOME $CHECKURL $CURRENTUSEDTIME
