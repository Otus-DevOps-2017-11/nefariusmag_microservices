FROM ubuntu:16.04
RUN apt-get update \
  && apt-get install -y ruby-full ruby-dev build-essential \
  && gem install bundler --no-ri --no-rdoc
ENV APP_HOME=/app \
  POST_SERVICE_HOST=post \
  POST_SERVICE_PORT=5000 \
  COMMENT_SERVICE_HOST=comment \
  COMMENT_SERVICE_PORT=9292
RUN mkdir $APP_HOME
WORKDIR $APP_HOME
COPY . $APP_HOME
RUN bundle install

CMD ["puma"]
