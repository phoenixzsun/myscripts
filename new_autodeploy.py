##############################################################################
#                                                                            #
# argv[1]:weblogic username                                                  #                                       
# argv[2]:weblogic password                                                  #
# argv[3]:ftp username                                                       #
# argv[4]:ftp password                                                       #
# argv[5]:lunix server ip                                                    #
# argv[6]:ftp ip                                                             #
# argv[7]:weblogic console url(t3://xxx)                                     #
# argv[8]:weblogic war package name                                          #
# argv[9]:if specified with '1' undeploy all wars before deploy new war      #
# ------- bug tracking message                                               #
# ******* exception message                                                  #
##############################################################################

import sys
import re
import os
from ftplib import FTP

###################################### Define Functions #######################################
def __ftp(linuxIp, ftpUsername, ftpPassword, packageName):
    ftp=FTP()
    try:
        ftp.connect(linuxIp,21)
    except:
        ftp.close()
    	return 1
    try:
        ftp.login(ftpUsername,ftpPassword)
    except:
        ftp.close()
   	return 2 
    fp=open('/home/haieradmin/tmpfile/'+packageName,'wb')
    try:
        ftp.retrbinary('RETR '+packageName,fp.write,1024)
    except:
        ftp.close()
    	return 3
    fp.close()
    return 0
    print '------- ftp operation completed.'

def __undeploy(appName):
    try:
        print '------- Stopping application ' + appName
        wlstProcess = stopApplication(appName)
        print '------- print WLSTProcess:'
        print wlstProcess.getCommandType()
        print wlstProcess.getMessage()
        print '------- Undeploying ' + appName
        edit()
        startEdit()
        wlstProcess = undeploy(appName, timeout=60000)
        save()
        activate()
        print '------- print WLSTProcess:'
        print wlstProcess.getCommandType()
        print wlstProcess.getMessage()
    except Exception, e:
        print '******* Deployment ' + appName + ' removal failed.'
        exit()

def __deploy(package, packagePath, webArchiveName, packageVersion, appServer):
    import time
    time.sleep(5)
    try:
        print '------- Deploying ' + package
        edit()
        startEdit()
        wlstProcess = deploy(package,packagePath+'/'+webArchiveName,archiveVersion=packageVersion,targets=appServer,stageMode='stage',upload='true',timeout=3600000)
        save()
        activate()
        print '------- print WLSTProcess:'
        print wlstProcess.getCommandType()
        print wlstProcess.getMessage()
    except:
        print '******* Deploy ' + package + '.' + packageVersion + 'failed.'
        exit()

def __redeploy(package, packagePath, webArchiveName, packageVersion):
    import time
    time.sleep(5)
    try:
        print '------- Redeploying ' + package
        wlstProcess = redeploy(package,appPath=packagePath+'/'+webArchiveName,archiveVersion=packageVersion,stageMode='stage',upload='true',timeout=3600000)
        print '------- print WLSTProcess:'
        print wlstProcess.getCommandType()
        print wlstProcess.getMessage()
    except:
        print '******* Redeploy ' + package + '.' + packageVersion + 'failed.'
        exit()

############################################# Functions over ##################################################

##################################################################
#                                                                #
#             SCRIPT STARTS FROM HERE   (~O'_'O~)                #
#                                                                #
##################################################################


weblogicName          =    sys.argv[1]
weblogicPassword      =    sys.argv[2]
ftpUsername           =    sys.argv[3]
ftpPassword           =    sys.argv[4]
linuxIp               =    sys.argv[5]
ftpIp                 =    sys.argv[6]
weblogicConsoleUrl    =    sys.argv[7]
packageName           =    sys.argv[8]
if (len(sys.argv)) > 9:
    option            =    sys.argv[9]

######################## ftp operation #########################
ftpResult = __ftp(ftpIp, ftpUsername, ftpPassword, packageName)
if ftpResult != 0:
    if ftpResult == 1:
        print '*******1ftpserverip'
    if ftpResult == 2:
        print '*******1ftpuserorpass'
    if ftpResult == 3:
        print '*******1ftpfilenotexsits'
    exit()

###################### analysing packages ######################
i=packageName.find(".")
j=packageName.rfind(".")
package=packageName[0:i]
packageVersion=packageName[int(i)+1:j]

print '------- Package needs to be deployed:'
print '------- packageName: ' + package
print '------- packageVersion: ' + packageVersion

print ''
####################### WLST operation #######################
try:
    connect(weblogicName,weblogicPassword,weblogicConsoleUrl)
except:
    print '******* WLST connectting failed.'
    exit()

par=re.findall('AdminServerName\s+\S+',ls()) ###[AdminiServerName    oms_admin]
par=par[0].split(' ')
adminServerName=par[len(par)-1]
print '------- AdminSererName:'
print adminServerName

# List all servers including managing server and managed servers
par=ls('/Servers')
par=par.replace('\n','').replace('dr--','')
allServers=re.findall('\w+',par)
print '------- All servers:'
print allServers

# List all managed servers
appServer=""
for tempAppServer in allServers:
   if tempAppServer!=adminServerName:
      if appServer=="":
         appServer=tempAppServer
      else:
         appServer += "," + tempAppServer

print '------- AppServerName: ' + appServer

# Whether the last deployment type is hot-deployment or deployed handly, both work
appList =  re.findall(package + '#\S*', ls('AppDeployments'))
appListAll = re.findall('\\b' + package + '\\b', ls('AppDeployments'))
if len(appListAll) > len(appList):
    appList.append(package)
print 'Previous deployed packages:'
print appList
packagePath = '/home/haieradmin/tmpfile'

# arguments < 5
if len(sys.argv) < 6:
    print '------- Arguments less than 5!!!'
    exit()

if len(sys.argv) == 10 and option == "1":
    for i in range(len(appList)):
        __undeploy(appList[i])
    __deploy(package, packagePath, packageName, packageVersion, appServer)
elif len(sys.argv) == 10 and option[:7] == ",,,...@":
    servers = appServer.split(",")
    appTargets = option[7:].strip().split(',')
    appTarget = ""
    if len(appTargets) > 0:
        for item in appTargets:
            if item in servers:
                if appTarget == "":
                    appTarget += item
                else:
                    appTarget += "," + item
    if appTarget != "":
        if len(appList) > 0:
            for i in range(len(appList)):
                __undeploy(package)
            __deploy(package, packagePath, packageName, packageVersion, appTarget)
	else:
	    __deploy(package, packagePath, packageName, packageVersion, appTarget)
    else:
        print 'Wrong appServer name. Please use the format--- ,,,...@appServer'
        exit()
else:
    if len(appList) >= 2:
        print '------- more than 1 deployed packages found,'
        print '------- Now deleting one...'
        __undeploy(appList[0])
        __redeploy(package, packagePath, packageName, packageVersion)
    elif len(appList) == 1:
        print '------- one deployed package found,'
        print '------- Now redeploy...'
        __redeploy(package, packagePath, packageName, packageVersion)
    else:
        print '------- no deployed packages found,'
        print '------- Now deploying...'
        __deploy(package, packagePath, packageName, packageVersion, appServer)

if option == "1":
    print '------- Deployment succeeds with "1".'
else:
    print '------- Deployment succeeds without "1".'
exit()
