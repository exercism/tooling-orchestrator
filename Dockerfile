FROM ruby:2.6.6-alpine3.12

RUN gem install bundler && \
    apk add --no-cache --update build-base cmake git && \
    chmod u+x /usr/local/bin/hivemind

WORKDIR /usr/src/app

COPY Gemfile Gemfile.lock ./
RUN bundle install

ENTRYPOINT cd /usr/src/app && hivemind -p 3021 ./Procfile

