all:	check run

check:
	docker run --rm -v "$(shell pwd)/scripts":/mnt mvdan/shfmt -d /mnt/build.sh
	docker run --rm -v "$(shell pwd)/scripts":/mnt mvdan/shfmt -d /mnt/docker_build.sh
	docker run --rm -v "$(shell pwd)/scripts":/mnt mvdan/shfmt -d /mnt/install.sh
	docker run --rm -e SHELLCHECK_OPTS="" -v "$(shell pwd)/scripts":/mnt koalaman/shellcheck:stable -x build.sh
	docker run --rm -e SHELLCHECK_OPTS="" -v "$(shell pwd)/scripts":/mnt koalaman/shellcheck:stable -x docker_build.sh
	docker run --rm -e SHELLCHECK_OPTS="" -v "$(shell pwd)/scripts":/mnt koalaman/shellcheck:stable -x install.sh

format:
	docker run --rm -v "$(shell pwd)/scripts":/mnt mvdan/shfmt -w /mnt/build.sh
	docker run --rm -v "$(shell pwd)/scripts":/mnt mvdan/shfmt -w /mnt/docker_build.sh
	docker run --rm -v "$(shell pwd)/scripts":/mnt mvdan/shfmt -w /mnt/install.sh

run:
	bash ./bash_helpers.sh || true

.PHONY: check format run
