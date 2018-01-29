Dmitriy Erokhin - nefariusmag

---
Homework 15
---

Работа с Docker machine, Dockerfile и Docker Hub

Установили Docker machine с https://docs.docker.com/machine/install-machine/

Настроили gcloud для работы с новым проектом и с помощью docker machine создали виртуалку в GCP с установленным докером
```
docker-machine create --driver google \
> --google-project docker-193608 \
> --google-zone europe-west1-b \
> --google-machine-type g1-small \
> --google-machine-image $(gcloud compute images list --filter ubuntu-1604-lts --uri) \
> docker-host
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
