Dmitriy Erokhin - nefariusmag

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
