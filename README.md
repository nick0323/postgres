# postgres
postgresql 9.6.13 + pgpool3.7.10 构建高可用postgres集群

环境：
192.168.248.124 db1
192.168.248.125 db2
192.168.248.126 pgpool1
192.168.248.127 pgpool2
192.168.248.101 VIP

os version: CentOS release 6.10 (Final)

一. 准备工作
1. 配置db,pgpool服务器/etc/hosts文件，设置ip和机器名映射,请根据实际情况修改。
# cat /etc/hosts 
...
192.168.248.124 db01
192.168.248.125 db02
192.168.248.126 dbp1
192.168.248.127 dbp2

2. 配置各server之间互信
root用户互信
postgres用户互信

二. 执行安装脚本
postgresql：psql_install.sh

pgpool：pgpool_install.sh //在安装pgpool时，注意修改pgpool配置。master和slave相反。

三. 启动postgresql服务。
/etc/init.d/postgresql-9.6 start

四. 启动pgpool服务
/etc/init.d/pgpool-II-96  start 

五. 查看节点状态命令
PGPASSWORD=1qaz2wsx psql -h 192.168.248.101 -U postgres -p 9999 -c 'show pool_nodes' //ip为VIP地址

六. 恢复节点命令
pcp_recovery_node -U postgres -h 192.168.248.101 -p 9898 -n 1 //参数 -n 指定node id, ip为VIP地址
