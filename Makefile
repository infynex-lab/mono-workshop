# make help
TARGET ?= apache
PORT   ?= 8080
IMAGE  ?= webforms-mono:$(TARGET)
NAME   ?= webforms-$(TARGET)
TARGET_FRAMEWORK ?=
DOCKER_BUILD = DOCKER_BUILDKIT=1 docker build -f docker/Dockerfile --build-arg TARGET_FRAMEWORK=$(TARGET_FRAMEWORK)

.PHONY: help artifacts build run test logs stop shell all run-artifacts local-build clean
help:
	@echo "make artifacts      compile in Docker and export binaries to ./artifacts  (webforms/ mvc/)"
	@echo "make build          build runtime image (TARGET=apache|xsp)"
	@echo "make run            start container on http://localhost:$(PORT)"
	@echo "make test           run tests/smoke.sh against it"
	@echo "make run-artifacts  run ./artifacts in the apache image WITHOUT rebuilding (port 8082)"
	@echo "make local-build    same as 'artifacts' but without Docker (needs mono + msbuild on this machine)"
	@echo "Use TARGET_FRAMEWORK=v4.8 (or v4.6.2 ...) to change the framework the projects are compiled against"

all: build run test

artifacts:
	$(DOCKER_BUILD) --target artifacts --output type=local,dest=artifacts .
	@cat artifacts/manifest.txt

build:
	$(DOCKER_BUILD) --target $(TARGET) -t $(IMAGE) .

run:
	-docker rm -f $(NAME) >/dev/null 2>&1
	docker run -d --name $(NAME) -p $(PORT):80 $(IMAGE)
	@echo "Open http://localhost:$(PORT)/webforms/Default.aspx and http://localhost:$(PORT)/mvc/"

test:
	CHECK_LANDING=$(if $(filter apache,$(TARGET)),1,0) tests/smoke.sh http://localhost:$(PORT)

logs:
	docker logs -f $(NAME)

shell:
	docker exec -it $(NAME) bash

stop:
	-docker rm -f $(NAME) webforms-artifacts

run-artifacts: artifacts
	-docker rm -f webforms-artifacts >/dev/null 2>&1
	docker run -d --name webforms-artifacts -p 8082:80 \
	  -v "$(CURDIR)/artifacts/webforms:/var/www/webforms" \
	  -v "$(CURDIR)/artifacts/mvc:/var/www/mvc" webforms-mono:apache
	@echo "Open http://localhost:8082/webforms/Default.aspx"

local-build:
	scripts/build.sh

clean: stop
	rm -rf artifacts packages .tools
