# Docker 镜像

> 集成 FastDFS, Nginx, PHP 等多种软件的 Docker 镜像, 免除 FastDFS 构建文件管理服务过程中一系列的关联服务的繁琐操作，该镜像已经上传至 Docker Hub.
> >
> FastDFS: 一个开源的轻量级分布式文件系统, 解决大容量存储和负载均衡问题 ( [https://github.com/happyfish100/fastdfs](https://github.com/happyfish100/fastdfs) ) .
> >
> 镜像构建: `docker build -t miitvip/nginx-php-fastdfs .`

## 0. 更新说明

```shell
[ ------------ 2022-12-20 ------------ ]
1. php 更新至 8.2.0
2. nginx 更新至 1.22.1
3. php redis 更新至 5.3.7


[ ------------ 2019-12-19 ------------ ]
1. php 更新至 7.4.1


[ ------------ 2019-11-29 ------------ ]
1. nginx 更新至 1.17.6
2. php 更新至 7.3.12
3. 新增 composer
4. 更新启动脚本 start.sh
```

## 1. 拉取镜像

`docker pull miitvip/nginx-php-fastdfs`

## 2. 创建目录

```shell
# 运行之前，创建好相应的文件目录，例如：

mkdir -p /miitvip/logs/php \
/miitvip/logs/nginx \
/miitvip/docker/nginx/ \
/miitvip/docker/nginx/ssl \
/miitvip/docker/nginx/letsencrypt \
/miitvip/docker/fastdfs/tracker \
/miitvip/docker/fastdfs/storage \
/miitvip/docker/fastdfs/client \
/miitvip/docker/fastdfs/conf \
/miitvip/web/fastdfs
```

## 3. 临时容器

`docker run --name php -p 9000:9000 -d --restart=always miitvip/nginx-php-fastdfs php`

## 4. 进入容器

`docker exec -it php /bin/bash`

## 5. 查看信息

```shell
php -r 'phpinfo();'

# 注意如下两个信息
...
Configuration File (php.ini) Path => /usr/local/etc/php
extension_dir => /usr/local/lib/php/extensions/no-debug-non-zts-20180731
...
```

## 6. 复制文件

```shell
# docker ps 查看容器信息
# 666f8de6d689 为刚刚启动的临时 PHP 容器ID 或可以直接将 id 改成 name

docker cp 666f8de6d689:/usr/local/lib/php/extensions/no-debug-non-zts-20180731/ /miitvip/docker/php/
mv /miitvip/docker/php/no-debug-non-zts-20180731 /miitvip/docker/php/ext
docker cp 666f8de6d689:/usr/local/etc/php/php.ini /miitvip/docker/php/php.ini

```

## 7. 启动 php

```shell
# 关闭临时 PHP 并删除后再次启动 PHP
# 注意 -v /miitvip/web:/www 的映射需要与 nginx 两边保持一致

docker stop php
docker rm php
docker run --name php -p 9000:9000 \
-v /miitvip/web:/www:rw \
-v /miitvip/logs/php:/var/log/php \
-v /miitvip/docker/php/ext:/usr/local/lib/php/extensions/no-debug-non-zts-20180731 \
-v /miitvip/docker/php/php.ini:/usr/local/etc/php/php.ini \
-d --restart=always --link mysql:mysql miitvip/nginx-php-fastdfs php

```

## 8. 启动 nginx

```shell
docker run -d -ti --name nginx \
-p 80:80 -p 443:443 \
-v /miitvip/web:/www \
-v /miitvip/logs/nginx:/var/log/nginx \
-v /miitvip/docker/nginx/nginx.conf:/etc/nginx/nginx.conf:ro \
-v /miitvip/docker/nginx/conf.d:/etc/nginx/conf.d \
-v /miitvip/docker/nginx/ssl:/etc/nginx/ssl \
-v /miitvip/docker/nginx/letsencrypt:/etc/nginx/letsencrypt \
-v /miitvip/web/fastdfs:/fastdfs/store \
--link php:php \
--restart=always miitvip/nginx-php-fastdfs nginx
```

## 9. 启动 fastdfs

```shell
docker run -d -ti --name fastdfs \
-p 8888:8888 -p 22122:22122 -p 23000:23000 \
-e GROUP_NAME=MIIT \
-e TRACKER_SERVER=服务器IP地址 \
-v /miitvip/docker/fastdfs/tracker:/fastdfs/tracker \
-v /miitvip/docker/fastdfs/storage:/fastdfs/storage \
-v /miitvip/docker/fastdfs/client:/fastdfs/client \
-v /miitvip/docker/fastdfs/conf/tracker.conf:/etc/fdfs/tracker.conf \
-v /miitvip/docker/fastdfs/conf/storage.conf:/etc/fdfs/storage.conf \
-v /miitvip/docker/fastdfs/conf/mod_fastdfs.conf:/etc/fdfs/mod_fastdfs.conf \
-v /miitvip/docker/fastdfs/conf/client.conf:/etc/fdfs/client.conf \
-v /miitvip/docker/fastdfs/conf/http.conf:/etc/fdfs/http.conf \
-v /miitvip/web/fastdfs:/fastdfs/store \
--restart=always miitvip/nginx-php-fastdfs fastdf
```

## 10. 测试

```shell
docker exec -it fastdfs /bin/bash
/usr/bin/fdfs_monitor /etc/fdfs/storage.conf

# 执行后出现如下提示信息
DEBUG - base_path=/fastdfs/storage, connect_timeout=10, network_timeout=60, tracker_server_count=1,
anti_steal_token=0, anti_steal_secret_key length=0, use_connection_pool=0,
g_connection_pool_max_idle_time=3600s, use_storage_id=0, storage server id count: 0

server_count=1, server_index=0

tracker server is 你的服务器IP:22122

group count: 1

Group 1:
group name = MIIT
disk total space = 50,26700 MB
disk free space = 41,44800 MB
trunk free space = 0 MB
storage server count = 1
active server count = 1
storage server port = 23000
storage HTTP port = 8888
store path count = 1
subdir count per path = 256
current write server index = 0
current trunk file id = 0

 Storage 1:
  id = 106.52.100.29
  ip_addr = 你的服务器IP  ACTIVE
  http domain = 
  version = 6.06
  join time = 2020-01-01 09:43:23
  up time = 2020-01-01 09:43:23
  total storage = 50,26700 MB
  free storage = 41,44800 MB
  upload priority = 10
  store_path_count = 1
  subdir_count_per_path = 256
  storage_port = 23000
  storage_http_port = 8888
  current_write_path = 0
  source storage id = 
  if_trunk_server = 0
  connection.alloc_count = 256
  connection.current_count = 0
  connection.max_count = 0
  total_upload_count = 0
  success_upload_count = 0
  total_append_count = 0
  success_append_count = 0
  total_modify_count = 0
  success_modify_count = 0
  total_truncate_count = 0
  success_truncate_count = 0
  total_set_meta_count = 0
  success_set_meta_count = 0
  total_delete_count = 0
  success_delete_count = 0
  total_download_count = 0
  success_download_count = 0
  total_get_meta_count = 0
  success_get_meta_count = 0
  total_create_link_count = 0
  success_create_link_count = 0
  total_delete_link_count = 0
  success_delete_link_count = 0
  total_upload_bytes = 0
  success_upload_bytes = 0
  total_append_bytes = 0
  success_append_bytes = 0
  total_modify_bytes = 0
  success_modify_bytes = 0
  stotal_download_bytes = 0
  success_download_bytes = 0
  total_sync_in_bytes = 0
  success_sync_in_bytes = 0
  total_sync_out_bytes = 0
  success_sync_out_bytes = 0
  total_file_open_count = 0
  success_file_open_count = 0
  total_file_read_count = 0
  success_file_read_count = 0
  total_file_write_count = 0
  success_file_write_count = 0
  last_heart_beat_time = 2020-01-02 07:15:27
  last_source_update = 1970-01-01 00:00:00
  last_sync_update = 1970-01-01 00:00:00
  last_synced_timestamp = 1970-01-01 00:00:00
```

## 11. 问题

> 若 FastDFS 启动失败，请进入 fastdfs 容器，手动启动 tracker & storage 后再试

```shell
docker exec -it fastdfs /bin/bash
/usr/bin/fdfs_trackerd /etc/fdfs/tracker.conf start
/usr/bin/fdfs_storaged /etc/fdfs/storage.conf start

# 再次查看是否正常
/usr/bin/fdfs_monitor /etc/fdfs/storage.conf
```

> 重启 nginx

```shell
docker restart nginx
```
