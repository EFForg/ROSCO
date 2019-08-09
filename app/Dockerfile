FROM ruby:alpine
LABEL maintainer="Rocket Lee <rocket@eff.org>"

RUN mkdir -p /srv/app
COPY Gemfile main.rb /srv/app/
WORKDIR /srv/app
RUN bundle install --without development test

CMD ["ruby", "./main.rb"]
