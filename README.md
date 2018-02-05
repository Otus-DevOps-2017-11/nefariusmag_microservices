Dmitriy Erokhin - nefariusmag

---
Homework 17
---

Работа с networks и docker-compose

Для создания сети используется команда:
`docker network create reddit --driver bridge`
Мост указывать не обязательно, он использует по умолчанию.

Контейнерам присваиваются имя или сетевые алиасы при старте:
--name <name> (можно задать только 1 имя)
--network-alias <alias-name> (можно задать множество алиасов)

Для создания сетей с отдельными подсетями к команде создания сети необходимо добавить аргумент --subnet
`docker network create back_net --subnet=10.0.2.0/24`

Для добавления контейнера в сеть можно использвоать команду:
`docker network connect <network> <container>`

Для удобства работы с docker используется docker-compose, можно все настройки закинуть в yml-файл. Поддерживается следующая структура:
```
version: '3.3'
services:
  post_db:
    image: mongo:3.2
    volumes:
      - post_db:/data/db
    networks:
      - reddit
  ui:
    build: ./ui
    image: ${USERNAME}/ui:1.0
    ports:
      - 9292:9292/tcp
    networks:
      - reddit
  post:
    build: ./post-py
    image: ${USERNAME}/post:1.0
    networks:
      - reddit
  comment:
    build: ./comment
    image: ${USERNAME}/comment:1.0
    networks:
      - reddit

volumes:
  post_db:

networks:
  reddit:
```

Запускется через:
`docker-compose up -d`

Если необходимо, чтобы переменные брались из файла .env, то прописываем дополнительно конструкцию:
`env_file: .env`


Задание со *

С помощью bridge-utils и докер-команд можно расмотреть как выглядит весь сетевой стек.

docker network ls
```
docker-user@docker-host:~$ sudo  docker network ls
NETWORK ID          NAME                DRIVER              SCOPE
0918ecacbffd        back_net            bridge              local
879cba15db5a        bridge              bridge              local
44805c78d030        front_net           bridge              local
362f774f8e0b        host                host                local
52227594e995        none                null                local
18874760deb6        reddit              bridge              local
```
Через ifconfig можно расмотреть созданные мосты:
ifconfig | grep br
```
docker-user@docker-host:~$ ifconfig | grep br -A 8
br-0918ecacbffd Link encap:Ethernet  HWaddr 02:42:72:22:12:34  
          inet addr:10.0.2.1  Bcast:10.0.2.255  Mask:255.255.255.0
          inet6 addr: fe80::42:72ff:fe22:1234/64 Scope:Link
          UP BROADCAST RUNNING MULTICAST  MTU:1500  Metric:1
          RX packets:104 errors:0 dropped:0 overruns:0 frame:0
          TX packets:115 errors:0 dropped:0 overruns:0 carrier:0
          collisions:0 txqueuelen:0
          RX bytes:6862 (6.8 KB)  TX bytes:17430 (17.4 KB)

br-18874760deb6 Link encap:Ethernet  HWaddr 02:42:aa:1a:b8:6f  
          inet addr:172.18.0.1  Bcast:172.18.255.255  Mask:255.255.0.0
          inet6 addr: fe80::42:aaff:fe1a:b86f/64 Scope:Link
          UP BROADCAST MULTICAST  MTU:1500  Metric:1
          RX packets:5449 errors:0 dropped:0 overruns:0 frame:0
          TX packets:5468 errors:0 dropped:0 overruns:0 carrier:0
          collisions:0 txqueuelen:0
          RX bytes:371368 (371.3 KB)  TX bytes:883026 (883.0 KB)

br-44805c78d030 Link encap:Ethernet  HWaddr 02:42:21:14:33:51  
          inet addr:10.0.1.1  Bcast:10.0.1.255  Mask:255.255.255.0
          inet6 addr: fe80::42:21ff:fe14:3351/64 Scope:Link
          UP BROADCAST RUNNING MULTICAST  MTU:1500  Metric:1
          RX packets:36 errors:0 dropped:0 overruns:0 frame:0
          TX packets:52 errors:0 dropped:0 overruns:0 carrier:0
          collisions:0 txqueuelen:0
          RX bytes:4598 (4.5 KB)  TX bytes:6042 (6.0 KB)
```
brctl уточнит какие veth-интерфейсы созданные докером объедененны мостом
```
docker-user@docker-host:~$  brctl show br-44805c78d030
bridge name	bridge id		STP enabled	interfaces
br-44805c78d030		8000.024221143351	no		veth0402a5b
							vethbc1c884
							vethbd034c8
```

Используя iptables видно какие разрешения созданы командок -p port:port
```
docker-user@docker-host:~$ sudo iptables -nL -t nat
Chain PREROUTING (policy ACCEPT)
target     prot opt source               destination         
DOCKER     all  --  0.0.0.0/0            0.0.0.0/0            ADDRTYPE match dst-type LOCAL

Chain INPUT (policy ACCEPT)
target     prot opt source               destination         

Chain OUTPUT (policy ACCEPT)
target     prot opt source               destination         
DOCKER     all  --  0.0.0.0/0           !127.0.0.0/8          ADDRTYPE match dst-type LOCAL

Chain POSTROUTING (policy ACCEPT)
target     prot opt source               destination         
MASQUERADE  all  --  10.0.1.0/24          0.0.0.0/0           
MASQUERADE  all  --  10.0.2.0/24          0.0.0.0/0           
MASQUERADE  all  --  172.18.0.0/16        0.0.0.0/0           
MASQUERADE  all  --  172.17.0.0/16        0.0.0.0/0           
MASQUERADE  tcp  --  10.0.1.2             10.0.1.2             tcp dpt:9292

Chain DOCKER (2 references)
target     prot opt source               destination         
RETURN     all  --  0.0.0.0/0            0.0.0.0/0           
RETURN     all  --  0.0.0.0/0            0.0.0.0/0           
RETURN     all  --  0.0.0.0/0            0.0.0.0/0           
RETURN     all  --  0.0.0.0/0            0.0.0.0/0           
DNAT       tcp  --  0.0.0.0/0            0.0.0.0/0            tcp dpt:9292 to:10.0.1.2:9292
```

Так же видно какую проксю прокинул докер:
```
docker-user@docker-host:~$ ps ax | grep docker-proxy
15084 ?        Sl     0:00 /usr/bin/docker-proxy -proto tcp -host-ip 0.0.0.0 -host-port 9292 -container-ip 10.0.1.2 -container-port 9292
```

Задание со *

Для обозначения "проектноого" имени явным видом можно использовать следующие варианты:
- Через аргумент -p dima при запуске docker-compose
- Через переменную COMPOSE_PROJECT_NAME=reddit в системе или .env
- Через имя папки в которой находится и запускается проект

---
Homework 16
---

Осваиваем Dockerfile

Образ собирается командой
```
docker build -t nefariusmag/comment:1.0 ./comment
docker build -t nefariusmag/post:1.0 ./post-py
docker build -t nefariusmag/ui:1.0 ./ui
```

Если Dockerfile выглядит не стандартно, то его надо указать явно
`docker build -t nefariusmag/ui:1.0 -f ./ui/Dockerfile ./ui`

Запуск через:
```
docker run -d --network=reddit --network-alias=post_db --network-alias=comment_db mongo:latest
docker run -d --network=reddit --network-alias=post nefariusmag/post:1.0
docker run -d --network=reddit --network-alias=comment nefariusmag/comment:1.0
docker run -d --network=reddit -p 9292:9292 nefariusmag/ui:1.0
```

Для создания одной сети в которой работают контейнеры используется:
`docker network create reddit`
Для использования этой сети контейнерам при запуске надо использовать ключ:
`--network=reddit`
Для общения между собой контейнеров по dns имени задаем его ключем:
`--network-alias=post_db`

Для хранения информации за пределами контейнера, например для БД используем volume, создадим его:
`docker volume create reddit_db`

И укажем при запуске контейнера:
`docker run -d --network=reddit —network-alias=post_db --network-alias=comment_db -v reddit_db:/data/db mongo:latest`

Задания со *

Создаем новую сеть reddit-new, меняем alias'ы и передаем их переменными для контейнеров через -e:
```
docker network create reddit-new
docker run -d --network=reddit-new --network-alias=post_db-new --network-alias=comment_db-new mongo:latest
docker run -d --network=reddit-new --network-alias=post-new -e "POST_DATABASE_HOST=post_db-new" nefariusmag/post:1.0
docker run -d --network=reddit-new --network-alias=comment-new -e "COMMENT_DATABASE_HOST=comment_db-new" nefariusmag/comment:1.0
docker run -d --network=reddit-new -p 9292:9292 -e "POST_SERVICE_HOST=post-new" -e "COMMENT_SERVICE_HOST=comment-new" nefariusmag/ui:1.0
```

Для сборки облегченного контейнера с alpine, собираем командой:
`docker build -t nefariusmag/ui:2.1 -f ./ui/Dockerfile_alpine ./ui`

По итогу docker images для ui выглядит так:
```
REPOSITORY            TAG                 IMAGE ID            CREATED             SIZE
nefariusmag/ui        2.1                 86162ad5a550        8 seconds ago       214 MB
nefariusmag/ui        2.0                 82953ee3fb54        38 minutes ago      453 MB
nefariusmag/ui        1.0                 1acad45d2886        2 hours ago         775 MB
```


---
Homework 15
---

Работа с Docker machine, Dockerfile и Docker Hub

Установили Docker machine с https://docs.docker.com/machine/install-machine/

Настроили gcloud для работы с новым проектом и с помощью docker machine создали виртуалку в GCP с установленным докером
```
docker-machine create --driver google \
--google-project docker-193608 \
--google-zone europe-west1-b \
--google-machine-type g1-small \
--google-machine-image $(gcloud compute images list --filter ubuntu-1604-lts --uri) \
docker-host
```
Проверка какие докер-машины доступны
```
docker-machine ls
```
Для переноса докер команд на виртуальную машину:
```
eval $(docker-machine env docker-host)
```

В Dockerfile основные команды для работы:
FROM \ RUN \ COPY \ CMD

Сборка образа по Dockerfile выполнятеся командой:
```
docker build -t reddit:latest .
```

DockerHub выступает как хралище образов пользователей и компаний.

---
Homework 14
---

Разбирали docker, его установку и первые шаги. Скачали с dockerhub пару образов - hello-world & ubuntu. Позапускали пару контейнеров из скаченных образов. Поостанавливали и стартовали заново, посмотрели конфигурацию и удалили контейнеры.

Основные команды:
```
docker run -it --rm
docker ps
docker ps -a
docker images
docker start
docker attach
docker exec -it
docker commit
docker inspect
docker ps -q
docker kill
docker system df
docker rm
```
