#############
## Stage 1 ##
#############
FROM ruby:2.6.6-alpine3.12 as gembuilder

RUN apk add --no-cache --update build-base cmake

WORKDIR /usr/src/app

COPY Gemfile Gemfile.lock ./

RUN gem install bundler:2.1.4 && \
    bundle config set deployment 'true' && \
    bundle config set without 'development test' && \
    bundle install

RUN bundle list

#############
## Stage 2 ##
#############
FROM ruby:2.6.6-alpine3.12

WORKDIR /usr/src/app

ENV APP_ENV=production

RUN gem install bundler:2.1.4
COPY --from=gembuilder /usr/local/bundle/ /usr/local/bundle/

# copy the source as late as possible to maximize cache
COPY . .

RUN bundle list

ENTRYPOINT bundle exec rackup -p 3000 --host 0.0.0.0
