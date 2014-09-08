#!/bin/bash
##########################################################################################################################
# Prerequist:                                                                                                            #
#        1. each project has its own account in the ftp server                                                           #
#        2. upload the tar archieve to the project directory under the home directory                                    #
#        3. the directory tree of the target servers to which tar archieves deploy should be like this:                  #
#           ~ (like /home/alm)                                                                                           #
#           |                                                                                                            #
#           `--alm_dubbo (This is called BASEDUBBODIR $4)                                                                #
#                  |                                                                                                     #
#                  |`-- 20140901                                                                                         #
#                  |       |                                                                                             #
#                  |       `--- alm-service-impl-4.0                                                                     #
#                  |                                                                                                     #
#                   `-- 20140902                                                                                         #
#                          |                                                                                             #
#                          `--- alm-service-impl-4.0                                                                     #
#                                                                                                                        #
# Arguments:                                                                                                             #
#          $1 -- ftp host ip                                                                                             #
#          $2 -- username of ftp server                                                                                  #
#          $3 -- password of ftp server                                                                                  #
#          $4 -- the tar path of the correspond app in the dubbo server (BASEDUBBODIR)                                   #
#          $5 -- the name of the tar archieve                                                                            #
#                                                                                                                        #
##########################################################################################################################

func_ftp() ## $BASEDUBBODIR $IP $USERNAME $PASSWORD $TARNAME $APP_VERSION
{
    appdir=$(basename $1)
    cd ~
    if [ ! -d $appdir ]; then
        mkdir $appdir
    fi
    cd $appdir
    if [ ! -d $6 ]; then
        mkdir $6
    fi
    cd $6

    ftp -ivn << !
    open $2
    user $3 $4
    binary
    cd project
    prompt
    get $5
    close
!
    if [ -f "$5" ]; then
        echo "filedownloaded."
    else
        echo "ftpfilenotexsits."
        exit 1
    fi
}

func_start() # $1=BASEDUBBODIR $2=APP_VERSION $3=tardirname
{
  echo "-----func_start begin-----"
    echo "   ---tardirname---   "
    echo "   "$3
    echo "   ---tardirname---   "
    cd $1/$2/$3/bin
    ./start.sh
    sleep 5
    DUBBOPID=`ps -ef|grep -E java |grep $1/$2/$3/conf |grep -v grep|awk '{print $2}'`
    if [ -n "$DUBBOPID" ]; then
        echo "PID exists! (^_^)"
        echo "-----func_start  end -----"
        return 0
    else
        echo "PID doesn't exist -_-#!!!"
        echo "-----func_start  end -----"
        return 1
    fi
}

func_stop() #$1=BASEDUBBODIR $2=tardirname
{
  echo "-----func_stop  start-----"
    PIDS=`ps -ef|grep java |grep $1 |grep $2 |grep -v grep|awk '{print $2}'`
    if [ -z "$PIDS" ]; then
        echo "INFO: The $2 does not started!"
        echo "-----func_stop   end -----"
        return 1
    fi
    echo "   Previous existing pids : "$PIDS
    echo -e "   Stopping the $2 ...\c"
    echo ""
    for PID in $PIDS ; do
        kill -9 $PID
        PID_CURR=`ps -f -p $PID | grep java`
        if [ -z "$PID_CURR" ]; then
          echo "   "$PID" is killed."
          break
        fi
    done

    COUNT=0
    while [ $COUNT -lt 1 ]; do    
        echo -e ".\c"
        sleep 1
        COUNT=1
        for PID in $PIDS ; do
            PID_EXIST=`ps -f -p $PID | grep java`
            if [ -n "$PID_EXIST" ]; then
                COUNT=0
                break
            fi
        done
    done
    echo "-----func_stop   end -----"
}

func_deploy() #$1=TARNAME $2=BASEDUBBODIR $3=APP_VERSION
{
    echo "-----func_deploy begin-----"
    sleep 2
    cd $2/$3
    CURRENTARDIRNAME=`echo $(tar -tvf $1 |head -1 | awk -vFPAT='\\\(.*\\\)|[^ ]+' '{print $NF}') | cut -d '/' -f 1`
    echo "  --CURRENTARDIRNAME--  "
    echo "  "$CURRENTARDIRNAME    
    echo "  --CURRENTARDIRNAME--  "
    func_stop $2 $CURRENTARDIRNAME
    tar -xf $1
    RE=`echo $?`
    if [ $RE != '0' ]; then
        echo $1"-unziperror"
        exit 1
    fi
    func_start $2 $3 $CURRENTARDIRNAME 
    ifstarted=`echo $?`
    if [ $ifstarted -eq 0 ]; then
        echo $1"-deploying-ok"
        echo ""
        echo ""
        return 0
    else
        echo $1"-deploying-failed-Exception"
        echo ""
        echo ""
        return 1
    fi
    echo "-----func_deploy  end -----"
}

func_deploy_dubbos() #$1=BASEDUBBODIR $2=APP_VERSION $3=TARNAME
{
    cd $1/$2
    
    IFEXISTSORDERFILE=noorder
    RESULTFROMGREPORDERTXT=$(tar -tvf $3 |grep order.txt)
    [[ $RESULTFROMGREPORDERTXT =~ "order.txt" ]] && IFEXISTSORDERFILE=order
    case $IFEXISTSORDERFILE in 
        "order" )
           echo "---order---"
           echo ""
           echo ""
           tar -xf $3
           RE=`echo $?`
           if [ $RE != '0' ]; then
               echo $3"-unziperror"
               exit 1
           fi
           TOTAL=$(cat order.txt | wc -l)
           OKITEM=0
           for dubbo in $(cat order.txt); do
               func_deploy $dubbo $1 $2
               RE=`echo $?`
               if [ $RE -eq 0 ]; then
                   OKITEM=$(expr $OKITEM + 1)
               fi
           done
           echo "--- =================== ---"
           echo $OKITEM
           echo $TOTAL
           echo "--- =================== ---"
           if [ $OKITEM -ne $TOTAL ]; then
               echo "Error:-Not all dubbos have been deployed-Exception"
           fi
           ;;
        "noorder" )
           echo "---noorder---" 
           echo ""
           echo ""
           func_deploy $3 $1 $2
           RE=`echo $?`
           if [ $RE -ne 0 ]; then
              echo "Error:-$3 deploying failed-Exception"
           fi
           ;;
    esac
}

# func_rollback() $1=tardirname $2=BASEDUBBODIR $3=TARNAME
# {
#     func_stop
#     cd $3
#     start
#     exit
# }

############ 1) rollback ############
# if [ $1 == "-rb" ]; then
#     BASEDUBBODIR=$2
#     TARNAME=$3
#     TARDIRNAME=$(basename $BASEDUBBODIR)
#     APP_NAME=${TARNAME%%.*}
#     TAR_VERSION_NAME=${TARNAME%.*}
#     APP_VERSION=${TAR_VERSION_NAME##*.}
#     func_rollback $TARDIRNAME $BASEDUBBODIR $TARDIRNAME
# fi

############ 2) normal deployment ############
IP=$1
USERNAME=$2
PASSWORD=$3
BASEDUBBODIR=$4
TARNAME=$5
TAR_VERSION_NAME=${TARNAME%.*}
APP_VERSION=${TAR_VERSION_NAME##*.}

func_ftp $BASEDUBBODIR $IP $USERNAME $PASSWORD $TARNAME $APP_VERSION
func_deploy_dubbos $BASEDUBBODIR $APP_VERSION $TARNAME