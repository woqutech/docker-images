## Oracle Database 11.2.0.4 Docker Image

Oracle官方在Github上提供了一些Oracle Docker image，但并未提供11g R2版本。考虑到目前仍有大量用户使用11g R2，所以，我们参考官方12.1版本image制作了11.2.0.4.0版本的image，并且在其基础上做了进一步丰富和标准化，包括：

- 指定是否开启归档
- 指定SGA及PGA大小(官方image指定的是固定的内存大小，如需修改，需要在数据库创建之后手动调整，所以，在此我们做了相应的自动化)
- 指定数据库角色，包括primary及standby(官方镜像只能创建primary数据库，我们同时实现了创建standby数据库的逻辑，但该部分逻辑依赖沃趣科技QCFS云存储提供的快照功能，目前只能在QFusion 3.0 RDS数据库云平台中实现)
- 包含对主库实例状态、备库实例状态和MRP恢复状态的健康检查
- ONLINE REDO LOG自动调整为1G大小
- 设置用户名密码永不过期(虽不安全，但在绝大部分企业级用户均采用此实践)
- 关闭Concurrent Statistics Gathering功能
- TEMP表空间设置为30G大小
- SYSTEM表空间设置为1G大小
- SYSAUX表空间设置为1G大小
- UNDO表空间设置为10G大小


### Image构建

```
1. 下载本目录的所有文件
2. 下载11.2.0.4 Patchset：p13390677_112040_Linux-x86-64_1of7.zip p13390677_112040_Linux-x86-64_2of7.zip
3. 执行构建命令：
	docker build -t oracle/database:11.2.0.4.0-ee .
```

### Image使用举例

```
docker run -d --name oracledb \
-p 1521:1521 \
-e ORACLE_SID=dbalex \
-e ORACLE_PWD=oracle \
-e ORACLE_CHARACTERSET=ZHS16GBK \
-e SGA_SIZE=8G \
-e PGA_SIZE=8G \
-e DB_ROLE=primary \
-e ENABLE_ARCH=true \
-v /data/dbalex:/opt/oracle/oradata \
oracle/database:11.2.0.4.0-ee

PS:目前在Github提供的社区版Image只能设置DB_ROLE为primary，standby尚不提供支持，请持续关注本项目。
```
