Dmitriy Erokhin - nefariusmag

---
Homework 32
---

Настройка мониторинга и логирования для k8s

Мониторинг:

Для работы нам необходим ingress-контроллер nginx:
`helm install stable/nginx-ingress --name nginx`

Получить ip nginx можно:
`kubectl get svc`

Prometheus устанавливается замысловато:
```
git clone https://github.com/kubernetes/charts.git kube-charts
cd kube-charts
git fetch origin pull/2767/head:prom_2.0
git checkout prom_2.0
```

Для запуска prometheus из нашего конфига:
`helm upgrade prom . -f custom_values.yml --install`

Для работы helm используются команды:
```
helm upgrade <release> --namespace <namespace> ./<folder> --install
```

Для установки Grafana выполняем:
`helm upgrade --install grafana stable/grafana --set "server.adminPassword=admin" --set "server.service.type=NodePort" --set "server.ingress.enabled=true" --set "server.ingress.hosts={reddit-grafana}"`

Добавляем дашборды для работы с кубернетисом:
https://grafana.com/dashboards/315
https://grafana.com/dashboards/741

Настраиваем источники БД и параметризируем окружения через variable дашбордов.
В каждый дашборд встраиваем настройку зависимомсти от окружения.


Логирование

Логировать будем через EFK (ElasticSearch, Fluentd, Kibana)

Чтобы еластик запустился на самой обьемной ноде, помечаем её:
`kubectl label node gke-cluster-1-big-pool-b4209075-tvn3 elastichost=true`

Kibana ставим через helm:
`helm upgrade --install kibana stable/kibana --set "ingress.enabled=true" --set "ingress.hosts={reddit-kibana}" --set "env.ELASTICSEARCH_URL=http://elasticsearch-logging:9200" --version 0.1.1`

Для настройки ElasticSearch и Fluentd используем yaml.

Задание со *

Насписал Chart для EFK

---
Homework 31
---

Работа с Helm

Работает как система клиент - сервер. На кластер ставится Tiller.

```
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: tiller
  namespace: kube-system
---
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRoleBinding
metadata:
  name: tiller
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
  - kind: ServiceAccount
    name: tiller
    namespace: kube-system
```

`kubectl apply -f tiller.yml`
`helm init --service-account tiller`

Для работы необходим Chart.yaml, где праписывается версия, приложение, владелец:
```
---
name: ui
version: 1.0.0
description: OTUS reddit application UI
maintainers:
  - name: Dmitry Erokhin
    email: i9164871362@gmail.com
appVersion: 1.0
```

Для установки приложения используется команда:
`helm install --name test-ui-1 ui/`

Для параметризации имени релиза и версии используем:
`{{ .Release.Name }}-{{ .Chart.Name }}`

Остальные вещи для параметризации:
```
{{ .Values.image.repository }}
{{ .Values.image.tag }}
{{ .Values.service.internalPort }}
{{ .Values.service.externalPort }}
```

Для функции задающей переменные:
```
{{- define "comment.fullname" -}}
{{- printf "%s-%s" .Release.Name .Chart.Name }}
{{- end -}}
```

Образение к этой функции выглядит следующим образом:
`{{ template "comment.fullname" . }}`

Для создания ссылок на другие элементы используем requirements.yaml
```
---
dependencies:
 - name: ui
 version: "1.0.0"
 repository: "file://../ui"
 - name: post
 version: "1.0.0"
 repository: file://../post
 - name: comment
 version: “1.0.0"
 repository: file://../comment
```

Для подгрухки зависимостей:
`helm dep update`



---
Homework 30
---

Работа с Network & PersistentVolume


За dns отвечат сервис  kube-dns-autoscaler и kube-dns, без них поды не будут распозновать друг друга по dns-именам.

Для создания внешнего балансировщика (в GCP) используется LoadBalancer, конфигурируется он для сервиса в следующих настройках:

```
spec:
  type: LoadBalancer
  ports:
  - port: 80
    nodePort: 32092
    protocol: TCP
    targetPort: 9292
  selector:
    app: reddit
    component: ui
```

Увидеть LoadBalancer можно командой:
`kubectl get service -n dev --selector component=ui `

Еще один балансировщик Ingress с большим количеством возможностей, задается он через:
```
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: ui
  annotations:
    kubernetes.io/ingress.allow-http: "false"
spec:
  tls:
  - secretName: ui-ingress
  backend:
    serviceName: ui
    servicePort: 9292
```

IP адрес можно увидеть через команду:
`kubectl get ingress -n dev`

Для генерации сертификата используем:
`openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout tls.key -out tls.crt -subj "/CN=35.190.66.90" `

Загрузить сертификат в кластер:
`kubectl create secret tls ui-ingress --key tls.key --cert tls.crt -n dev`

Проверить наличие сертификата:
`kubectl describe secret ui-ingress -n dev`

Настройка Ingress для работы только по https:
```
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: ui
  annotations:
    kubernetes.io/ingress.allow-http: "false"
spec:
  tls:
  - secretName: ui-ingress
  backend:
    serviceName: ui
    servicePort: 9292
```

Удаление ingress выполняется через команду:
`kubectl delete ingress ui -n dev`

___

Для настройки NetworkPolicy необходимо включить этот плагин:
```
gcloud beta container clusters list
gcloud beta container clusters update <cluster-name> --zone=us-central1-a --update-addons=NetworkPolicy=ENABLED
gcloud beta container clusters update <cluster-name> --zone=us-central1-a --enable-network-policy
```

В yaml это описывается следующим образом:
```
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-db-traffic
  labels:
    app: reddit
spec:  # объекты
  podSelector:
    matchLabels:
      app: reddit
      component: mongo
  policyTypes: # запреты
  - Ingress
  ingress: # разрешающие правила
  - from:
    - podSelector:
        matchLabels:
          app: reddit
          component: comment
```


___

Хранилища для БД описываются в yml:
```
---
---
apiVersion: apps/v1beta1
kind: Deployment
metadata:
  name: mongo
...
    spec:
      containers:
      - image: mongo:3.2
        name: mongo
        volumeMounts:
        - name: mongo-persistent-storage
          mountPath: /data/db
      volumes:
      - name: mongo-persistent-storage
        emptyDir: {}
```

Для централизованного гугловского хранилища необходимо его создать и настроить поды работать с ним

Хранилище в GCP создается командой:
`gcloud compute disks create --size=25GB --zone=us-central1-a reddit-mongo-disk`

Настройка подов для работы с хранилищем:
```
---
apiVersion: apps/v1beta1
kind: Deployment
metadata:
  name: mongo
...
    spec:
      containers:
      - image: mongo:3.2
        name: mongo
        volumeMounts:
        - name: mongo-gce-pd-storage
          mountPath: /data/db
      volumes:
      - name: mongo-persistent-storage
        emptyDir: {}
        volumes:
      - name: mongo-gce-pd-storage
        gcePersistentDisk:
          pdName: reddit-mongo-disk
          fsType: ext4
```

Для удаления задеплоиного mongo используем:
`kubectl delete deploy mongo -n dev`


Для настройки PersistentVolume для ограничения места настройка выглядит следующим образом:
```
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: reddit-mongo-disk
spec:
  capacity:
    storage: 25Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  gcePersistentDisk:
    fsType: "ext4"
    pdName: "reddit-mongo-disk"
```

Для настройки PersistentVolumeClaim нужно сконфигурировать yml:

```
---
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: mongo-pvc
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 25Gi
```

---
Homework 29
---

Kubernetes локально в minikube и глобально в GKE

Для развертывания Kubernetes локально используем virtualbox + minikube. Для работы с кластером Kubernetes используем Kubectl.

Установка:

Kubectl:
https://kubernetes.io/docs/tasks/tools/install-kubectl/

Virtualbox:
https://www.virtualbox.org/wiki/Downloads

Minikube:
`curl -Lo minikube https://storage.googleapis.com/minikube/releases/v0.24.1/minikube-linuxamd64 && chmod +x minikube && sudo mv minikube /usr/local/bin/`

Запуск кластера:
`minikube start`

Проверка работы кластера:
`kubectl get nodes`

Манифет для подключения kubectl к кластеру Kubernetes
~/.kube/config

Конфигурация kubectl в ручную:
Создать cluster:
$ kubectl config set-cluster … cluster_name
Создать данные пользователя (credentials)
$ kubectl config set-credentials … user_name
Создать контекст
$ kubectl config set-context context_name --cluster=cluster_name --user=user_name
Использовать контекст
$ kubectl config use-context context_name

Список всех контекстов:
`kubectl config get-contexts`

Проверка текущего контекста:
`kubectl config current-context`

Окружение настраивается через namespace:
```
apiVersion: v1
kind: Namespace
metadata:
  name: dev
```

Для деплоя приложений используются команда:
`kubectl apply  -n dev -f ххх.yml`

Проброс портов для тестирования приложения:
`kubectl port-forward <pod-name> 8080:9292`

Описание подов или сервисов:
`kubectl describe service\pods post\post-6cd8566f6-985fl`

Подключение к подам:
`kubectl exec -ti <pod-name> /bin/sh`

Удаление сервиса:
`kubectl delete service mongodb`

Minikube:

Отображение веб-страниц с внешними сервисами:
`minikube service ui -n dev`

Список всех сервисов:
`minikube services list`

Список расширений:
`minikube addons list`

Включим addon:
`minikube addons enable dashboard`

Дашборд для управления кластером:
`minikube service kubernetes-dashboard -n kube-system`

GKP настаивался графически.

Задание со *



---
Homework 28
---

Развертывание Kubernetes в ручную. GCP + Kubernetes

Используя инструкцию https://github.com/kelseyhightower/kubernetes-the-hard-way шаг за шагом развертываем кубернетис.

---
Homework 27
---

Работа с Docker Swarm

Создаем master и worker'ов

Инициализируем на мастере swarm `docker swarm init`  

Подключаем воркеров:
`docker swarm join --token SWMTKN-1-5dkxha7z0h9vfxqsoepxqybmehcs7mvfrtml00s8hxnn2nrgepchln12zdzd1805uensy5xouj7 10.132.0.6:2377`

Стек управляется командами:
`docker stack deploy/rm/services/ls/ps STACK_NAME`

Для деплоя из docker-compose.yml с подтягиванием .env используется команда:
`docker stack deploy --compose-file=<(docker-compose -f docker-compose.monitoring.yml -f docker-compose.yml config 2>/dev/null) DEV`

Добавления label к ноде:
`docker node update --label-add reliability=high master-1`

Посмотреть label’ы всех нод:
`docker node ls -q | xargs docker node inspect  -f '{{ .ID }} [{{ .Description.Hostname }}]: {{ .Spec.Labels }}'`

Создать ограничения для работы сервисов

- на какой ноде запуститься:
```
deploy:
  placement:
    constraints:
      - node.labels.reliability == high
```
или
```
deploy:
  placement:
    constraints:
      - node.role == worker
```

- количество запусков:
```
deploy:
  mode: replicated
  replicas: 7
```
или
```
deploy:
  mode: global
```

- параметры деплоя:
```
deploy:
  update_config:
    parallelism: 2
    delay: 5s
    failure_action: rollback
    monitor: 5s
    max_failure_ratio: 2
    order: start-first
```

- ограничения по ресурсам:
```
deploy:
  resources:
    limits:
    cpus: ‘0.25’
    memory: 150M   
```

- ограничения по перезапускам приложения:
```
deploy:
  restart_policy:
    condition: on-failure
    max_attempts: 3
    delay: 3s
```

При создании нового worker на него заливается по умолчанию только node-exporter, которому мы указали быть на всех серверах.

Задание со *

При увеличении количества реплик приложений после создания нового воркера, они сначала заливаются на него, до выравнивания загруженности.

Управляю окружения за счет подсовывания разных .env

Примеры:
.env_DEV
.env_STAGE
.env_PROD

Команды для старта:
```
docker stack deploy --compose-file=<(docker-compose -f docker-compose.yml -f docker-compose.monitoring.yml config 2>/dev/null) DEV
docker stack deploy --compose-file=<(docker-compose -f docker-compose.yml -f docker-compose.monitoring.yml config 2>/dev/null) STAGE
docker stack deploy --compose-file=<(docker-compose -f docker-compose.yml -f docker-compose.monitoring.yml config 2>/dev/null) PROD
```

Неодобно, то что надо париться на счет того не совпадают ли порты постоянно((

---
Homework 25
---

Работа с EFK (elasticsearch + fluentd + kibana)

Разворачиваем приложение reddit (обновленный), чиним в нем баги, разворачиваем zipkin (port:9411), fluentd (port:24224), elasticsearch (port:9200), kibana (port:5601) через docker-compose-logging.yml

fluentd собирается предварительно, куда подкидываем fluentd.conf, в котором:

Источник данных:
```
<source>
  @type forward
  port 24224
  bind 0.0.0.0
</source>
```

Место куда обработанные логи отправляются:
```
<match *.**>
  @type copy
  <store>
    @type elasticsearch
    host elasticsearch
    port 9200
    logstash_format true
    logstash_prefix fluentd
    logstash_dateformat %Y%m%d
    include_tag_key true
    type_name access_log
    tag_key @log_name
    flush_interval 1s
  </store>
  <store>
    @type stdout
  </store>
</match>
```

Логи обрабатываем с помощью фильтров:
```
<filter service.ui>
  @type parser
  key_name log
  format grok
  grok_pattern %{RUBY_LOGGER}
</filter>

<filter service.ui>
  @type parser
  format grok
  grok_pattern service=%{WORD:service} \| event=%{WORD:event} \| request_id=%{GREEDYDATA:request_id} \| message='%{GREEDYDATA:message}'
  key_name message
  reserve_data true
</filter>
```

Иногда фильтры это просто регулярные выражения, наподобие:
```
<filter service.ui>
  @type parser
  format /\[(?<time>[^\]]*)\]  (?<level>\S+) (?<user>\S+)[\W]*service=(?<service>\S+)[\W]*event=(?<event>\S+)[\W]*(?:path=(?<path>\S+)[\W]*)?request_id=(?<request_id>\S+)[\W]*(?:remote_addr=(?<remote_addr>\S+)[\W]*)?(?:method= (?<method>\S+)[\W]*)?(?:response_status=(?<response_status>\S+)[\W]*)?(?:message='(?<message>[^\']*)[\W]*)?/
  key_name log
</filter>
```

Задание со *

Чтобы распарсить message типа - `service=ui | event=request | path=/ | request_id=6a37a8cb-c02e-4e79-8bc3-a65ef568f013 | remote_addr=195.26.187.23 | method= GET | response_status=200`, используем фильтр:
```
<filter service.ui>
  @type parser
  format grok
  grok_pattern service=%{WORD:service} \| event=%{WORD:event} \| path=%{URIPATH:path} \| request_id=%{UUID:request_id} \| remote_addr=%{IPORHOST:ip_address} \| method=\s%{WORD:method} \| response_status=%{NUMBER:response_status}
  key_name message
</filter>
```

---
Homework 23
---

Работа с Grafana

Подняли мониторинг контейнеров - cAdvisor и Grafana для визуализации данных в графики. Настроили систему оповещений.

В docker-compose-monitoring.yml добавили:
```
cadvisor:
  image: google/cadvisor:v0.29.0
  volumes:
    - '/:/rootfs:ro'
    - '/var/run:/var/run:rw'
    - '/sys:/sys:ro'
    - '/var/lib/docker/:/var/lib/docker:ro'
  ports:
    - '8080:8080'

grafana:
  image: grafana/grafana:5.0.0-beta4
  volumes:
    - grafana_data:/var/lib/grafana
  environment:
    - GF_SECURITY_ADMIN_USER=admin
    - GF_SECURITY_ADMIN_PASSWORD=secret
  depends_on:
    - prometheus
  ports:
    - 3000:3000

volumes:
  grafana_data:    
```

Хранилище dashboard для Grafana - https://grafana.com/dashboards

Для отображеиня в grafana мониторинга только определенных старниц 400 или 500 указываем функцию:
`rate(ui_request_count{http_status=~"^[45].*"}[1m])`

Для гистограммы:
`histogram_quantile(0.95, sum(rate(ui_request_latency_seconds_bucket[5m])) by (le))`

Алертинг для prometheus можно настроить приложение altermanager:

```
alertmanager:
  image: ${USER_NAME}/alertmanager
  command:
    - '--config.file=/etc/alertmanager/config.yml'
  ports:
    - 9093:9093
  networks:
    - back_net
    - front_net
```
Настриаем конфиг самого приложения config.yml:
```
global:
  slack_api_url: 'https://hooks.slack.com/services/T6HR0TUP3/B99QPJHLN/ххххххххх'

route:
  receiver: 'slack-notifications'

receivers:
- name: 'slack-notifications'
  slack_configs:
  - channel: '#dmitriy-erokhin'
```

Встаиваем его в prometheus.yml
```
rule_files:
  - "alerts.yml"

alerting:
  alertmanagers:
  - scheme: http
    static_configs:
    - targets:
      - "alertmanager:9093"
```

DockerHub: https://hub.docker.com/r/nefariusmag/

Задание с *

-- В Makefile добавил новую сборку.

-- Метрики докер контейнера

Настроил докер на запись метрик в /etc/docker/daemon.json
```
{
  "metrics-addr" : "0.0.0.0:9323",
  "experimental" : true
}
```
В прометеус добавил, где 172.18.0.1 и 172.19.0.1 - ip шлюза подсети:
```
- job_name: 'docker'
  static_configs:
    - targets:
    - '172.18.0.1:9323'   
    - '172.19.0.1:9323'   
```

-- Email

Для отправки сообщений в настроки alertmanager надо добавить:
```
global:
  smtp_smarthost: 'smtp.yandex.ru:465'
  smtp_from: 'nefarius-mag@yandex.ru'
  smtp_auth_username: "nefarius-mag@yandex.ru"
  smtp_auth_password: "xxx"
  smtp_require_tls: false

receivers:
- name: 'notifications'
  email_configs:
  - to: 'i9164871362@gmail.com'
```

-- Новые метрики - загрузка CPU, RAM и HDD

```
- alert: CPUisload
  expr: node_load1 > 0.5
  for: 1m
  labels:
    severity: warning
  annotations:
    description: "{{$labels.instance}} have cpu load > 0.5"

- alert: HDDisLow
  expr: node_filesystem_avail{mountpoint="/"} < 400000000
  for: 1m
  labels:
    severity: critical
  annotations:
    description: "{{$labels.instance}} have HDD < 400 Mb"

- alert: RAMisLow
  expr: node_memory_MemAvailable < 1000000000
  for: 1m
  labels:
    severity: critical
  annotations:
    description: '{{$labels.instance}} have RAM < 1 Gb'
```

и перцентиль

```
- alert: Percentile95
  expr: histogram_quantile(0.95, sum(rate(ui_request_latency_seconds_bucket[1m])) by (le)) > 0.3
  for: 1m
  labels:
    severity: warning
  annotations:
    description: '{{ $labels.instance }} of job {{ $labels.job }} have percentile95 a lot of norm more than 1 minute'
    summary: 'Instance {{ $labels.instance }} have percentile95 a lot of norm more than 1 minute'
```    

---
Homework 21
---

Развертывание Prometheus


Настройка prometheus через yml, prometheus.yml подкладывается в /etc/prometheus/

Настройка частоты проверки:
```
global:
  scrape_interval: '5s'
```

Инстансы для проверки:
```
- job_name: 'ui'
  static_configs:
    - targets:
      - 'ui:9292'
```

DockerHub: https://hub.docker.com/r/nefariusmag/

Задание со * 1

Для мониторинга БД использовал экспортер mongodb_exporter, бинарник взял с репозитория, сам не собирал. Бинарник по умолчанию мониторит localhost, надо передаеть ему url бд: MONGODB_URL= 'mongodb://post_db:27017'

В настройки prometheus добавил:
```
- job_name: 'mongodb'
  static_configs:
    - targets:
      - 'mongodb-exporter:9001'
```
В docker-compose.yml добавил:
```
mongodb-exporter:
  image: ${USER_NAME}/mongodb_exporter:${VERSION_APP}
  environment:
    MONGODB_URL: 'mongodb://post_db:27017'
  ports:
    - 9001:9001
  networks:
    - back_net
    - front_net
```

Задание со * 2

Для мониторинга сервисов по http использвал blackbox_exporter, бинарник взял с репозитория.

В настройки prometheus добавил:
```
- job_name: 'blackbox'
  metrics_path: /probe
  params:
    module: [http_2xx]
  static_configs:
    - targets:
      - http://comment:9292/healthcheck
      - http://ui:9292/healthcheck
      - http://post:5000/healthcheck
  relabel_configs:
    - source_labels: [__address__]
      target_label: __param_target
    - source_labels: [__param_target]
      target_label: instance
    - target_label: __address__
      replacement: blackbox-exporter:9115
```
В docker-compose.yml добавил:
```
blackbox-exporter:
  image: ${USER_NAME}/blackbox_exporter:${VERSION_APP}
  ports:
    - 9115:9115
  networks:
    - front_net
    - back_net
```

Задание со * 3

Создал Makefile, для сборок всех приложений, отправки на докерхаб и рестарта докер контейнеров.

---
Homework 20
---

Более детальная настройка pipeline в GitLab

Для настройки заупуска в ручную используется параметр:
`when: manual`

Для ограничения запуска только по тегу:
```
only:
 - /^\d+\.\d+.\d+/
```

Запуск веток, но не мастера:
```
only:
  - branches
except:
  - master
```

Задача с *

Для задания кнопки стоп, использвал конструкцию:
```
deploy_dev_job:
  stage: review
  script:
    - echo 'Deploy'
  environment:
    name: dev
    url: http://dev.example.com
    on_stop: stop

stop:
  stage: review
  script: echo "Stop to dev"
  environment:
    name: dev
    action: stop
  when: manual
```

Задача со **

Я видел две возможности как выполнить это задания:

1 конструкция - в gitlab runner создать раннер на основе docker, чтобы он запускал docker контейнеры.
Но тут я столкнулся с проблемой, что не могу достучаться до приложения из вне, как бы не указывал порты для пробрасывания.
```
docker exec -it gitlab-runner gitlab-runner register -n \
--url http://35.204.192.31/ \
--registration-token pdtkb2JKLshbg3yskyJL \
--executor docker \                          
--description "my-runner-1" \
--docker-image "docker:latest" \
--docker-privileged
```

2 конструкция - создать новый раннер на основе shell, в который установить docker и в итоге несмотря на определенную корявость это работает!!

Зарегистрировать новый runner:
```
docker exec -it gitlab-runner gitlab-runner register -n \
    --url http://35.204.192.31/ \
    --registration-token pdtkb2JKLshbg3yskyJL \
    --executor shell \
    --description "my-runner-2"
```

Для сборки образа и деплоя контейнера создал код который положил в .gitlab-ci.yml.reddit

Собирает приложение, деплоит на дев, стейдж, прод, с возможностью остановки.

---
Homework 19
---

Работа с GitLab CI

Для создания виртуалки использвал:

```
docker-machine create --driver google \
--google-project docker-193608 \
--google-zone europe-west4-b \
--google-machine-type n1-standard-1 \
--google-disk-size 70 \
--google-machine-image $(gcloud compute images list --filter ubuntu-1604-lts --uri) \
docker-host
```

Доустановил docker-compose и добавил возможность подключения по http, https и ssh

Развернул с помощью docker-compose GitLab CI
```
web:
  image: 'gitlab/gitlab-ce:latest'
  restart: always
  hostname: 'gitlab.example.com'
  environment:
    GITLAB_OMNIBUS_CONFIG: |
      external_url 'http://35.204.192.31'
  ports:
    - '80:80'
    - '443:443'
    - '2222:22'
  volumes:
    - '/srv/gitlab/config:/etc/gitlab'
    - '/srv/gitlab/logs:/var/log/gitlab'
    - '/srv/gitlab/data:/var/opt/gitlab'
```

Настроив базового пользователя, группу и проект залил туда репозиторий и добавил файл для pipeline, .gitlab-ci.yml:
```
image: ruby:2.4.2

stages:
  - build
  - test
  - deploy

variables:
  DATABASE_URL: 'mongodb://mongo/user_posts'

before_script:
  - cd reddit
  - bundle install

build_job:
  stage: build
  script:
    - echo 'Building'

test_unit_job:
  stage: test
  services:
    - mongo:latest
  script:
    - ruby simpletest.rb

test_integration_job:
  stage: test
  script:
    - echo 'Testing 2'

deploy_job:
  stage: deploy
  script:
    - echo 'Deploy'
```

Для запуска runner поднял еще контейнер:
```
docker run -d --name gitlab-runner --restart always \
-v /srv/gitlab-runner/config:/etc/gitlab-runner \
-v /var/run/docker.sock:/var/run/docker.sock \
gitlab/gitlab-runner:latest
```
Подключившись к которому зарегистирровал его в GitLab
`docker exec -it gitlab-runner gitlab-runner register`

Задание со *

Настроил интеграцию с Slack, чат #dmitriy-erokhin

Для развертывания новых runner создал плейбук, запускается командой:
`ansible-playbook new_runner.yml -i inventory -e "host=35.204.192.31 number_runner=1"`
В которой указываем ip и номер runner который хотим развернуть.

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

Задание с **

Так как не сказанно было что именно менять в коде приложений, то я просто добавлял файл check в /opt c содержимым "Hellow Moscow".
Добавил дебаг режим (вроде по логике, но не знаю как это проверить).


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
