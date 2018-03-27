#!/bin/bash
# LICENSE GPL 3.0
#
# Copyright (c) 2012-2018 Hangzhou WOQUTECH co,ltd. All rights reserved.
#
# Description: Creates an Oracle Database based on following parameters:
#              $ORACLE_SID: The Oracle SID and CDB name
#              $ORACLE_PDB: The PDB name
#              $ORACLE_PWD: The Oracle password
# 

set -e

# Check whether ORACLE_SID is passed on
#export ORACLE_SID=${1:-ORCLCDB}

# Check whether ORACLE_PDB is passed on
#export ORACLE_PDB=${2:-ORCLPDB1}

# If there is greater than 8 CPUs default back to dbca memory calculations
# dbca will automatically pick 40% of available memory for Oracle DB
# The minimum of 2G is for small environments to guarantee that Oracle has enough memory to function
# However, bigger environment can and should use more of the available memory
# This is due to Github Issue #307
#if [ `nproc` -gt 8 ]; then
#   sed -i -e "s|totalMemory=2048||g" $ORACLE_BASE/dbca.rsp
#fi;

# snapshot time
#time=`date "+%Y-%m-%d-%H:%M:%S"`

# change permission for oracle
sudo su - root -c "chown -R oracle:dba $ORACLE_BASE/oradata"

# Start LISTENER and run DBCA
lsnrctl start 

mkdir -p /opt/oracle/admin/$ORACLE_SID/adump
cp -r /tmp/backup/* /opt/oracle/oradata
rm -rf /opt/oracle/oradata/$ORACLE_SID/archivelog/*
rm -rf /opt/oracle/oradata/dbconfig/$ORACLE_SID/DB_INIT
rm -rf /opt/oracle/oradata/dbconfig/$ORACLE_SID/OPEN

if [ ! -L $ORACLE_HOME/dbs/spfile$ORACLE_SID.ora ]; then
   ln -f -s $ORACLE_BASE/oradata/dbconfig/$ORACLE_SID/spfile$ORACLE_SID.ora $ORACLE_HOME/dbs/spfile$ORACLE_SID.ora
fi;

if [ ! -L $ORACLE_HOME/dbs/orapw$ORACLE_SID ]; then
   ln -f -s $ORACLE_BASE/oradata/dbconfig/$ORACLE_SID/orapw$ORACLE_SID $ORACLE_HOME/dbs/orapw$ORACLE_SID
fi;

if [ ! -L $ORACLE_HOME/network/admin/sqlnet.ora ]; then
   ln -f -s $ORACLE_BASE/oradata/dbconfig/$ORACLE_SID/sqlnet.ora $ORACLE_HOME/network/admin/sqlnet.ora
fi;

if [ ! -L $ORACLE_HOME/network/admin/listener.ora ]; then
   ln -f -s $ORACLE_BASE/oradata/dbconfig/$ORACLE_SID/listener.ora $ORACLE_HOME/network/admin/listener.ora
fi;

if [ ! -L $ORACLE_HOME/network/admin/tnsnames.ora ]; then
   ln -f -s $ORACLE_BASE/oradata/dbconfig/$ORACLE_SID/tnsnames.ora $ORACLE_HOME/network/admin/tnsnames.ora
fi;

# oracle user does not have permissions in /etc, hence cp and not ln
cp $ORACLE_BASE/oradata/dbconfig/$ORACLE_SID/oratab /etc/oratab

#echo "primary =
#  (DESCRIPTION =
#    (ADDRESS = (PROTOCOL = TCP)(HOST = $PRIMARY_SRV)(PORT = 1521))
#    (CONNECT_DATA =
#      (SERVER = DEDICATED)
#      (SERVICE_NAME = $ORACLE_SID)
#    )
#  )
#" >> $ORACLE_HOME/network/admin/tnsnames.ora

sqlplus / as sysdba << EOF
  startup mount;
  alter database create standby controlfile AS '/opt/oracle/oradata/control_stdby.tmp';
  --alter system set db_unique_name=standby scope=spfile;
  alter system set db_file_name_convert='/opt/oracle/oradata','/opt/oracle/oradata' scope=spfile;
  alter system set log_file_name_convert='/opt/oracle/oradata','/opt/oracle/oradata' scope=spfile;
  alter system set fal_server=primary;
  shutdown immediate
  host cp -f /opt/oracle/oradata/control_stdby.tmp /opt/oracle/oradata/\$ORACLE_SID/control01.ctl
  startup mount
  alter database add standby logfile size 1G;
  alter database add standby logfile size 1G;
  alter database add standby logfile size 1G;
  exit;
EOF

# start MRP
/opt/oracle/$START_MRP
