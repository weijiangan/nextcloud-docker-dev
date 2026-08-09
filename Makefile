SHELL := /bin/bash

.PHONY: images docker-build pull-all docs docs-watch diff-up

.ONESHELL:
images: docker/*/Dockerfile docker/Dockerfile.*

.ONESHELL:
pull-all:
	for file in $$(find docker/ -maxdepth 1 -type f -iname 'Dockerfile.*'); do \
		NAME=$$(echo $$file | sed 's/^.*\.//'); \
		echo "=> Pulling image $$NAME"; docker pull "ghcr.io/juliusknorr/nextcloud-dev-$${NAME}"; \
	done
	for file in $$(find docker -maxdepth 2 -type f -iname 'Dockerfile'); do \
		NAME=$$(basename $$(dirname $$file)); \
		echo "=> Pulling image $$NAME"; docker pull "ghcr.io/juliusknorr/nextcloud-dev-$${NAME}"; \
	done

pull-installed:
	docker image ls | grep juliusknorr/nextcloud-dev | cut -f 1 -d " "
	docker image ls | grep juliusknorr/nextcloud-dev | cut -f 1 -d " " | xargs -L 1 docker pull

# ── Phase 16.1: differential-test harness bring-up ────────────────────────────
# SUT    = nextcloud (Rust nc-server fronting PHP)       → http://127.0.0.1:8080
# Oracle = oracle    (pure PHP, proxy → oracle:9000 fpm) → http://127.0.0.1:9091
# Both share database-pgsql + redis but use SEPARATE databases (nextcloud/oracle).
# --build: my_proxy.conf is baked into the proxy image (needs rebuild to expose
# :9091), and building nextcloud+oracle together guarantees the SUT and oracle
# run the IDENTICAL master-nextcloud:latest image — a correctness requirement
# for a differential oracle. BuildKit caching makes unchanged rebuilds fast.
# previews_hpb: the shared Imaginary (aio-imaginary) — scenario 27 asserts
# byte parity of previews generated through it (Phase 16.11).
diff-up:
	docker compose up -d --build proxy nextcloud oracle database-pgsql redis previews_hpb
	@echo "Waiting for both instances to report installed:true …"; \
	until curl -fsS -H 'Host: nextcloud.local' http://127.0.0.1:8080/status.php 2>/dev/null | grep -q '"installed":true'; do sleep 2; done; \
	echo "  ready: SUT    http://127.0.0.1:8080  (Rust)"; \
	until curl -fsS -H 'Host: oracle.local' http://127.0.0.1:9091/status.php 2>/dev/null | grep -q '"installed":true'; do sleep 2; done; \
	echo "  ready: Oracle http://127.0.0.1:9091  (pure PHP)"

# Empty target to always build
docker-build:

docker/%/Dockerfile: docker-build
	NAME=$$(basename $$(dirname $@)); \
	echo "=> Building dockerfile" $@ as ghcr.io/juliusknorr/nextcloud-dev-$$NAME:latest; \
	(cd docker && docker build -t ghcr.io/juliusknorr/nextcloud-dev-$$NAME:latest -f $$NAME/Dockerfile .)

docker/Dockerfile.%: docker-build
	NAME=$$(echo $$(basename $@) | sed 's/^.*\.//'); \
	echo "=> Building dockerfile" $@ as ghcr.io/juliusknorr/nextcloud-dev-$$NAME:latest; \
	(cd docker && docker build -t ghcr.io/juliusknorr/nextcloud-dev-$$NAME:latest -f Dockerfile.$$NAME .)

check: dockerfilelint shellcheck

.ONESHELL:
dockerfilelint:
	for file in $$(find docker/ -type f -iname 'Dockerfile.*' -maxdepth 1); do dockerfilelint $$file; done;
	for file in $$(find docker -type f -iname 'Dockerfile' -maxdepth 2); do dockerfilelint $$file; done;

.ONESHELL:
shellcheck:
	for file in $$(find . -type f -iname '*.sh' -not -path './wip/*'); do shellcheck --format=gcc -x $$file; done;
	for file in $$(find ./scripts -type f); do shellcheck --format=gcc -x $$file; done;

.ONESHELL:
template-apply:
	cat docker/Dockerfile.php.template | sed 's/php:8.2/php:7.1/' > docker/Dockerfile.php71
	cat docker/Dockerfile.php.template | sed 's/php:8.2/php:7.2/' > docker/Dockerfile.php72
	cat docker/Dockerfile.php.template | sed 's/php:8.2/php:7.3/' > docker/Dockerfile.php73
	cat docker/Dockerfile.php.template | sed 's/php:8.2/php:7.4/' > docker/Dockerfile.php74
	cat docker/Dockerfile.php.template | sed 's/php:8.2/php:8.0/' > docker/Dockerfile.php80
	cat docker/Dockerfile.php.template | sed 's/php:8.2/php:8.1/' > docker/Dockerfile.php81
	cat docker/Dockerfile.php.template | sed 's/php:8.2/php:8.2/' > docker/php82/Dockerfile
	cat docker/Dockerfile.php.template | sed 's/php:8.2/php:8.3/' > docker/php83/Dockerfile
	cat docker/Dockerfile.php.template | sed 's/php:8.2/php:8.4/' > docker/php84/Dockerfile
	cat docker/Dockerfile.php.template | sed 's/php:8.2/php:8.5/' > docker/php85/Dockerfile

docs:
	pip3 install mkdocs
	mkdocs

docs-watch:
	pip3 install mkdocs
	mkdocs serve
