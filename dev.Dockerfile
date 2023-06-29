#############
## Stage 1 ##
#############
FROM ruby:2.6.6-alpine3.12 as gembuilder

RUN apk add --no-cache --update build-base cmake

WORKDIR /usr/src/app

COPY Gemfile Gemfile.lock ./
RUN gem install bundler:2.4.12 && \
    bundle install --frozen

#############
## Stage 2 ##
#############
FROM ruby:2.6.6-alpine3.12

WORKDIR /usr/src/app

RUN gem install bundler:2.4.12
COPY --from=gembuilder /usr/local/bundle/ /usr/local/bundle/

# copy the source as late as possible to maximize cache
COPY . .

ENV CONTAINER_NAME=tooling-orchestrator

ENTRYPOINT APP_ENV=development bundle exec rackup -p 3021 --host 0.0.0.0

