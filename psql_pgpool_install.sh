#!/bin/bash
PORT=5432
PGDIR=/var/lib/pgsql
DATADIR=$PGDIR/9.6/data/
PGHOME=/usr/pgsql-9.6
PSQL=/usr/bin/psql
SERVICE=/sbin/service
PASSWORD=1qaz2wsx
PGPOOL1=192.168.248.126
PGPOOL2=192.168.248.127
NETWORK=192.168.248.0/24
DEVICE=eth0

SCRIPT_DIR=$(cd "$(dirname "$0")"; pwd)

##install postgresql
yum localinstall pgpool-II-96-extensions-3.7.10-1.rhel6.x86_64.rpm pgpool-II-96-3.7.10-1.rhel6.x86_64.rpm postgresql96-server-9.6.13-1PGDG.rhel6.x86_64.rpm postgresql96-libs-9.6.13-1PGDG.rhel6.x86_64.rpm postgresql96-contrib-9.6.13-1PGDG.rhel6.x86_64.rpm postgresql96-9.6.13-1PGDG.rhel6.x86_64.rpm -y

su postgres -c "$PGHOME/bin/initdb -D $DATADIR"
echo $PASSWORD | passwd --stdin postgres

mkdir /var/lib/pgsql/archivedir

cp /var/lib/pgsql/9.6/data/postgresql.conf /var/lib/pgsql/9.6/data/postgresql.conf.old
##configure postgresql.conf
sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/" /var/lib/pgsql/9.6/data/postgresql.conf
sed -i "s/#wal_level = minimal/wal_level = hot_standby/" /var/lib/pgsql/9.6/data/postgresql.conf
sed -i "s/#archive_mode = off/archive_mode = on/" /var/lib/pgsql/9.6/data/postgresql.conf
sed -i "s@#archive_command = ''@archive_command = 'cp "%p" "/var/lib/pgsql/archivedir/%f"'@" /var/lib/pgsql/9.6/data/postgresql.conf
sed -i "s/#max_wal_senders = 0/max_wal_senders = 2/" /var/lib/pgsql/9.6/data/postgresql.conf
sed -i "s/log_filename = 'postgresql-%a.log'/log_filename = 'postgresql-%Y-%m-%d_%H%M%S.log'/" /var/lib/pgsql/9.6/data/postgresql.conf

##configure pg_hba.conf
mv /var/lib/pgsql/9.6/data/pg_hba.conf /var/lib/pgsql/9.6/data/pg_hba.conf.old
cat > /var/lib/pgsql/9.6/data/pg_hba.conf << EOT
local   all             all                                     trust
host    all             all             127.0.0.1/32            trust
host    all             all             $PGPOOL1/32          password
host    all             all             $PGPOOL2/32          password
host    all             all             ::1/128                 trust
local   replication     postgres                                trust
host    replication     postgres        $NETWORK           trust
host    replication     postgres        ::1/128                 trust
EOT

##create basebackup.sh
cat > /var/lib/pgsql/9.6/data/recovery_1st_stage << EOT
#!/bin/bash -x
# Recovery script for streaming replication.

pgdata=\$1
remote_host=\$2
remote_pgdata=\$3
port=\$4

pghome=/usr/pgsql-9.6
archivedir=/var/lib/pgsql/archivedir
hostname=\$(hostname)

ssh -T postgres@\$remote_host "
rm -rf \$remote_pgdata
\$pghome/bin/pg_basebackup -h \$hostname -U postgres -D \$remote_pgdata -x -c fast
rm -rf \$archivedir/*

cd \$remote_pgdata
cp postgresql.conf postgresql.conf.bak
sed -e 's/#*hot_standby = off/hot_standby = on/' postgresql.conf.bak > postgresql.conf
rm -f postgresql.conf.bak
cat > recovery.conf << EOF
standby_mode = 'on'
primary_conninfo = 'host="\$hostname" port=\$port user=postgres'
restore_command = 'scp \$hostname:\$archivedir/%f %p'
EOF
"
EOT

##create pgpool_remote_start
cat > /var/lib/pgsql/9.6/data/pgpool_remote_start << EOT
#! /bin/sh -x

pghome=/usr/pgsql-9.6
remote_host=\$1
remote_pgdata=\$2

# Start recovery target PostgreSQL server
ssh -T \$remote_host \$pghome/bin/pg_ctl -w -D \$remote_pgdata start > /dev/null 2>&1 < /dev/null &
EOT



chown -R postgres.postgres $PGDIR
chmod -R 700 $PGDIR
chmod +x $DATADIR/{recovery_1st_stage,pgpool_remote_start}
chmod +x /etc/init.d/postgresql-9.6

##start psql,modify postgres password and create function,then stop psql
/etc/init.d/postgresql-9.6 start
$PSQL -U postgres -c "alter user postgres with password '$PASSWORD';"

$PSQL -U postgres -f /usr/pgsql-9.6/share/extension/pgpool-recovery.sql postgres
$PSQL -U postgres -f /usr/pgsql-9.6/share/extension/pgpool-recovery.sql template1
$PSQL -U postgres -f /usr/pgsql-9.6/share/extension/pgpool-regclass.sql postgres
$PSQL -U postgres -f /usr/pgsql-9.6/share/extension/pgpool-regclass.sql template1

/etc/init.d/postgresql-9.6 stop
