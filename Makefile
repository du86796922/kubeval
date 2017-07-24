NAME=kubeval
PACKAGE_NAME=github.com/garethr/$(NAME)
GOFMT_FILES?=$$(find . -name '*.go' | grep -v vendor)
TAG=$$(git describe --abbrev=0 --tags)

LDFLAGS += -X "$(PACKAGE_NAME)/version.BuildTime=$(shell date -u '+%Y-%m-%d %I:%M:%S %Z')"
LDFLAGS += -X "$(PACKAGE_NAME)/version.BuildVersion=$(shell git describe --abbrev=0 --tags)"
LDFLAGS += -X "$(PACKAGE_NAME)/version.BuildSHA=$(shell git rev-parse HEAD)"
# Strip debug information
LDFLAGS += -s

all: build

$(GOPATH)/bin/glide:
	go get github.com/Masterminds/glide

$(GOPATH)/bin/golint:
	go get github.com/golang/lint/golint

$(GOPATH)/bin/goveralls:
	go get github.com/mattn/goveralls

$(GOPATH)/bin/errcheck:
	go get -u github.com/kisielk/errcheck

.bats:
	git clone --depth 1 https://github.com/sstephenson/bats.git .bats

glide.lock: glide.yaml $(GOPATH)/bin/glide
	glide update
	@touch $@

vendor: glide.lock
	glide install
	@touch $@

check: vendor $(GOPATH)/bin/errcheck
	errcheck

releases:
	mkdir -p releases

bin/linux/amd64:
	mkdir -p bin/linux/amd64

bin/windows/amd64:
	mkdir -p bin/windows/amd64

bin/darwin/amd64:
	mkdir -p bin/darwin/amd64

build: darwin linux windows

darwin: vendor releases bin/darwin/amd64
	env GOOS=darwin GOAARCH=amd64 go build -ldflags '$(LDFLAGS)' -v -o $(CURDIR)/bin/darwin/amd64/$(NAME)
	tar -cvzf releases/$(NAME)-darwin-amd64.tar.gz bin/darwin/amd64/$(NAME)

linux: vendor releases bin/linux/amd64
	env GOOS=linux GOAARCH=amd64 go build -ldflags '$(LDFLAGS)' -v -o $(CURDIR)/bin/linux/amd64/$(NAME)
	tar -cvzf releases/$(NAME)-linux-amd64.tar.gz bin/linux/amd64/$(NAME)

windows: vendor releases bin/windows/amd64
	env GOOS=windows GOAARCH=amd64 go build -ldflags '$(LDFLAGS)' -v -o $(CURDIR)/bin/windows/amd64/$(NAME)
	tar -cvzf releases/$(NAME)-windows-amd64.tar.gz bin/windows/amd64/$(NAME)

lint: $(GOPATH)/bin/golint
	golint

docker:
	docker build -t garethr/kubeval:$(TAG) .
	docker tag garethr/kubeval:$(TAG) garethr/kubeval:latest

publish: docker
	docker push garethr/kubeval:$(TAG)
	docker push garethr/kubeval:latest

vet:
	go vet `glide novendor`

test: vendor vet lint check
	go test -v -cover `glide novendor`

coveralls: vendor $(GOPATH)/bin/goveralls
	goveralls -service=travis-ci

watch:
	ls */*.go | entr make test

acceptance: .bats
	env PATH=./.bats/bin:$$PATH:./bin/darwin/amd64 ./acceptance.bats

cover:
	go test -v ./kubeval -coverprofile=coverage.out
	go tool cover -html=coverage.out
	rm coverage.out

clean:
	rm -fr releases bin

fmt:
	gofmt -w $(GOFMT_FILES)

.PHONY: fmt clean cover acceptance lint docker test vet watch windows linux darwin build check