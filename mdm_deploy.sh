#!/bin/bash
#########################################################################################
#                                                                                       #
#  This script will create a application folder underneath the specific domain in       #
#  which located the app folder with explorered web application archieve.               #
#                                                                                       #
#  Such as:                                                                             #
#         ~/domain                                                                      #
#             `-- application                                                           #
#                      `-- webtest                                                      #
#                            |-- META-INF                                               #
#                            |   |-- MANIFEST.MF                                        #
#                            |   `-- maven                                              #
#                            |       `-- com.ws                                         #
#                            |           `-- webtest                                    #
#                            |               |-- pom.properties                         #
#                            |               `-- pom.xml                                #
#                            |-- WEB-INF                                                #
#                            |   |-- classes                                            #
#                            |   `-- web.xml                                            #
#                            `-- index.jsp                                              #
#                                                                                       #
#########################################################################################
USAGE()
{
  echo "Usage: $1 {WEBLOGIC_DOMAIN} {WEBLOGIC_USERNAME} {WEBLOGIC_PASSWORD} {WEBLOGIC_CONSOLEURL} {TARGETS} {WAR_NAME} {FTP_IP} {FTP_USERNAME} {FTP_PASSWORD}"
  echo "For example:"
  echo "  $1 /home/vom/domains/vom_domain weblogic welcome1 t3://10.135.16.42:7011 vom_app1,vom_app2,vom_app3,vom_app4 vom.2014071001.war 10.135.16.42 webftp webftp"
}
if [ "$1" = "" ]; then
  USAGE $0
  exit
fi
FUNFTP()
{
  cd $1
  if [ ! -d "application" ]; then
    mkdir application
  fi
  cd application
  if [ ! -d "$6" ]; then
    mkdir $6
  fi
  cd $6
  ftp -in $2 << SCRIPTEND
  user $3 $4
  binary
  cd ~
  get $5
  bye
SCRIPTEND
  cd $1/application/$6
  if [ -f "$5" ]; then
    echo "ftpok"
  else
    echo "ftpwrong"
    exit
  fi
}

UNPACK()
{
  cd $1/application
  if [ -d "$4" ]; then
    rm -rf $4
  fi
  mkdir $4
  mv $3/$2 $4
  rm -rf $3
  cd $4
  CDIR=`pwd`
  jar -xf $2
  rm $2
}

MDMDEPLOY()
{
  WEBLOGIC_CONSOLEURL=$1
  WEBLOGIC_USERNAME=$2
  WEBLOGIC_PASSWORD=$3
  WEBLOGIC_DOMAIN=$4
  APP_VERSION=$5 
  TARGETS=$6
  APP_NAME=$7
  OPTION=$8
  cd $WEBLOGIC_DOMAIN/bin
  . ./setDomainEnv.sh
  cd $WEBLOGIC_DOMAIN/application
  if [ ! -f current_running ]; then
    touch current_running
  fi
  cr=`cat current_running|wc -l`
  if [ $cr -gt 2 ]; then
    echo "Something wrong. 2+ current running version."
    exit
  fi
  if [ $cr -gt 1 ]; then
    oldest_version=`head -1 current_running`
    RESULT=`java weblogic.Deployer -adminurl $WEBLOGIC_CONSOLEURL -user $WEBLOGIC_USERNAME -password $WEBLOGIC_PASSWORD -name $APP_NAME -undeploy -appversion $oldest_version`
    KEYWORD="completed"
    SITRES=(`echo $RESULT | grep $KEYWORD`)
    if [ -n "$SITRES" ]; then
      sed -i '1d' current_running
      echo "undeploy "$oldest_version" succeed!"
    else
      echo "Cannot undeploy the version: "$oldest_version
      exit
    fi
  fi
  if [ "$OPTION" == 1 ]; then
    HOTRESULT=`java weblogic.Deployer -adminurl $WEBLOGIC_CONSOLEURL -user $WEBLOGIC_USERNAME -password $WEBLOGIC_PASSWORD -redeploy -name $APP_NAME -source /$WEBLOGIC_DOMAIN/application/$APP_NAME -targets $TARGETS -appversion $APP_VERSION -retiretimeout 300`
    HOTKEYWORD="completed"
    HOTSITRES=(`echo $HOTRESULT | grep $HOTKEYWORD`)
    if [ -n "$HOTSITRES" ];then
      echo $APP_VERSION >> current_running
      echo "hotdeploy "$APP_VERSION" succeed!"
    else
      echo "hotdelpoy doesn't succeed!"
    fi
  else
    NORMALRESULT=`java weblogic.Deployer -adminurl $WEBLOGIC_CONSOLEURL -user $WEBLOGIC_USERNAME -password $WEBLOGIC_PASSWORD -deploy -name $APP_NAME -source /$WEBLOGIC_DOMAIN/application/$APP_NAME -targets $TARGETS -stage -appversion $APP_VERSION`
    NORMALKEYWORD="completed"
    NORMALSITRES=(`echo $NORMALRESULT | grep $NORMALKEYWORD`)
    if [ -n "$NORMALSITRES" ]; then
      echo $APP_VERSION >> current_running
      echo "normaldelpoy "$APP_VERSION" succeed!"
    else
      echo "normaldelpoy doesn't succeed!"
    fi
  fi
}

WEBLOGIC_DOMAIN=$1
WEBLOGIC_USERNAME=$2
WEBLOGIC_PASSWORD=$3
WEBLOGIC_CONSOLEURL=$4
TARGETS=$5
WAR_NAME=$6
FTP_IP=$7
FTP_USERNAME=$8
FTP_PASSWORD=$9
if [ -z ${10} ]; then
  OPTION=""
else
  OPTION=${10}
fi

APP_NAME=${WAR_NAME%%.*}
WAR_VERSION_NAME=${WAR_NAME%.*}
APP_VERSION=${WAR_VERSION_NAME##*.}

FUNFTP $WEBLOGIC_DOMAIN $FTP_IP $FTP_USERNAME $FTP_PASSWORD $WAR_NAME $APP_VERSION
UNPACK $WEBLOGIC_DOMAIN $WAR_NAME $APP_VERSION $APP_NAME
MDMDEPLOY $WEBLOGIC_CONSOLEURL $WEBLOGIC_USERNAME $WEBLOGIC_PASSWORD $WEBLOGIC_DOMAIN $APP_VERSION $TARGETS $APP_NAME $OPTION
