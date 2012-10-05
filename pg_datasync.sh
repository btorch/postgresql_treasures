#!/bin/bash

# Info:
#
# Created by Marcelo Martins
# Date: 2009-05-05
#
# Last Changed: 
#       2009-10-13, 2009-10-08, 2009-06-22, 2009-05-07
#
# Info:
#      - Peforms a Base Backup of PGDATA from SOURCE to DEST node.
#      - It also allows you to setup a WAL shipping relation between 
#        SOURCE and DESTINATION once the base backup is completed.
#
#      * Currently only supports pg_xlog as a link 
#        tablespaces or any other links are not supported 
#
# Usage: 
#      pg_datasync.sh [OPTIONS] -d <DEST NODE IP> 
#
# Recommended: 
#      - Rsync 3.0.5 or later 
#
# Required options: 
#      -d  DEST_IP  Destination node IP address 
#
# Suplemental options: 
#      -V  PG_VERSION  Optional user specified PG Version (default 8.3) 
#      -S  Starts remote PG service onto online mode 
#      -w  Sets up log shipping between SOURCE and DESTINATION nodes 
#          overrides flags -S if set 
#      -v  Verbose output to stdout screen (no logging) 
#      -h  Provides this help screen 
#
# --------- IMPORTANT NOTICES BELOW, PLEASE READ ---------
#
# PLEASE NOTE: 
#      The PostgreSQL service on destination node 
#      is started up in recovery mode by default 
#
# Requirements:
# 	
#	- script must be run as the "postgres" user and SSH key authentication must be 
#	  setup between SRC and DEST nodes
#
#   - You MUST setup the PG_XLOG_DIR and WALSHIPPING_DIR parameters below 
#     if you are using links to either one
#
# 	- If you choose SYNC_METHOD to be rsync you must have the rsyncd daemon 
#	  properly configured and running on the receiving end (DEST NODE)
#	  The rsync module "pgdata" must also be write enabled
#     **** ONLY SYNC_METHOD SUPPORTED AT THIS TIME IS RSYNC ****  
#
# TODO_LIST: 
#
#   - Check if mail app is installed 
#
#   - Implement support for Redhat, SuSE and Solaris
#
#	- Check destination postgresql log to see when database is accepting connection 
#     when the ONLINE MODE is requested 
#
#   - Check what PostgreSQL version is installed and currently active and compare
#     that with the default value in PG_VERSION variable or whatever provided by -V flag (DONE)
#



###########################
# CONFIGURABLE VALUES
###########################

# Data Sync Transfer Method
# Only rsync is now supported 
SYNC_METHOD="rsync"

# If using PG 8.3 the timeout below may need to be over 30s
# If the timeout valule chosen does not work to bring the 
# destination into online mode when -S flag is specified 
# the manual creation of the trigger file will be required 
FAILOVER_TIMEOUT="30"

# NOTE: 
#  The parent directory where the PG_XLOG_DIR or WALSHIPPING_DIR folder 
#  is located MUST be owned by the postgres user/group 
#
# If using a symbolic link for the walshipping folder, one MUST specify 
# the absolute path of the directory the link will point to otherwise leave empty
# e.g: WALSHIPPING_DIR="/mnt/disk2/walshipping" 
WALSHIPPING_DIR="/mnt/disk3/walshipping" 

# If using a symbolic link for the pg_xlog folder, one MUST specify 
# the absolute path of the directory the link will point to otherwise leave empty
# e.g: PG_XLOG_DIR="/mnt/disk2/pg_xlog"
PG_XLOG_DIR="/mnt/disk2/pg_xlog"

# Trigger file location (postgres user must be able to create/remove file)
TRIGGER_FILE="/tmp/pgsql.trigger.5442"

# Email addresses used by the mail_warnning function 
# Separated by commas
EMAIL_ADDRESS=""



###########################
# FUNCTIONS
###########################


#---------------------------------------
# Function for displyaing proper usage 
usage_display() {
   msg="\n"
   msg=${msg}"\n\t Usage: "
   msg=${msg}"\n\t\t pg_datasync.sh [OPTIONS] -d <DEST NODE IP> "
   msg=${msg}"\n"
   msg=${msg}"\n\t Required options: "
   msg=${msg}"\n\t\t -d DEST_IP \t Destination node IP address "
   msg=${msg}"\n"
   msg=${msg}"\n\t Suplemental options: "
   msg=${msg}"\n\t\t -V PG_VERSION \t Optional user specified PG Version (default 8.3) "
   msg=${msg}"\n\t\t -S \t\t Starts remote PG service onto online mode "
   msg=${msg}"\n\t\t -w \t\t Sets up log shipping between SOURCE and DESTINATION nodes "
   msg=${msg}"\n\t\t    \t\t overrides flags -S if set "
   msg=${msg}"\n\t\t -v \t\t Verbose output to stdout screen (no logging) "
   msg=${msg}"\n\t\t -h \t\t Provides this help screen "
   msg=${msg}"\n"
   msg=${msg}"\n\t Please note that PG service on destination node "
   msg=${msg}"\n\t is started up in recovery mode by default "
   msg=${msg}"\n"
   msg=${msg}"\n\t If using symbolic links you MUST configure the "
   msg=${msg}"\n\t WALSHIPPING_DIR & PG_XLOG_DIR parameters within the script "
   msg=${msg}"\n"
   echo -e ${msg}
}


#----------------------------------------
# Function for setting up stderr/stdout 
# redirection for logging purposes
log_setup() {

LOGFILE=/var/log/postgresql/pg_hotsync.log
LOGERR=/var/log/postgresql/pg_hotsync.err

if [ ! -e $LOGFILE ]; then
   touch $LOGFILE
fi

if [ ! -e $LOGERR ]; then
   touch $LOGERR
fi

exec 6>&1           # Link file descriptor #6 with stdout. Saves stdout.
exec >> $LOGFILE    # stdout replaced with file $LOGFILE.
exec 7>&2           # Link file descriptor #7 with stderr. Saves stderr
exec 2>> $LOGERR    # stderr replaced with file $LOGERR.

}


#-----------------------------------
# Function for checking IP address
# provided and validate it 
# Returns 0 = valid , 1 = invalid
ip_check () {

IP="$1"
TEST=`echo "${IP}." | grep -E "([0-9]{1,3}\.){4}"`

if [ -n "$TEST" ]; then 

  CHECK_RESULT=`echo "$IP" | awk -F. '{ if ( (($1>=0) && ($1<=255)) && (($2>=0) && ($2<=255)) && (($3>=0) && ($3<=255)) && (($4>=0) && ($4<=255)) ) { print(0); } else { print(1); } }'`

else
  echo "Error: ip_check failed, variable not set"
  exit 1
fi

return $CHECK_RESULT

}


#-------------------------------------------------
# Function for setting some PG related variables 
# according to the PG version
set_postgres_vars () {

PG_VERSION=$1 
PG_VARS_SET=1

if [ "$PG_VERSION" != "8.3" ] && [ "$PG_VERSION" != "8.4" ]; then 

   msg="\n\t Sorry, but PostgreSQL Version $PG_VERSION is not supported since it has not been tested against "
   msg=${msg}"\n\t You are welcome to try it out, but first modify \"set_postgres_vars\" function "
   msg=${msg}"\n"

   echo -e ${msg}
   exit 1  
fi

# Source node
SRC_PGDATA="/var/lib/postgresql/$PG_VERSION/main"

# Destination node
DEST_PGDATA="/var/lib/postgresql/$PG_VERSION/main"

# Destination Walshiping path
WALSHIPPING="/var/lib/postgresql/$PG_VERSION/walshipping"

# Location of postgresql configuration file
PGCONF="/etc/postgresql/$PG_VERSION/main/postgresql.conf"

# PostgreSQL init script
PG_INIT="/etc/init.d/postgresql-$PG_VERSION"

# PostgreSQL Standby script
PG_STDBY="/usr/lib/postgresql/$PG_VERSION/bin/pg_standby"


# Check that PID exists for PostgreSQL version 
if [ ! -e $SRC_PGDATA/postmaster.pid ]; then 
   echo -e "\n\t ERROR: "
   echo -e "\t - Could not find PostgreSQL $PG_VERSION running on source "
   echo -e "\t - Please make sure you are specifying correct version \n"
   exit 1
fi 

}


#-----------------------------------------------------------------
# Function for parsing the option arguments passed to the script
# uses getopts for parsing the flags
parse_args () {

DEST_NODE=
LOG_SHIPPING_MODE=0
ONLINE_MODE=0
PG_VARS_SET=0
PG_VERSION="8.3"
VERBOSE=0

while getopts "hwsSV:d:v" OPTION 
do 
  case $OPTION in 
    h) 
        usage_display
        exit 1 
        ;;
    v)
        VERBOSE=1
        ;;
    w)
        LOG_SHIPPING_MODE=1
        if [ "$ONLINE_MODE" = "1" ]; then 
            echo -e "\n\t Sorry, -S flag cannot be used along with -w flag "
            usage_display 
            exit 1
        fi
        ;;
    S)
        ONLINE_MODE=1
        if [ "$LOG_SHIPPING_MODE" = "1" ]; then 
            echo -e "\n\t Sorry, -w flag cannot be used along with -S flag "
            usage_display
            exit 1
        fi
        ;;
    V)  
        PG_V=$OPTARG
        set_postgres_vars $PG_V
        ;;
    d)
        ip_check $OPTARG
        IP_CHECK_RESULT=$?
        if [ $IP_CHECK_RESULT -eq 0 ]; then
            DEST_NODE=$OPTARG
        else
            echo -e "\n\t Invalid IP address ... "
            usage_display
            exit 1
        fi
        ;;
    ?)
        usage_display
        exit 1
        ;;
  esac  
done 

if [ -z "$DEST_NODE" ]; then 
  echo -e "\n\t No destination IP provided "
  usage_display
  exit 1 
fi

}


#--------------------------------------
# Function for checking the existance 
# of the walshipping folders on the 
# destination system and creating the link
walshipping_folders_check () {

if [ ! -z $WALSHIPPING_DIR ]; then 
 
  if ssh -T $DEST_NODE [ ! -d $WALSHIPPING_DIR ]; then 

    echo -n -e "\n\t - Walshipping folders missing on destination : "
    MKDIR_RES=`ssh -T $DEST_NODE mkdir -p $WALSHIPPING_DIR/logs.complete  2>/dev/null ; echo $? `

    if [ "$MKDIR_RES" = "0" ];then 
       echo  " Successfuly Created "
    else
       echo  " Connot Create "
       echo -e "\t - Please check folder permission on destination "
       echo -e "\n\t ------------- END: `date` ------------- "
       exit 1
    fi
  fi

  if ssh -T $DEST_NODE [ ! -L $WALSHIPPING ]; then 

    echo -n -e "\t - Walshipping link missing on destination : "
    LN_RES=`ssh -T $DEST_NODE ln -s $WALSHIPPING_DIR $WALSHIPPING 2>/dev/null ; echo $? `

    if [ "$LN_RES" = "0" ];then
       echo  " Successfuly Created "
    else
       echo  " Link Failed "
       echo -e "\t - Please check folder permission on destination "
       echo -e "\n\t ------------- END: `date` ------------- "
       exit 1
    fi
    
  fi

elif [ -z $WALSHIPPING_DIR ]; then 

  if ssh -T $DEST_NODE [ ! -d $WALSHIPPING ]; then

    echo -n -e "\n\t - Walshipping folders missing on destination : "
    MKDIR_RES=`ssh -T $DEST_NODE mkdir -p $WALSHIPPING/logs.complete  2>/dev/null ; echo $? `

    if [ "$MKDIR_RES" = "0" ];then
       echo  " Successfuly Created "
    else
       echo  " Connot Create "
       echo -e "\t - Please check folder permission on destination "
       echo -e "\n\t ------------- END: `date` ------------- "
       exit 1
    fi
  fi

fi 

}


#---------------------------------
# Function for sending email out 
mail_warning() {
  NODE=$1
  SUBJECT="Remote startup failed on $NODE " 
  MSG="Please check on the destination node to see what errors occured"

  `echo $MSG | mail -s "$SUBJECT" "$EMAIL_ADDRESS" `
}


#--------------------------------------------------------
# Function for checking destination system is reachable  
# Also checks to see if PG on destination system is 
# also online and if so it will be shutdown
destination_check () {

PING_OUTPUT=`/bin/ping -c 2 -w 5 $DEST_NODE 2>/dev/null 1>/dev/null ; echo $? `

if [ "$PING_OUTPUT" = "0" ]; then

  PG_DEST_STATUS=`ssh -T $DEST_NODE $PG_INIT status | awk '{print $4}'` 2>/dev/null 1>/dev/null

  if [ "$PG_DEST_STATUS" = "online" ]; then

     STOP_STATUS=`ssh -T $DEST_NODE $PG_INIT stop 2>/dev/null 1>/dev/null ; echo $? `
     SHUTDOWN_STATUS=`ssh -T $DEST_NODE $PG_INIT  status | awk '{print $4}'`

     if [ "$STOP_STATUS" = "1" ]; then
        msg="\n\t Standby postgreSQL instance failed to be stopped "
        msg=${msg}"\n\t Please stop it manually and try again "
        msg=${msg}"\n"
        msg=${msg}"\n\t ------------- END: `date` ------------- "

        echo -e ${msg}
        exit 1
     fi

     if [ "$SHUTDOWN_STATUS" = "down" ]; then
        echo -e "\n\t - Standby postgreSQL instance has been shutdown \n"
     else
        echo -e "\n\t Standby postgreSQL status does not seem to be down "
        echo -e "\n\t Please check it manually and try again "
        echo -e "\n"
        echo -e "\n\t ------------- END: `date` ------------- "
        exit 1
     fi
  elif [ "$PG_DEST_STATUS" = "down" ]; then
     echo -e "\n\t - Standby postgreSQL is already down "
  fi

else
    echo -e "\n\t `date`: Server could not be reached "
    echo -e "\n\t  ------------- END: `date` ------------- "
    echo -e "\n"
    exit 1
fi

}


#--------------------------------------------------------------
# Function to check that RSYNC is alive on destination system 
# and also to make sure it's receiving RW requests
rsync_destination_check () {

RSYNC_SRVNODE=$1
RSYNC_PORT="873"

RSYNC_CHECK=`ssh -T $RSYNC_SRVNODE netstat -tnl |grep "$RSYNC_SRVNODE:$RSYNC_PORT" 2> /dev/null 1>/dev/null ; echo $? `

if [ "$RSYNC_CHECK" = "1" ]; then

  msg="\n\t - Rsyncd is not running/listening on \"$RSYNC_SRVNODE:$RSYNC_PORT\" on destination node "
  msg=${msg}"\n\t - Please enable it and try again "
  msg=${msg}"\n"
  msg=${msg}"\n\t ------------- END: `date` ------------- \n\n"
  echo -e ${msg}
  exit 1
else
  echo -e "\t - Rsyncd is running/listening on destination node \"$RSYNC_SRVNODE:$RSYNC_PORT\" "
fi

touch /tmp/rsync_check
RSYNC_RW_CHECK=`rsync -q /tmp/rsync_check $RSYNC_SRVNODE::pgdata/ 2>/dev/null; echo $? `

if [ "$RSYNC_RW_CHECK" != "0" ]; then 

  msg="\n\t - Rsyncd is in Read-Only Mode on destination node "
  msg=${msg}"\n\t - Please enable Read-Write and try again "
  msg=${msg}"\n"
  msg=${msg}"\n\t ------------- END: `date` ------------- \n\n"

  rm /tmp/rsync_check

  echo -e ${msg}
  exit 1 
else
  echo -e "\t - Rsyncd Read-Write destination check: OK "
fi

rm /tmp/rsync_check

}


#--------------------------------------------------------------
# Function to check that archive_mode is enabled on source PG   
archive_mode_check () {

ARC_MODE=`psql -t -c "show archive_mode"`

if [ $ARC_MODE != "on" ]; then 

    msg="\n\t ######################################### "
    msg=${msg}"\n\t # archve_mode is currently disabled \t #"
    msg=${msg}"\n\t # please enable archive_mode first \t #"
    msg=${msg}"\n\t # and also set proper archive command \t # "
    msg=${msg}"\n\t ######################################### \n\n"
    msg=${msg}"\n\t ------------- END: `date` ------------- \n"
    echo -e ${msg}
    exit 1
else 
  echo -e "\t - Archive mode has been checked and it is enabled "
fi

}


#-----------------------------------------------------
# Function for setting up the proper Archive Command 
archive_cmd_setup () {

  # ARCHIVE COMMANDS
  DEST_IP_ARCH="$1"

  # IF USING WALMGR.PY SKYTOOLS
  #ARC_COMMAND_LINE="archive_command = \\'\/usr\/bin\/walmgr.py \/var\/lib\/postgresql\/walconfs\/wal-master.ini xarchive %p %f\\'"
  #ARC_COMMAND="/usr/bin/walmgr.py /var/lib/postgresql/walconfs/wal-master.ini xarchive %p %f"

  # IF NOT USING SKYTOOLS
  ARC_COMMAND_LINE="archive_command = \\'\/usr\/bin\/rsync -a %p $DEST_IP_ARCH:\/var\/lib\/postgresql\/$PG_VERSION\/walshipping\/logs.complete\/%f\\'"
  ARC_COMMAND="/usr/bin/rsync -a %p $DEST_IP_ARCH:$WALSHIPPING/logs.complete/%f"

}


#-------------------------------------------------------------------
# Function for checking that the archive_command is setup properly
archive_command_check () {

ARCHIVE_CHANGE=0
CUR_ARC_COMMAND=`psql -t -c "show archive_command" | sed 's/^[ \t]*//;s/[ \t]*$//'`

if [ "$CUR_ARC_COMMAND" = "'/bin/true'" ]; then

       sed -i "s/^archive_command.*/$ARC_COMMAND_LINE/" $PGCONF 	

       # reload conf
       psql -qt -c "SELECT pg_reload_conf()" 2> /dev/null 1> /dev/null

       RECHECK=`psql -t -c "show archive_command" | sed 's/^[ \t]*//;s/[ \t]*$//'`
  
       if [ "$RECHECK" = "$ARC_COMMAND" ]; then 
          ARC_GOOD=1
       else
          ARC_GOOD=0
       fi 
       ARCHIVE_CHANGE=1

elif [ "$CUR_ARC_COMMAND" != "$ARC_COMMAND" ]; then 

       sed -i "s/^archive_command.*/$ARC_COMMAND_LINE/" $PGCONF

       # reload conf
       psql -qt -c "SELECT pg_reload_conf()" 2> /dev/null 1> /dev/null

       RECHECK=`psql -t -c "show archive_command" | sed 's/^[ \t]*//;s/[ \t]*$//'`
 
       if [ "$RECHECK" = "$ARC_COMMAND" ]; then           
          ARC_GOOD=1
       else
          ARC_GOOD=0
       fi
       ARCHIVE_CHANGE=1
fi
}


#----------------------------------------------------------------------
# Function for rolling back the archive command 
# once sync is finished, unless WAL shipping is to be enabled
archive_command_rollback () {

CUR_ARC_COMMAND=`psql -t -c "show archive_command" | sed 's/^[ \t]*//;s/[ \t]*$//'`
ARC_CMD_ROLLBACK="archive_command = \'\/bin\/true\'"

if [ "$CUR_ARC_COMMAND" = "$ARC_COMMAND" ]; then

   sed -i "s/^archive_command.*/$ARC_CMD_ROLLBACK/" $PGCONF
   # reload conf
   psql -qt -c "SELECT pg_reload_conf()" 2> /dev/null 1> /dev/null
fi

}


#-------------------------------------------
# Function for starting up PostgreSQL on 
# remote/destination system 
remote_startup () {

# Check if there is a leftover trigger file, if so remove it 
if ssh -T $DEST_NODE [ -f $TRIGGER_FILE ]; then 
  ssh -T $DEST_NODE rm -f $TRIGGER_FILE  
fi 

STATUS=`ssh -T $DEST_NODE $PG_INIT start`

if [[ $STATUS = *failed* ]]; then

   echo -e "\n\t - Remote postgresql service failed to start up "
   mail_warning $DEST_NODE

   echo -e "\t ------------- END: `date` ------------- \n\n"
   exit 1
else

   CHECK_STATUS=`ssh -T $DEST_NODE $PG_INIT status | awk '{print $4}'` 2>/dev/null 1>/dev/null

   if [ "$CHECK_STATUS" = "online" ]; then
      msg="\n"
      msg=${msg}"\t - Remote PostgreSQL serviec started up OK \n"
      msg=${msg}"\t - Please check PG logs on remote server for more details \n"
      echo -e $msg

   fi
fi

}



#################################################################
#                     MAIN SECTION BEGINS HERE                  #
#################################################################

############################
# PARSE ARGUMENTS PROVIDED 
############################
parse_args "$@"

if [ "$PG_VARS_SET" = "0" ]; then 
  set_postgres_vars $PG_VERSION
fi 



########################
# ARCHIVE CMD SETUP 
######################## 
archive_cmd_setup $DEST_NODE



############################
# LOG SETUP
############################
if [ "$VERBOSE" != "1" ]; then 
  log_setup
fi



#####################
# RSYNC DST CHECK 
#####################
if [ "$SYNC_METHOD" = "rsync" ]; then
   echo -e "\n\t ------------ START: `date` ------------ \n"
   # Check Rsync is running on destination and that is read-write enabled
   rsync_destination_check $DEST_NODE 
else 
   # No SYNC Method chosen exit 
   msg="\n\t ############################################## "
   msg=${msg}"\n\t # There is no SYNC_METHOD defined "
   msg=${msg}"\n\t # Please define one within the CONFIGURATION "
   msg=${msg}"\n\t # section on the script and try again " 
   msg=${msg}"\n\t # Exiting .... "
   msg=${msg}"\n\t ############################################## \n\n"
   echo -e ${msg}
   exit 1
fi 



############################
# WALSHIPPING FOLDER CHECK
############################
walshipping_folders_check



############################
# DESTINATION CHECK
############################
destination_check



############################################
# CHECK ARCHIVE MODE & COMMAND ARE PROPERLY 
# SETUP ON THE MASTER DATABASE SERVER 
############################################
archive_mode_check
archive_command_check

if [ "$ARCHIVE_CHANGE" = "1" ]; then 

   echo -e "\t - Archive commnad has been changed "
   if [ "$ARC_GOOD" = "1" ]; then 
      echo -e "\t\t Archive cmd changed/re-checked: OK "

      NEW_ARC=`psql -t -c "show archive_command" | sed 's/^[ \t]*//;s/[ \t]*$//'`
      echo -e "\t\t Arc. Cmd.: $NEW_ARC \n"
   else 
      msg="\n\t Archive command could not be setup properly "
      msg=${msg}"\n\t Please check PG for any errors " 
      msg=${msg}"\n\t exiting ... \n"
      msg=${msg}"\n\t ------------- END: `date` ------------- \n"
      echo -e ${msg}
      exit 1 
   fi 

elif [ "$ARCHIVE_CHANGE" = "0" ]; then
   echo -e "\t - No archive command changes were necessary \n"
fi



###########################
# REMOVE OLD PGDATA FILES
###########################

if ssh -T $DEST_NODE [ -L $DEST_PGDATA/pg_xlog ]; then 

  echo -e "\t - Removing old xlog files found on destination "
  ssh -T $DEST_NODE "find $DEST_PGDATA/pg_xlog/ -type f -exec rm -f {} \;"

  echo -e "\t - Removing pg_xlog link on destination "
  ssh -T $DEST_NODE unlink $DEST_PGDATA/pg_xlog
fi 

echo -e "\t - Removing old PGDATA files on destination \n"
ssh -T $DEST_NODE rm -rf $DEST_PGDATA/*

if ssh -T $DEST_NODE [ -f $DEST_PGDATA/rsync_check ]; then 
  ssh -T $DEST_NODE rm -f $DEST_PGDATA/rsync_check 
fi



###########################
# START OF BACKUP STEPS
###########################
sleep 2

# CHECKPOINT
psql -c "SELECT pg_switch_xlog()" | sed 's/^/\t/'
sleep 3 

# start the backup
psql -c "SELECT pg_start_backup('hot_backup')" postgres | sed 's/^/\t/'
sleep 3


if [ "$SYNC_METHOD" = "rsync" ]; then
   # Rsync 
   rsync -ah -W --stats  --exclude pg_xlog --exclude postmaster.pid --exclude ".walshipping.last"  $SRC_PGDATA/ $DEST_NODE::pgdata 2>/dev/null | sed 's/^/\t/'
fi 

echo -e "\n"

sleep 2
# Stop the backup
psql -c "SELECT pg_stop_backup()" postgres | sed 's/^/\t/'

sleep 10

# CHECKPOINT
psql -c "SELECT pg_switch_xlog()" | sed 's/^/\t/'



###########################
# CREATE LINKS 
###########################

if [ -n "$PG_XLOG_DIR" ]; then 
  echo -e "\t - Re-creating pg_xlog link "
  ssh -T $DEST_NODE ln -s $PG_XLOG_DIR  $DEST_PGDATA/pg_xlog

elif [ -z  "$PG_XLOG_DIR" ]; then
    echo -e "\t - Re-creating pg_xlog directories "
    ssh -T $DEST_NODE mkdir -p $DEST_PGDATA/pg_xlog/archive_status
    ssh -T $DEST_NODE chmod 700 $DEST_PGDATA/pg_xlog 
    ssh -T $DEST_NODE chmod 700 $DEST_PGDATA/pg_xlog/archive_status
fi

echo -e "\t - Re-creating cert links "

if [ "$PG_VERSION" != "8.4" ]; then 
  if ssh -T $DEST_NODE [ ! -L $DEST_PGDATA/root.crt ]; then 
    ssh -T $DEST_NODE ln -s /etc/postgresql-common/root.crt $DEST_PGDATA/root.crt
  fi 
fi 

if ssh -T $DEST_NODE [ ! -L $DEST_PGDATA/server.crt ]; then 
  ssh -T $DEST_NODE ln -s /etc/ssl/certs/ssl-cert-snakeoil.pem $DEST_PGDATA/server.crt
fi 

if ssh -T $DEST_NODE [ ! -L $DEST_PGDATA/server.key ]; then 
  ssh -T $DEST_NODE ln -s /etc/ssl/private/ssl-cert-snakeoil.key $DEST_PGDATA/server.key
fi



###############################
# RECOVERY CONF SETUP
# DESTINATION NODE REMOTE START
###############################

echo -e "\n\t - Setting up recovery file on destination node "

echo "restore_command = '$PG_STDBY -t $TRIGGER_FILE $WALSHIPPING/logs.complete  %f %p %r'" > /tmp/recovery.conf

if [ "$PG_VERSION" = "8.4" ]; then 
   echo "recovery_end_command = 'rm -f $TRIGGER_FILE ' " >> /tmp/recovery.conf
fi

scp /tmp/recovery.conf $DEST_NODE:$DEST_PGDATA/recovery.conf 2>/dev/null 1>/dev/null
rm -f /tmp/recovery.conf

if [ "$ONLINE_MODE" = "1" ]; then 

   echo -e "\t - Rolling back archive command "
   archive_command_rollback

   echo -e "\t -"
   echo -e "\t - Starting postgresql on destination in online mode "
   remote_startup

   # Take out of recovery mode (smart failover) to bring it online
   if [ "$PG_VERSION" = "8.3" ]; then 
      sleep $FAILOVER_TIMEOUT 
   else 
      sleep 5
   fi 
   ssh -T $DEST_NODE touch $TRIGGER_FILE 
    
elif [ "$ONLINE_MODE" = "0" ]; then 

   if [ "$LOG_SHIPPING_MODE" = "1" ]; then
      echo -e "\t - Log Shipping left enabled on source "
      echo -e "\t - Destination system will be a WARM standby "
   else
      echo -e "\t - Rolling back archive command "
      archive_command_rollback
   fi          

   echo -e "\n "
   echo -e "\t - Starting postgresql on destination in recovery mode "
   echo -e "\t   Trigger file required to kick it out of recovery mode "
   remote_startup
fi

echo -e "\t - Hot-Backup Sync has finished successfuly "
echo -e "\t ------------- END: `date` ------------- \n"

exit 0 

