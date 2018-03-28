#!/bin/bash
# LICENSE GPL 3.0
#
# Copyright (c) 2012-2018 Hangzhou WOQUTECH co,ltd. All rights reserved.
#
# Author: lex.guo@woqutech.com
# Description: Creates an Oracle Database based on following parameters:
#              $ORACLE_SID: The Oracle SID and CDB name
#              $ORACLE_PDB: The PDB name
#              $ORACLE_PWD: The Oracle password
# 

set -e

# Check whether ORACLE_SID is passed on
export ORACLE_SID=${1:-ORCLCDB}

# Check whether ORACLE_PDB is passed on
export ORACLE_PDB=${2:-ORCLPDB1}

# Auto generate ORACLE PWD if not passed on
export ORACLE_PWD=${3:-"`openssl rand -base64 8`1"}
echo "ORACLE PASSWORD FOR SYS, SYSTEM AND PDBADMIN: $ORACLE_PWD";

# Replace place holders in response file
cp $ORACLE_BASE/$CONFIG_RSP $ORACLE_BASE/dbca.rsp
sed -i -e "s|###ORACLE_SID###|$ORACLE_SID|g" $ORACLE_BASE/dbca.rsp
sed -i -e "s|###ORACLE_PDB###|$ORACLE_PDB|g" $ORACLE_BASE/dbca.rsp
sed -i -e "s|###ORACLE_PWD###|$ORACLE_PWD|g" $ORACLE_BASE/dbca.rsp
sed -i -e "s|###ORACLE_CHARACTERSET###|$ORACLE_CHARACTERSET|g" $ORACLE_BASE/dbca.rsp
sed -i -e "s|###SGA_SIZE###|$SGA_SIZE|g" $ORACLE_BASE/dbca.rsp
sed -i -e "s|###PGA_SIZE###|$PGA_SIZE|g" $ORACLE_BASE/dbca.rsp
sed -i -e "s|###CDB_ENABLE###|$CDB_ENABLE|g" $ORACLE_BASE/dbca.rsp

# If there is greater than 8 CPUs default back to dbca memory calculations
# dbca will automatically pick 40% of available memory for Oracle DB
# The minimum of 2G is for small environments to guarantee that Oracle has enough memory to function
# However, bigger environment can and should use more of the available memory
# This is due to Github Issue #307
#if [ `nproc` -gt 8 ]; then
#   sed -i -e "s|totalMemory=2048||g" $ORACLE_BASE/dbca.rsp
#fi;

# change permission for oracle
sudo su - root -c "chown -R oracle:dba $ORACLE_BASE/oradata"

# Create network related config files (sqlnet.ora, tnsnames.ora, listener.ora)
mkdir -p $ORACLE_HOME/network/admin
echo "NAME.DIRECTORY_PATH= (TNSNAMES, EZCONNECT, HOSTNAME)" > $ORACLE_HOME/network/admin/sqlnet.ora

# Listener.ora
echo "LISTENER = 
(DESCRIPTION_LIST = 
  (DESCRIPTION = 
    (ADDRESS = (PROTOCOL = IPC)(KEY = EXTPROC1)) 
    (ADDRESS = (PROTOCOL = TCP)(HOST = 0.0.0.0)(PORT = 1521)) 
  ) 
) 

DEDICATED_THROUGH_BROKER_LISTENER=ON
DIAG_ADR_ENABLED = off
" > $ORACLE_HOME/network/admin/listener.ora

# make directory for archivelog
mkdir -p /opt/oracle/oradata/$ORACLE_SID/archivelog

# Start LISTENER and run DBCA
lsnrctl start &&
dbca -initParams java_jit_enabled=false -silent -createDatabase -responseFile $ORACLE_BASE/dbca.rsp -redoLogFileSize 1024 -datafileDestination /opt/oracle/oradata ||
 cat /opt/oracle/cfgtoollogs/dbca/$ORACLE_SID/$ORACLE_SID.log ||
 cat /opt/oracle/cfgtoollogs/dbca/$ORACLE_SID.log

echo "$ORACLE_SID=
(DESCRIPTION =
  (ADDRESS = (PROTOCOL = TCP)(HOST = 0.0.0.0)(PORT = 1521))
  (CONNECT_DATA =
    (SERVER = DEDICATED)
    (SERVICE_NAME = $ORACLE_SID)
  )
)" >> $ORACLE_HOME/network/admin/tnsnames.ora

# Standardize the creation of the database.
sqlplus / as sysdba << EOF
   alter system set db_recovery_file_dest='' scope=spfile;
   alter system reset db_recovery_file_dest_size scope=spfile;
   alter system set sga_target=$SGA_SIZE scope=spfile;
   alter system set sga_max_size=$PGA_SIZE scope=spfile;
   alter system set pga_aggregate_target=$PGA_SIZE scope=spfile;
   alter system set audit_trail=none scope=spfile;
   alter system set audit_sys_operations=false scope=spfile;
   alter system set filesystemio_options=directio scope=spfile;
   alter system set log_archive_dest_1='location=/opt/oracle/oradata/$ORACLE_SID/archivelog';
   ALTER SYSTEM SET control_files='$ORACLE_BASE/oradata/$ORACLE_SID/control01.ctl' scope=spfile;
   SHUTDOWN IMMEDIATE;
   STARTUP;
   declare
     CURSOR c_cursor IS SELECT file_name,file_id from dba_data_files;
     v_fileid number;
     v_filename varchar2(100);
   begin
   execute immediate 'alter database tempfile 1 resize 30G';
   OPEN c_cursor;
   FETCH c_cursor INTO v_filename, v_fileid;
   WHILE c_cursor%FOUND LOOP
     if instr(v_filename,'system') <> 0 then
     execute immediate 'alter database datafile ' || v_fileid || ' resize 1G';
     end if;
     if instr(v_filename,'sysaux') <> 0 then
     execute immediate 'alter database datafile ' || v_fileid || ' resize 1G';
     end if;
     if instr(v_filename,'undo') <> 0 then
     execute immediate 'alter database datafile ' || v_fileid || ' resize 10G';
     end if;
     FETCH c_cursor INTO v_filename, v_fileid;
   END LOOP;
   CLOSE c_cursor;
   END;
   /
   alter system set db_create_file_dest='/opt/oracle/oradata';
   alter system set db_create_online_log_dest_1='/opt/oracle/oradata';
   alter database force logging;
   alter system set STANDBY_FILE_MANAGEMENT=AUTO;
   EXEC DBMS_STATS.SET_GLOBAL_PREFS('CONCURRENT','FALSE');
   alter profile default limit PASSWORD_LIFE_TIME unlimited;
   exit;
EOF

if [ "$ENABLE_ARCH" == "true" ] ; then
	sqlplus / as sysdba << EOF
    shutdown immediate;
    startup mount;
    alter database archivelog;
    alter database open;
EOF
fi


# Remove temporary response file
rm $ORACLE_BASE/dbca.rsp
