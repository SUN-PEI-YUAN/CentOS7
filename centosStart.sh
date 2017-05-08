#!/bin/sh

#` Centos7
#`  系統帳號/密碼
#`      root：
#`      name1：
#`  MariaDB 
#`      root：
#`      name2：
#`  WordPress
#`      name3：
#`  Port
#`      ssh：22
#`      http：80
#`

#` 設定主機名稱和時區

hostnamectl set-hostname Yourhostname.com
timedatectl set-timezone "Asia/Taipei"
ntpdate tock.stdtime.gov.tw
hwclock -w
localectl set-locale LANG=en_US.utf8

#`MariabDB 10.1 rpm`
echo -e "# MariaDB 10.1 CentOS repository list - created 2017-04-09 17:13 UTC\n# http://downloads.mariadb.org/mariadb/repositories/\n[mariadb]\nname = MariaDB\nbaseurl = http://yum.mariadb.org/10.1/centos7-amd64\ngpgkey=https://yum.mariadb.org/RPM-GPG-KEY-MariaDB\npgcheck=1" > /etc/yum.repos.d/MariaDB.repo
#`nginx 1.12.0 rpm`
rpm -Uvh http://nginx.org/packages/centos/7/noarch/RPMS/nginx-release-centos-7-0.el7.ngx.noarch.rpm
#`php71w`
rpm -Uvh https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
rpm -Uvh https://mirror.webtatic.com/yum/el7/webtatic-release.rpm
#` python3.6
yum -y install https://centos7.iuscommunity.org/ius-release.rpm

#`start install software`

software="update development epel-release yum-utils net-tools vim nginx MariaDB-server MariaDB-client fail2ban python36u python36u-pip python36u-devel"
for i in ${software}
do
     if [ ${i} == "update" ]; then
        yum -y ${i};
     elif [ ${i} == "development" ]; then
        yum -y groupinstall ${i};
     else
        yum -y install ${i};
     fi
done

phpsoftware="php71w-cli php71w-common php71w-fpm php71w-gd php71w-mbstring php71w-mysql php71w-opcache php71w-pdo php71w-xml php71w-xmlrpc php71w-curl php71w-mcrypt"
for j in ${phpsoftware}
do
    yum -y install ${j};
    if [ ${j} == "php71w-mysql" ]; then
        yum -y remove ${j};
        yum -y install php71w-mysqlnd;
    fi
done

#`end of install software`

#` service config`
software="mariadb nginx sshd fail2ban"
for k in ${service}
do
    if [ ${k} == mariadb ]; then
        systemctl start mariadb.service;
        # echo -e '\n\n\nPassword\nPassword\n\n\n\n' | mysql_secure_installation
    if [ ${k} == nginx ]; then
        systemctl enable php-fpm;
        systemctl enable nginx;
        firewall-cmd --permanent --zone=public --add-service=http;
        firewall-cmd --permanent --zone=public --add-service=https;
        mkdir /var/log/nginx/phpMyAdmin;
        mkdir /var/log/nginx/threecooked.com;
        systemctl start php-fpm;
        systemctl start nginx;
    if [ ${k} == sshd ]; then
        firewall-cmd --zone=public --remove-service=ssh --permanent;
    if [ ${k} == fail2ban ]; then
        systemctl enable fail2ban;
        cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local;
        systemctl start fail2ban;
        #` /usr/bin/fail2ban-client -v -v start <<<用來 Debug
    fi
done

firewall-cmd --reload

#`download pma wordpress start`
mkdir /web
cd /web
wget https://tw.wordpress.org/latest-zh_TW.tar.gz
wget https://files.phpmyadmin.net/phpMyAdmin/4.7.0/phpMyAdmin-4.7.0-all-languages.tar.gz
for l in $(ls)
do
    tar -xf ${l}
done

cd /var/www
chown nginx:nginx -R /var/www/wordpress
cp config.sample.inc.php config.inc.php
mkdir /var/lib/php/session
chown nginx:nginx /var/lib/php/session
#`download pma wordpress end`

# `網頁ssl`
#`安裝certbot`

cd /opt
wget https://dl.eff.org/certbot-auto
chmod a+x certbot-auto
mkdir /opt/letsencrypt
mv certbot-auto /opt/letsencrypt/
/opt/letsencrypt/certbot-auto

cd letsencrypt
# 生成憑證
./certbot-auto certonly
/opt/letsencrypt/certbot-auto certonly --webroot -w /var/www -d Yourhostname.com

# 生成 dhparam.pem 
openssl dhparam -out dhparam.pem 2048
# openssl dhparam -out dhparam.pem 4096

# 測試
/opt/letsencrypt/certbot-auto renew --dry-run
# 若測試沒問題，就可以使用正式指令來更新：  
/opt/letsencrypt/certbot-auto renew --quiet --no-self-upgrade

# 而為了方便起見，可以將這個更新指令寫在 /opt/letsencrypt/renew.sh 指令稿中：
echo -e "/opt/letsencrypt/certbot-auto renew --quiet --no-self-upgrade --post-hook 'systemctl restart nginx'" > /opt/letsencrypt/renew.sh

crontab -e 
# 30 2 * * 0 /opt/letsencrypt/renew.sh
(crontab -l; 30 2 * * 0 /opt/letsencrypt/renew.sh) |uniq - | crontab -
