#!/bin/bash

if [[ $TRACKER_SERVER ]]; then

    echo -e "---------------------------------------------------------------"
    echo -e "--- *** FASTDFS CONFIGURATION OVERRIDE @ tracker-server *** ---"
    echo -e "---------------------------------------------------------------"

    new_ip=$TRACKER_SERVER
    old_ip="127.0.0.1"

    echo "$(sed "s/$old_ip/$new_ip/g" /etc/fdfs/client.conf)" > /etc/fdfs/client.conf
    echo "$(sed "s/$old_ip/$new_ip/g" /etc/fdfs/storage.conf)" > /etc/fdfs/storage.conf
    echo "$(sed "s/$old_ip/$new_ip/g" /etc/fdfs/mod_fastdfs.conf)" > /etc/fdfs/mod_fastdfs.conf

fi

if [[ $GROUP_NAME ]]; then

    echo -e "-----------------------------------------------------------"
    echo -e "--- *** FASTDFS CONFIGURATION OVERRIDE @ group-name *** ---"
    echo -e "-----------------------------------------------------------"

    new_group_name=$GROUP_NAME
    old_group_name="MIIT"

    echo "$(sed "s/$old_group_name/$new_group_name/g" /etc/fdfs/storage.conf)" > /etc/fdfs/storage.conf

fi

case $1 in
nginx )
    echo -e "---------------------------"
    echo -e "--- *** START NGINX *** ---"
    echo -e "---------------------------"
    /usr/sbin/nginx
    ;;
php )
    echo -e "-------------------------"
    echo -e "--- *** START PHP *** ---"
    echo -e "-------------------------"
    /usr/local/sbin/php-fpm
    ;;
fastdfs )
    echo -e "-----------------------------"
    echo -e "--- *** START TRACKER *** ---"
    echo -e "-----------------------------"
    /etc/init.d/fdfs_trackerd start
    echo -e "-----------------------------"
    echo -e "--- *** START STORAGE *** ---"
    echo -e "-----------------------------"
    /etc/init.d/fdfs_storaged start
    ;;
tracker )
    echo -e "-----------------------------"
    echo -e "--- *** START TRACKER *** ---"
    echo -e "-----------------------------"
    /etc/init.d/fdfs_trackerd start
    ;;
storage )
    echo -e "-----------------------------"
    echo -e "--- *** START STORAGE *** ---"
    echo -e "-----------------------------"
    /etc/init.d/fdfs_storaged start
    ;;
* )
    echo -e "---------------------------"
    echo -e "--- *** START NGINX *** ---"
    echo -e "---------------------------\n"
    /usr/sbin/nginx

    echo -e "-------------------------"
    echo -e "--- *** START PHP *** ---"
    echo -e "-------------------------\n"
    /usr/local/sbin/php-fpm

    echo -e "-----------------------------"
    echo -e "--- *** START TRACKER *** ---"
    echo -e "-----------------------------\n"
    /etc/init.d/fdfs_trackerd start

    echo -e "-----------------------------"
    echo -e "--- *** START STORAGE *** ---"
    echo -e "-----------------------------\n"
    /etc/init.d/fdfs_storaged start
esac

tail -f  /dev/null
