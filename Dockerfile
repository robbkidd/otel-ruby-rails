FROM ruby:3.0
RUN gem install bundler
WORKDIR /myapp
COPY Gemfile* /myapp/
RUN bundle install
COPY greeter.ru /myapp

EXPOSE 3000
CMD [ "bundle", "exec", "rackup", "greeter.ru", "--server", "puma", "--host", "0.0.0.0"]
