# LICENSE GPL 3.0
#
# Copyright (c) 2012-2018 Hangzhou WOQUTECH co,ltd. All rights reserved.
#
# ORACLE DOCKERFILES PROJECT
# --------------------------
# This is the Dockerfile for Oracle Database 11g Release 2 Enterprise Edition
# 
# REQUIRED FILES TO BUILD THIS IMAGE
# ----------------------------------
# (1) p13390677_112040_Linux-x86-64_1of7.zip
#     p13390677_112040_Linux-x86-64_2of7.zip
#
# HOW TO BUILD THIS IMAGE
# -----------------------
# Put all downloaded files in the same directory as this Dockerfile
# Run: 
#      $ docker build -t oracle/database:11.2.0.4.0-ee . 
#
# Pull base image
# ---------------
FROM centos

# Environment variables required for this build (do NOT change)
# -------------------------------------------------------------
ENV ORACLE_BASE=/opt/oracle \
    ORACLE_HOME=/opt/oracle/product/11.2.0 \
    INSTALL_FILE_1="p13390677_112040_Linux-x86-64_1of7.zip" \
    INSTALL_FILE_2="p13390677_112040_Linux-x86-64_2of7.zip" \
    INSTALL_RSP="db_inst.rsp" \
    CONFIG_RSP="dbca.rsp.tmpl" \
    RUN_FILE="runOracle.sh" \
    START_FILE="startDB.sh" \
    CREATE_DB_FILE="createDB.sh" \
    CREATE_STB_FILE="createSTB.sh" \
    START_MRP="startMRP.sh" \
    SETUP_LINUX_FILE="setupLinuxEnv.sh" \
    CHECK_SPACE_FILE="checkSpace.sh" \
    CHECK_DB_FILE="checkDBStatus.sh" \
    INSTALL_DB_BINARIES_FILE="installDBBinaries.sh"

# Use second ENV so that variable get substituted
ENV INSTALL_DIR=$ORACLE_BASE/install \
    PATH=$ORACLE_HOME/bin:$ORACLE_HOME/OPatch/:/usr/sbin:$PATH \
    LD_LIBRARY_PATH=$ORACLE_HOME/lib:/usr/lib \
    CLASSPATH=$ORACLE_HOME/jlib:$ORACLE_HOME/rdbms/jlib

# Copy binaries
# -------------
COPY $INSTALL_FILE_1 $INSTALL_FILE_2 $INSTALL_RSP $SETUP_LINUX_FILE $CHECK_SPACE_FILE $INSTALL_DB_BINARIES_FILE $INSTALL_DIR/
COPY $RUN_FILE $START_FILE $CREATE_DB_FILE $CREATE_STB_FILE $START_MRP $CONFIG_RSP $CHECK_DB_FILE $ORACLE_BASE/

RUN chmod ug+x $INSTALL_DIR/*.sh && \
    sync && \
    $INSTALL_DIR/$CHECK_SPACE_FILE && \
    $INSTALL_DIR/$SETUP_LINUX_FILE

# Install DB software binaries
USER oracle
RUN $INSTALL_DIR/$INSTALL_DB_BINARIES_FILE

USER root
RUN $ORACLE_BASE/oraInventory/orainstRoot.sh && \
    $ORACLE_HOME/root.sh && \
    rm -rf $INSTALL_DIR/*

USER oracle
WORKDIR /home/oracle

VOLUME ["$ORACLE_BASE/oradata"]
EXPOSE 1521
HEALTHCHECK --interval=1m --start-period=5m \
   CMD "$ORACLE_BASE/$CHECK_DB_FILE" >/dev/null

# Define default command to start Oracle Database. 
CMD exec $ORACLE_BASE/$RUN_FILE
