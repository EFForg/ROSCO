FROM ruby:alpine
LABEL maintainer="Rocket Lee <rocket@eff.org>"

RUN mkdir -p /srv/app
COPY ./lib /srv/app
WORKDIR /srv/app
RUN bundle install --without development test
CMD crond -l 2 -f
