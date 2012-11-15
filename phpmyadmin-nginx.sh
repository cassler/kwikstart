#!/bin/bash
#
# Setup phpMyAdmin running under Nginx
#
# Assumes the host is CentOS 6 / EL 6 derivatives (inc Amazon Linux AMI) and Nginx / PHP already setup. Should be idempotent.
#
# Adlibre Pty Ltd 2012
#

## Configuration
SERVER_NAME="phpmyadmin.`hostname`"
WWW_ROOT="/srv/www/${SERVER_NAME}"
SSL=False

## Constants
LOGFILE='install.log'

echo "### Beginning Install ###"

( # Start log capture

## Start

mkdir -p ${WWW_ROOT}

# Configure Nginx vhost
cat > /etc/nginx/conf.d/${SERVER_NAME}-phpmyadmin.conf << EOF
    # phpMyAdmin Nginx Config for ${SERVER_NAME}
    
    server {
        listen  80;
        server_name_in_redirect off;
        server_name ${SERVER_NAME};
        root    ${WWW_ROOT};
        index   index.php index.html index.htm;        
$(
if [ $SSL == True ]; then
cat << EOFA
        
        # SSL
        listen 443 default ssl;
        if (\$server_port = 443) { set \$https on; }
        if (\$server_port = 80) { set \$https off; }
        
        ssl_certificate /etc/pki/tls/certs/${SERVER_NAME}.crt;
        ssl_certificate_key /etc/pki/tls/private/${SERVER_NAME}.key;
        
EOFA
fi
)       
        # Output compression
        gzip on;
        gzip_disable "msie6";
        gzip_http_version 1.0;
        gzip_vary on;
        gzip_comp_level 5;
        gzip_proxied any;
        gzip_types text/plain text/css application/json application/x-javascript text/xml application/xml application/xml+rss text/javascript;
        gzip_buffers 16 8k;
        
        # Max file upload
        client_max_body_size 32M;
        
        location / {
            # if the requested file exists, return it immediately
            if (-f \$request_filename) {
                break;
            }
        }

        # Pass PHP scripts on to PHP-FASTCGI
        location ~ \.php$ {
            include /etc/nginx/fastcgi_params;
            fastcgi_pass  127.0.0.1:9000;
            fastcgi_index index.php;
            fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
            fastcgi_read_timeout 300; # increase timeout incase our mysql is on different servers
        }

        # Don't serve .htaccess, .svn or .git
        location ~ \.(htaccess|svn|git) {
            deny  all;
        }        
    }
EOF

# Install phpMyAdmin
wget http://sourceforge.net/projects/phpmyadmin/files/latest/download -O /tmp/phpmyadmin-latest.tar.bz2 && \
tar -xjf /tmp/phpmyadmin-latest.tar.bz2 -C ${WWW_ROOT} && rm -f /tmp/phpmyadmin-latest.tar.bz2

# Start / Restart
service spawn-fcgi restart
service nginx restart 

) 2>&1 1>> ${LOGFILE} | tee -a ${LOGFILE} # stderr to console, stdout&stderr to logfile

echo "### Install Complete ###"
