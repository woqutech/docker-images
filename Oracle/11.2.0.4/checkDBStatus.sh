#!/bin/bash
# LICENSE GPL 3.0
#
# Copyright (c) 2012-2018 Hangzhou WOQUTECH co,ltd. All rights reserved.
#
# Description: Checks the status of Oracle Database.
# Return codes: 0 = Database is open and ready to use
#               1 = Database is not open
#               2 = Sql Plus execution failed
#               3 = Standby Database is in MOUNTED mode WITH APPLY.
#               4 = Standby Database is in READ ONLY WITH APPLY mode. 
# 

ORACLE_SID="`grep $ORACLE_HOME /etc/oratab | cut -d: -f1`"
ORACLE_PDB="`ls -dl $ORACLE_BASE/oradata/$ORACLE_SID/*/ | grep -v pdbseed | awk '{print $9}' | cut -d/ -f6`"
ORAENV_ASK=NO
source oraenv

# Check Primary Oracle DB status and store it in status
if [ "$DB_ROLE" == "primary" ] || [ "$DB_ROLE" == "" ] ; then
  status=`sqlplus -s / as sysdba << EOF
     set heading off;
     set pagesize 0;
     select open_mode from v\\$database;
     exit;
EOF`

  # Store return code from SQL*Plus
  ret=$?

  # SQL Plus execution was successful and primary database is open
  if [ $ret -eq 0 ] && [ "$status" = "READ WRITE" ]; then
     echo "{\"statusCode\": 1 , \"message\": \"Primary Database is in READ WRITE mode.\"}" > $ORACLE_BASE/oradata/dbconfig/$ORACLE_SID/DB_INIT
     exit 0;
  # Database is not open
  elif [ "$status" != "READ WRITE" ]; then
     echo "{\"statusCode\": 2 , \"message\": \"Database Creation is not successful.Please check manually.\"}" > $ORACLE_BASE/oradata/dbconfig/$ORACLE_SID/DB_INIT
     exit 1;
  # SQL Plus execution failed
  else
     exit 2;
  fi;
else
  status=`sqlplus -s / as sysdba << EOF
     set heading off;
     set pagesize 0;
     select open_mode from v\\$database;
     exit;
EOF`
  
  # Store return code from SQL*Plus
  ret=$?

  # MRP
  mrp_status=`sqlplus -s / as sysdba << EOF
    set heading off;
    set pagesize 0;
    select count(*) from v\\$managed_standby where status='APPLYING_LOG';
    exit;
EOF`

  # SQL Plus execution was successful and standby database is open read only with apply
  if [ $ret -eq 0 ] && [ "$status" = "READ ONLY WITH APPLY" ]; then
     echo "{\"statusCode\": 4, \"message\": \"Standby Database is in READ ONLY WITH APPLY mode.\"}" > $ORACLE_BASE/oradata/dbconfig/$ORACLE_SID/DB_INIT
     exit 4;
  fi;
  # Database is not open
  if [ $ret -eq 0 ] && [ "$status" == "MOUNTED" ] && [ $mrp_status -gt 0 ] ; then
     echo ""{\"statusCode\": 3 , \"message\": \"Standby Database is in MOUNTED mode WITH APPLY.\"} > $ORACLE_BASE/oradata/dbconfig/$ORACLE_SID/DB_INIT
     exit 3;
  fi;
  # SQL Plus execution failed
  echo "{\"statusCode\": 2 , \"message\": \"Database Creation is not successful.Please check manually.\"}" > $ORACLE_BASE/oradata/dbconfig/$ORACLE_SID/DB_INIT
  exit 2;
fi;
