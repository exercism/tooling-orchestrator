#############
## Stage 1 ##
#############
FROM ruby:3.4.4-alpine3.22

RUN apk add --no-cache --update build-base cmake

WORKDIR /usr/src/app
ENV APP_ENV=production
ENV RACK_ENV=production

COPY Gemfile Gemfile.lock ./

RUN gem install bundler:2.4.12 && \
    bundle config set deployment 'true' && \
    bundle config set without 'development test' && \
    bundle install

# copy the source as late as possible to maximize cache
COPY . .

ENTRYPOINT bundle exec rackup -p 3000 --host 0.0.0.0
