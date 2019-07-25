#!/bin/sh

##################################################
##      pgpool-II-96 install and configure      ##
##################################################

##################################################################
##########Define variable,Please According to environmental change
##define master postgres info				
backend_hostname0=\'192.168.248.124\'				#primary db
backend_port0=5432
backend_data_directory0=\'/var/lib/pgsql/9.6/data\'

##define slave postgres info				
backend_hostname1=\'192.168.248.125\'				#secondary db
backend_port1=5432
backend_data_directory1=\'/var/lib/pgsql/9.6/data\'

##define master pgpool info
wd_hostname=\'192.168.248.126\'					#master pgpool
other_pgpool_hostname0=\'192.168.248.127\'				#slave pgpool
delegate_IP=\'192.168.248.101\'						#VIP

##define password for postgres user
password=1qaz2wsx						#password of dbuser postgres
PGPOOL_CONFIG_DIR=/etc/pgpool-II-96

log_destination=\'syslog\'
facility=LOCAL7
device=eth0
##########Define variable,Please According to environmental change
##################################################################

useradd postgres -d /var/lib/pgsql
echo $password | passwd --stdin postgres

SCRIPT_DIR=$(cd "$(dirname "$0")"; pwd)

##installed pgpool
yum localinstall pgpool-II-96-3.7.10-1.rhel6.x86_64.rpm postgresql96-9.6.13-1PGDG.rhel6.x86_64.rpm postgresql96-libs-9.6.13-1PGDG.rhel6.x86_64.rpm -y

##copy pcp.conf failback.sh failover.sh  to the destination
if [ -f $SCRIPT_DIR/pcp.conf ];then
    cp -p $SCRIPT_DIR/pcp.conf $PGPOOL_CONFIG_DIR/
    if [ $? != 0 ];then
        echo "copy pcp.conf is fail"
        exit 1
    fi
    ls -lR $PGPOOL_CONFIG_DIR/
else
    echo "$SCRIPT_DIR/pcp.conf is not exist"
    exit 1
fi

if [ -f $SCRIPT_DIR/pool_passwd ];then
    cp -p $SCRIPT_DIR/pool_passwd $PGPOOL_CONFIG_DIR/
    if [ $? != 0 ];then
        echo "copy pool_passwd is fail"
        exit 1
    fi
    ls -lR $PGPOOL_CONFIG_DIR/
else
    echo "$SCRIPT_DIR/pool_passwd is not exist"
    exit 1
fi

if [ -f $SCRIPT_DIR/failover.sh ];then
    cp -p $SCRIPT_DIR/failover.sh $PGPOOL_CONFIG_DIR/
    if [ $? != 0 ];then
        echo "copy failover.sh is fail"
        exit 1
    fi
    ls -l $PGPOOL_CONFIG_DIR/
else
    echo "$SCRIPT_DIR/failover.sh is not exist"
    exit 1
fi

##modify failback.sh failover.sh File Permissions
chmod 755 $PGPOOL_CONFIG_DIR/failover.sh
if [ $? != 0 ];then
    echo "modify failback.sh failover.sh File Permissions is fail"
    exit 1
fi

##copy sample pgpool.conf
cp $PGPOOL_CONFIG_DIR/pgpool.conf.sample-stream $PGPOOL_CONFIG_DIR/pgpool.conf

##modify pgpool.conf File
###comment the old configuration
pg_password=\'$password\'
syslog_facility=\'$facility\'
sed -i "s/listen_addresses = 'localhost'/listen_addresses = '*'/" $PGPOOL_CONFIG_DIR/pgpool.conf
sed -i "s/backend_hostname0 = 'host1'/backend_hostname0 = $backend_hostname0/" $PGPOOL_CONFIG_DIR/pgpool.conf
sed -i "s@backend_data_directory0 = '/data'@backend_data_directory0 = $backend_data_directory0@" $PGPOOL_CONFIG_DIR/pgpool.conf
sed -i "s/#backend_hostname1 = 'host2'/backend_hostname1 = $backend_hostname1/" $PGPOOL_CONFIG_DIR/pgpool.conf
sed -i "s/#backend_port1 = 5433/backend_port1 = $backend_port1/" $PGPOOL_CONFIG_DIR/pgpool.conf
sed -i "s/#backend_weight1 = 1/backend_weight1 = 1/" $PGPOOL_CONFIG_DIR/pgpool.conf
sed -i "s@#backend_data_directory1 = '/data1'@backend_data_directory1 = $backend_data_directory1@" $PGPOOL_CONFIG_DIR/pgpool.conf
sed -i "s/#backend_flag1 = 'ALLOW_TO_FAILOVER'/backend_flag1 = 'ALLOW_TO_FAILOVER'/" $PGPOOL_CONFIG_DIR/pgpool.conf
sed -i "s/log_destination = 'stderr'/log_destination = $log_destination/" $PGPOOL_CONFIG_DIR/pgpool.conf
sed -i "s/log_standby_delay = 'none'/log_standby_delay = 'if_over_threshold'/" $PGPOOL_CONFIG_DIR/pgpool.conf
sed -i "s/syslog_facility = 'LOCAL0'/syslog_facility = $syslog_facility/" $PGPOOL_CONFIG_DIR/pgpool.conf
sed -i "s@pid_file_name = '/var/run/pgpool/pgpool.pid'@pid_file_name = '/var/run/pgpool-II-96/pgpool.pid'@" $PGPOOL_CONFIG_DIR/pgpool.conf
sed -i "s/sr_check_user = 'nobody'/sr_check_user = 'postgres'/" $PGPOOL_CONFIG_DIR/pgpool.conf
sed -i "s/sr_check_password = ''/sr_check_password = $pg_password/" $PGPOOL_CONFIG_DIR/pgpool.conf
sed -i "s/health_check_period = 0/health_check_period = 10/" $PGPOOL_CONFIG_DIR/pgpool.conf
sed -i "s/health_check_user = 'nobody'/health_check_user = 'postgres'/" $PGPOOL_CONFIG_DIR/pgpool.conf 
sed -i "s/health_check_password = ''/health_check_password = $pg_password/" $PGPOOL_CONFIG_DIR/pgpool.conf
sed -i "s/health_check_max_retries = 0/health_check_max_retries = 10/" $PGPOOL_CONFIG_DIR/pgpool.conf
sed -i "s/health_check_retry_delay = 1/health_check_retry_delay = 5/" $PGPOOL_CONFIG_DIR/pgpool.conf
sed -i "s@failover_command = ''@failover_command = '/etc/pgpool-II-96/failover.sh %d %P %H %R'@" $PGPOOL_CONFIG_DIR/pgpool.conf 
#sed -i "s@failback_command = ''@failback_command = '/usr/local/etc/failback.sh %d "%h" %p %D'@" $PGPOOL_CONFIG_DIR/pgpool.conf 
sed -i "s/recovery_user = 'nobody'/recovery_user = 'postgres'/" $PGPOOL_CONFIG_DIR/pgpool.conf
sed -i "s/recovery_password = ''/recovery_password = $pg_password/" $PGPOOL_CONFIG_DIR/pgpool.conf
sed -i "s/recovery_1st_stage_command = ''/recovery_1st_stage_command = 'recovery_1st_stage'/" $PGPOOL_CONFIG_DIR/pgpool.conf
sed -i "s/use_watchdog = off/use_watchdog = on/" $PGPOOL_CONFIG_DIR/pgpool.conf
sed -i "s/wd_hostname = ''/wd_hostname = $wd_hostname/" $PGPOOL_CONFIG_DIR/pgpool.conf
sed -i "s/delegate_IP = ''/delegate_IP = $delegate_IP/" $PGPOOL_CONFIG_DIR/pgpool.conf
sed -i "s/heartbeat_destination0 = 'host0_ip1'/heartbeat_destination0 = $other_pgpool_hostname0/" $PGPOOL_CONFIG_DIR/pgpool.conf
#sed -i "s/wd_lifecheck_method = 'heartbeat'/wd_lifecheck_method = 'query'/" $PGPOOL_CONFIG_DIR/pgpool.conf
sed -i "s/wd_lifecheck_user = 'nobody'/wd_lifecheck_user = 'postgres'/" $PGPOOL_CONFIG_DIR/pgpool.conf
sed -i "s/wd_lifecheck_password = ''/wd_lifecheck_password = $pg_password/" $PGPOOL_CONFIG_DIR/pgpool.conf
sed -i "s/#other_pgpool_hostname0 = 'host0'/other_pgpool_hostname0 = $other_pgpool_hostname0/" $PGPOOL_CONFIG_DIR/pgpool.conf
sed -i "s/#other_pgpool_port0 = 5432/other_pgpool_port0 = 9999/" $PGPOOL_CONFIG_DIR/pgpool.conf
sed -i "s/#other_wd_port0 = 9000/other_wd_port0 = 9000/" $PGPOOL_CONFIG_DIR/pgpool.conf

##configuration pgpool log export to syslog
cat > /etc/rsyslog.d/pgpool.conf << EOT
$facility.*                                               /var/log/pgpool/pgpool.log
EOT

mkdir -p /var/log/pgpool;chmod 755 /var/log/pgpool
mkdir -p /var/lib/pgsql/trigger;chmod 777 /var/lib/pgsql/trigger

##start rsyslog service
if [ -f /var/run/syslogd.pid ];then
    service rsyslog restart
else
    service rsyslog start
fi

##pgpool logrotate
cat > /etc/logrotate.d/pgpool << EOT
/var/log/pgpool/pgpool.log
{
    weekly
    rotate 4
    create 0664 root opegrp
    postrotate
        /bin/kill -HUP `cat /var/run/syslogd.pid 2> /dev/null` 2> /dev/null || true
    endscript
}
EOT

chown postgres. /var/run/pgpool-II-96/ -R 
##start pgpool service
if [ -f /var/run/pgpool-II-96/pgpool.pid ];then 
    service pgpool-II-96 restart
else
    service pgpool-II-96 start
fi

##End
