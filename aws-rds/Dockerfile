FROM ruby:2.2
MAINTAINER Mitch Gerdisch <mitch@rightscale.com>

RUN gem install praxis -v 0.16.1

COPY Gemfile /tmp/Gemfile
RUN cd /tmp && bundle install

ENV WORKDIR /opt/praxis
WORKDIR $WORKDIR
