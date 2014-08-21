#!/bin/bash
##########################################################################################################################
# Prequist:                                                                                                              #
#        1. each project has its own account in the ftp server                                                           #
#        2. upload the tar archieve to the home directory of the ftp server                                              #
#        3. the directory organization of the target servers to which tar archieves deploy should be like this:          #
#           ~                                                                                                            #
#           |------alm                                                                                                   #
#           |       |------alm-service-impl-4.0                                                                          #
#           |       |------backup_of_last_version                                                                        #
#           |------oms                                                                                                   #
#                   |------oms-service-impl-4.0                                                                          #
#                   |------backup_of_last_version                                                                        #
#                                                                                                                        #
#        4. the content of the tar archieve would be like this:                                                          #
#           ****.tar                                                                                                     #
#           |                                                                                                            #
#           |------***-service-impl-4.0                                                                                  #
#                           |                                                                                            #
#                           |------bin                                                                                   #
#                           |                                                                                            #
#                           |------conf                                                                                  #
#                           |                                                                                            #
#                           |------lib                                                                                   #
#                                                                                                                        #
# Arguments:                                                                                                             #
#          $1 -- ftp host ip                                                                                             #
#          $2 -- username of ftp server                                                                                  #
#          $3 -- password of ftp server                                                                                  #
#          $4 -- the tar path of the correspond app in the dubbo server                                                  #
#          $5 -- the name of the tar archieve                                                                            #
#                                                                                                                        #
##########################################################################################################################
funFtp()
{
    basedir=`basename $4`
    cd ~
    if [ ! -d "$basedir" ]; then
        mkdir $basedir
    fi
    ftp -in $1 << SCRIPTEND
	user $2 $3
	binary
	cd ~
	lcd $4
	get $5
	bye
SCRIPTEND
	cd $4
	if [ -f "$5" ]; then
		echo "Filedownloaded."
	else
		echo "FileNotFound."
	fi
}
stop()
{
    cd $1
    if [ -d "$2" ]; then
        cd $2/bin
        result=`./stop.sh`
        situation1="OK!"
        situation2="started!"
        req1=(`echo $result | grep  $situation1`)
        req2=(`echo $result | grep  $situation2`) 
        if [ -n "$req1" ]; then
            echo "-0-- stopped!"  
        elif [ -n "$req2" ]; then  
            echo "-1-- hasn't started!"  
        fi
    fi
}
unpack()
{
    cd $1
    if [ -d "backup_of_last_version" ]; then 
        rm -rf backup_of_last_version
    fi
    if [ -d "$3" ]; then
        mv $3 backup_of_last_version
    fi
    tar -xf $2 -C $1
}
start()
{
    cd $1/$2/bin
    chmod +x *.sh
    ./start.sh
    DUBBOPID=`ps -ef|grep -E java |grep $1/$2/conf |grep -v grep|awk '{print $2}'`
    if [ -n "$DUBBOPID" ]; then
        echo "PID exists! (^_^)"
    else
        echo "PID doesn't exist -_-#!!!"
    fi
    #result=`./start.sh`
    #result=`$1/$2/bin/start.sh`
    #situation1="OK!"
    #situation2="started!"
    #situation3="port"
    #req1=(`echo $result | grep $situation1`)
    #req2=(`echo $result | grep $situation2`) 
    #req3=(`echo $result | grep $situation3`) 
    #if [ -n "$req1" ]; then
    #    echo "-0-- starting succeeds!"  
    #else 
    ##    if [ -n "$req2" ]; then  
    #        echo "-1-- already started!"  
    #    fi 
    #    if [ -n "$req3" ]; then  
    #        echo "-2-- port already used!"  
    #    fi 
    #fi
}

######################### script starts from here ################################

###############################################
echo "*************" >> hopdeploy.log
currTime=$(date +%y-%m-%d-%H-%M-%S)
echo $currTime >> hopdeploy.log
echo $1-$2-$3-$4-$5 >> hopdeploy.log
echo "*************" >> hopdeploy.log
echo "" >> hopdeploy.log
echo "" >> hopdeploy.log
echo "" >> hopdeploy.log
################################################

ftphost=$1
ftpuser=$2
ftppass=$3
tarhome=$4 # such as, /home/${dubbohost}/alm
tarname=$5

tarabbr=`basename $tarhome`
ftpLocalPath=~/$tarabbr
tardir=$tarabbr"-service-impl-4.0"

# 0. retrieve the file from ftp server
FTPRESULT=`funFtp $ftphost $ftpuser $ftppass $ftpLocalPath $tarname`
S1="Filedownloaded"
S2="FileNotFound"
R1=(`echo $FTPRESULT | grep $S1`)
R2=(`echo $FTPRESULT | grep $S2`)
if [ -n "$R1" ]; then
    echo "FTPOK"
fi
if [ -n "$R2" ]; then
    echo "FTP: file not exists."
    exit 1
fi
# 1. stop the currently running tar
stop $tarhome $tardir
# 2. untar the new tar and backup the stopped tar
unpack $tarhome $tarname $tardir
# 3. start the new tar
start $tarhome $tardir
