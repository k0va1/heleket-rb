.PHONY: test

install:
	bundle install

cons:
	bin/console

test:
	bundle exec rspec

lint:
	bundle exec standardrb

lint-fix:
	bundle exec standardrb --fix
