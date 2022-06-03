#!/bin/bash 

#this script used to install zabbix server and zabbix agent both on one server
#for this to run properly you need a fresh installation on CentOS 7 with internet connection
#there also Granfana installed just to make it enough

#update systemctl and disable selinux
yum -y update
sed -i -e 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
setenforce 0

#Bypass firewalld

systemctl stop --now firewalld
systemctl mask firewalld 

#Import zabbix repo:

rpm -Uvh https://repo.zabbix.com/zabbix/5.0/rhel/7/x86_64/zabbix-release-5.0-1.el7.noarch.rpm
yum clean all

# Installing needed packages for zabbix:

yum -y install vim wget httpd mariadb mariadb-server zabbix-server-mysql zabbix-agent epel-release  pwgen  centos-release-scl-rh rh-php72* zabbix-web-mysql-scl zabbix-apache-conf-scl

sed -i -e 's/enabled=0/enabled=1/g' /etc/yum.repos.d/zabbix.repo

systemctl enable --now httpd 

#PHP paramenter:

sed -i -e 's/php_value[max_execution_time] = 300/php_value[max_execution_time] = 600/g' /etc/opt/rh/rh-php72/php-fpm.d/zabbix.conf
sed -i -e 's/php_value[max_input_time] = 300/php_value[max_input_time] = 600/g' /etc/opt/rh/rh-php72/php-fpm.d/zabbix.conf
sed -i -e 's/php_value[memory_limit] = 128M/php_value[memory_limit] = 1024M/g' /etc/opt/rh/rh-php72/php-fpm.d/zabbix.conf
sed -i -e 's/php_value[post_max_size] = 16M/php_value[post_max_size] = 32M/g' /etc/opt/rh/rh-php72/php-fpm.d/zabbix.conf
sed -i -e 's/php_value[upload_max_filesize] = 2M/php_value[upload_max_filesize] = 32M/g' /etc/opt/rh/rh-php72/php-fpm.d/zabbix.conf
sed -i '$ d' /etc/opt/rh/rh-php72/php-fpm.d/zabbix.conf
echo "php_value[date.timezone] = Asia/Ho_Chi_Minh" >>  /etc/opt/rh/rh-php72/php-fpm.d/zabbix.conf

#sed -i -e 's/; php_value[date.timezone] = Europe\/Riga/php_value[date.timezone] = Asia\/Ho_Chi_Minh/g' /etc/opt/rh/rh-php72/php-fpm.d/zabbix.conf

#mysql start and auto create root user:
#this part stole on Stack, if there better one, please guide me

systemctl enable --now mariadb
pgrep mysql | xargs kill -9  > /dev/null 2>&1
mysqld_safe --skip-grant-tables >res 2>&1 &
sleep 6
DB_ROOT_PASS='somepassword'
DB_ROOT_USER='root'
mysql mysql -e "UPDATE user SET Password=PASSWORD('$DB_ROOT_PASS') WHERE User='$DB_ROOT_USER';FLUSH PRIVILEGES;"
pgrep mysql | xargs kill -9
systemctl restart mariadb


systemctl enable rh-php72-php-fpm
systemctl enable --now zabbix-server

mysql -u root -p$DB_ROOT_PASS -e "CREATE DATABASE somedb CHARACTER SET UTF8 COLLATE UTF8_BIN;"
mysql  -u root -p$DB_ROOT_PASS -e "CREATE USER 'zabbix'@'localhost' IDENTIFIED BY 'somepassword'" 
mysql  -u root -p$DB_ROOT_PASS -e "GRANT ALL PRIVILEGES ON zabbixdb.* to 'zabbix'@'localhost'"
mysql  -u root -p$DB_ROOT_PASS  -e "FLUSH PRIVILEGES"
zcat /usr/share/doc/zabbix-server-mysql-5.0.19/create.sql.gz | mysql -uzabbix -pzabbixpass zabbixdb
sed -i -e 's/DBName=zabbix/DBName=somedb/g' /etc/zabbix/zabbix_server.conf
#sed -i -e 's/DBUser=zabbix/DBUser=zabbix/g' /etc/zabbix/zabbix_server.conf
sed -i -e 's/# DBPassword=/DBPassword=somepassword/g' /etc/zabbix/zabbix_server.conf

systemctl restart zabbix-server zabbix-agent httpd rh-php72-php-fpm mariadb
systemctl status zabbix-server zabbix-agent httpd rh-php72-php-fpm mariadb
systemctl restart httpd zabbix-server mariadb

systemctl daemon-reload
#Install grafana:

wget https://dl.grafana.com/oss/release/grafana-8.0.0~beta3-1.x86_64.rpm
yum install grafana-8.0.0~beta3-1.x86_64.rpm
systemctl daemon-reload
systemctl enable --now grafana-server

#One all of this is done, access: http://localhost/zabbix and localhost:3000 for grafana 
#bash forever.
