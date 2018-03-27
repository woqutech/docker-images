#!/bin/bash
# LICENSE GPL 3.0
#
# Copyright (c) 2012-2018 Hangzhou WOQUTECH co,ltd. All rights reserved.
#
# Description: Start MRP on standby database.

# Modify initialization parameters on primary database
hostname=$(hostname)
stbno=${hostname: -1}
let "no=$stbno + 2"

fal=`sqlplus -s sys/$ORACLE_PWD@primary as sysdba << EOF
     set heading off;
     set pagesize 0;
select value from v\\$parameter where name='fal_server';
EOF`

if [ $stbno == 0 ] ; then
fal='standby'${stbno}
else
fal=${fal}',standby'${stbno}
fi

sqlplus sys/$ORACLE_PWD@primary as sysdba << EOF
ALTER SYSTEM SET LOG_ARCHIVE_DEST_$no = 'service=standby$stbno ASYNC VALID_FOR=(ONLINE_LOGFILES,PRIMARY_ROLE)';
ALTER SYSTEM SET FAL_SERVER=$fal;
EOF

sqlplus sys/$ORACLE_PWD@primary as sysdba << EOF
alter system archive log current;
EOF

sqlplus / as sysdba << EOF
recover managed standby database until consistent;
alter database open;
RECOVER MANAGED STANDBY DATABASE USING CURRENT LOGFILE DISCONNECT FROM SESSION;
EOF

sleep 10

for i in $(seq 1 100)
do
    mrp_running=`ps -ef|grep mrp|grep -v grep|wc -l`
    if [ "$mrp_running" -eq 0 ] ; then
		sqlplus / as sysdba << EOF
		shutdown abort;
EOF
	else
		status=`sqlplus -s / as sysdba << EOF
     	set heading off;
     	set pagesize 0;
     	select open_mode from v\\$database;
     	exit;
EOF`

		if [ "$status" == "READ ONLY WITH APPLY" ] ; then
    		echo "YES" > $ORACLE_BASE/oradata/dbconfig/$ORACLE_SID/OPEN
			exit;
		else
			sleep 60
		fi;
	fi;	
done

if [ "$status" == "MOUNTED" ] ; then
  sqlplus / as sysdba << EOF
  shutdown abort
  exit;
EOF
fi
