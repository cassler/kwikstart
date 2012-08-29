#!/bin/bash
#
# Install MySQL for Wordpress Multisite
#
# Assumes the host is clean unconfigured CentOS 6 / EL 6 derivatives (inc Amazon Linux AMI). Should be idempotent.
#
# Adlibre Pty Ltd 2012
#

## Configuration
ROOT_PASS_FILE='/etc/mysql_root_password'

## Constants
LOGFILE='install.log'

echo "### Beginning Install ###"

( # Start log capture

## Start

# Set password if not already exist
if [ ! -f ${ROOT_PASS_FILE} ]; then
    DB_ROOT_PASS=`tr -cd "[:alnum:]" < /dev/urandom | head -c 10` # 10 char random password
    touch ${ROOT_PASS_FILE}
    chmod 700 ${ROOT_PASS_FILE}
    echo ${DB_ROOT_PASS} > ${ROOT_PASS_FILE}
else
    DB_ROOT_PASS=`cat ${ROOT_PASS_FILE}`
fi

# Install base packages
yum -y install mysql-server

# turn on services
chkconfig mysqld on

# Configure MySQL
service mysqld restart

# **sigh** http://bugs.mysql.com/bug.php?id=53796
cat | /usr/bin/expect << EOF
    spawn /usr/bin/mysql_secure_installation
    
    expect "Enter current password for root (enter for none):"
    send "\r"
        
    expect "Set root password?"
    send "y\r"
    
    expect "New password:"
    send "${DB_ROOT_PASS}\r"
    
    expect "Re-enter new password:"
    send "${DB_ROOT_PASS}\r"
    
    expect "Remove anonymous users?"
    send "y\r"
    
    expect "Disallow root login remotely?"
    send "y\r"
    
    expect "Remove test database and access to it?"
    send "y\r"
    
    expect "Reload privilege tables now?"
    send "y\r"
    
    puts "Ended expect script."

EOF

# Configure MySQL for Wordpress Multisite usage
cp -n /etc/my.cnf /etc/my.cnf.orig # backup

# TODO: This config needs some generalisation. And should configure it's size based on host memory setting.
cat > /etc/my.cnf << EOF
# The MySQL server
[mysqld]
datadir=/var/lib/mysql
port=3306
socket=/var/lib/mysql/mysql.sock
user=mysql
# Disabling symbolic-links is recommended to prevent assorted security risks
symbolic-links=0

key_buffer_size = 512M
max_allowed_packet = 8M
table_open_cache = 512
sort_buffer_size = 2M
read_buffer_size = 2M
read_rnd_buffer_size = 8M
myisam_sort_buffer_size = 64M
thread_cache_size = 8
query_cache_size = 32M

# Multisite important config
table_cache=16384
table_definition_cache=16384

[mysqld_safe]
log-error=/var/log/mysqld.log
pid-file=/var/run/mysqld/mysqld.pid
EOF

# Start / Restart
service mysqld restart

) 2>&1 1>> ${LOGFILE} | tee -a ${LOGFILE} # stderr to console, stdout&stderr to logfile

echo "### Install Complete ###"