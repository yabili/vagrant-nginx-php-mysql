#!/bin/bash

# Set locale
#export LANGUAGE=en_US.UTF-8
#export LANG=en_US.UTF-8
#export LC_ALL=en_US.UTF-8
#locale-gen en_US.UTF-8
#dpkg-reconfigure locales

# Repair "==> default: stdin: is not a tty" message
sudo sed -i '/tty/!s/mesg n/tty -s \\&\\& mesg n/' /root/.profile

# In order to avoid the message
# "==> default: dpkg-preconfigure: unable to re-open stdin: No such file or directory"
# use " > /dev/null 2>&1" in order to redirect stdout to /dev/null
# For more info see http://stackoverflow.com/questions/10508843/what-is-dev-null-21

# Remove no longer required packages
echo "Removing no longer required packages"
sudo apt-get autoremove -yf >> $VAGRANT_BUILD_LOG 2>&1

# Install tools
echo "Updating apt-get"
sudo apt-get update -y > $VAGRANT_BUILD_LOG 2>&1

echo "Installing utilities (CURL, GIT, UNZIP)"
sudo apt-get install -y curl git unzip >> $VAGRANT_BUILD_LOG 2>&1

# Install NGINX
# ( Web server document root: /usr/share/nginx/html -> /vagrant/php-app )
# ( Nginx default user: www-data )
# ( Default site configuration file: /etc/nginx/sites-enabled/default )
# ( Virtual sites defined in: /etc/nginx/sites-enabled )
echo "Installing Nginx"
sudo apt-get install -y nginx >> $VAGRANT_BUILD_LOG 2>&1
nginx -v >> $VAGRANT_BUILD_LOG 2>&1

# Install PHP-FPM 7.0
# ( Configuration files for PHP 7.0 in /etc/php/7.0 )
# ( PHP-FPM Unix socket: /var/run/php/php7.0-fpm.sock )
# ( PHP-FPM TCP socket: 127.0.0.1:9000 )
echo "Updating PHP repository"
sudo apt-get install -y language-pack-en-base >> $VAGRANT_BUILD_LOG 2>&1
sudo LC_ALL=en_US.UTF-8 add-apt-repository ppa:ondrej/php >> $VAGRANT_BUILD_LOG 2>&1
sudo apt-get update -y >> $VAGRANT_BUILD_LOG 2>&1

echo "Installing PHP-FPM 7.0 & extensions"
sudo apt-get install -y php7.0-fpm php7.0-cli php7.0-common php-pear php7.0-intl \
                        php7.0-json php7.0-xml php7.0-zip php7.0-bz2 \
                        php7.0-opcache php7.0-mysql php7.0-curl php7.0-readline >> $VAGRANT_BUILD_LOG 2>&1
# Other PHP modules
# php7.0-apcu php7.0-memcached php7.0-mcrypt php7.0-pspell php7.0-redis php7.0-mcrypt php7.0-gd php7.0-imap
# php7.0-cgi php7.0-phpdbg libphp7.0-embed php7.0-dbg php7.0-enchant php7.0-gmp php7.0-interbase php7.0-ldap
# php7.0-odbc php7.0-pgsql php7.0-pspell php7.0-recode php7.0-snmp php7.0-tidy php7.0-xmlrpc php7.0-xsl php7.0-sybase
# php7.0-dev php-all-dev php7.0-modules-source
php --version >> $VAGRANT_BUILD_LOG 2>&1

echo "Configuring Nginx"
sudo cp $NGINX_CONF /etc/nginx/sites-available/vhost >> $VAGRANT_BUILD_LOG 2>&1
ln -s /etc/nginx/sites-available/vhost /etc/nginx/sites-enabled/
sudo rm -rf /etc/nginx/sites-available/default
sudo rm -rf /etc/nginx/sites-enabled/default

# link app root folder
ln -s /vagrant/php-app/* /usr/share/nginx/html/

echo "Configuring PHP"
sudo cp $PHP_FPM_CONF /etc/php/7.0/fpm/php-fpm.conf >> $VAGRANT_BUILD_LOG 2>&1
sudo cp $PHP_INI /etc/php/7.0/fpm/php.ini >> $VAGRANT_BUILD_LOG 2>&1

echo "Restarting Nginx service"
sudo service nginx restart >> $VAGRANT_BUILD_LOG 2>&1

echo "Restarting PHP service"
sudo service php7.0-fpm restart >> $VAGRANT_BUILD_LOG 2>&1

# Install MySQL 5.6
echo "Installing MySQL 5.6"
debconf-set-selections <<< "mysql-server-5.6 mysql-server/root_password password $DB_ROOT_PASSWORD"
debconf-set-selections <<< "mysql-server-5.6 mysql-server/root_password_again password $DB_ROOT_PASSWORD"
sudo apt-get install -y mysql-server-5.6 >> $VAGRANT_BUILD_LOG 2>&1
mysql --version >> $VAGRANT_BUILD_LOG 2>&1

echo "Creating Database and User"
if [ ! -f /var/log/dbinstalled ];
then
    echo "CREATE USER '$DBUSER'@'$DB_HOST' IDENTIFIED BY '$DB_PASSWORD'" | mysql -uroot -p$DB_ROOT_PASSWORD >> $VAGRANT_BUILD_LOG 2>&1
    echo "CREATE DATABASE $DB_NAME" | mysql -uroot -p$DB_ROOT_PASSWORD >> $VAGRANT_BUILD_LOG 2>&1
    echo "GRANT ALL ON $DB_NAME.* TO '$DBUSER'@'$DB_HOST'" | mysql -uroot -p$DB_ROOT_PASSWORD >> $VAGRANT_BUILD_LOG 2>&1
    echo "flush privileges" | mysql -uroot -p$DB_ROOT_PASSWORD >> $VAGRANT_BUILD_LOG 2>&1
    touch /var/log/dbinstalled
    if [ -f /vagrant/provision/mysql/loadschema.sql ];
    then
        mysql -uroot -p$DB_ROOT_PASSWORD $DB_NAME < /vagrant/provision/mysql/loadschema.sql >> $VAGRANT_BUILD_LOG 2>&1
    fi
fi

echo "Restarting MySQL service"
sudo service mysql restart >> $VAGRANT_BUILD_LOG 2>&1

# Install Composer
echo "Installing Composer"
cd /usr/local/bin
if [ ! -f composer ];
then
    curl -sS https://getcomposer.org/installer | php
    ln -s composer.phar composer
fi
chmod a+x composer.phar

# Go to app root folder
cd /vagrant/php-app

# Launch Composer
echo "Launching 'composer install'"
if [[ -s /vagrant/php-app/composer.json ]];
then
  sudo -u vagrant -H sh -c "composer install"
fi
