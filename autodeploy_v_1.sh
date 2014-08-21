##########################################################################
# [1]:weblogic username                                                  #                                       
# [2]:weblogic password                                                  #
# [3]:ftp username                                                       #
# [4]:ftp password                                                       #
# [5]:lunix server ip                                                    #
# [6]:ftp ip                                                             #
# [7]:weblogic console url(t3://xxx)                                     #
# [8]:weblogic war package name                                          #
# [9]:if specified with '1' undeploy all wars before deploy new war      #
##########################################################################


WL_HOME='/home/haieradmin/Oracle/Middleware/wlserver_10.3'

currTime=$(date +%y-%m-%d-%H-%M-%S)
echo "************** $currTime ************" >> hopdeploy.log
echo $8 >> hopdeploy.log
echo "************** $currTime ************" >> hopdeploy.log
echo "" >> hopdeploy.log

echo "********************** begin setWLSEnv.sh *********************"
.  $WL_HOME/server/bin/setWLSEnv.sh
echo "********************** end setWLSEnv.sh *********************"
echo "*************begin weblogic.WLST--autodeploy*****************"
java weblogic.WLST $WL_HOME/server/bin/new_autodeploy.py $1 $2 $3 $4 $5 $6 $7 $8 $9
echo "*************end weblogic.WLST--autodeploy*****************"
