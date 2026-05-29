.PHONY: setup test ci openapi docker-build demo

setup:
	mix deps.get
	mix ecto.setup

test:
	mix test

ci:
	mix ci

openapi:
	npx @redocly/cli lint openapi.yaml

docker-build:
	docker build .

demo:
	./scripts/demo.sh
