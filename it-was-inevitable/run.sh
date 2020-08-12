#!/bin/sh

mode=$1

if [[ -z "$mode" ]]; then
	echo 'No tag given. Changing command to ./run.bash example.'
	mode=dev
fi

docker build -t benlubar/it_was_inevitable .
if [[ "$mode" == "dev" ]]; then
	docker run --rm -ti \
		--security-opt seccomp="$(pwd)/seccomp.json" \
		-p 1556:8080 \
		benlubar/it_was_inevitable
else
	docker stop it_was_inevitable_ || :
	docker rm -v it_was_inevitable_ || :
	docker run -d --name it_was_inevitable_ \
		--restart unless-stopped \
		--security-opt seccomp="$(pwd)/seccomp.json" \
		-p 1556:8080 \
		benlubar/it_was_inevitable
fi
