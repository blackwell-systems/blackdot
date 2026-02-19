VERSION ?= $(shell git describe --tags --always --dirty 2>/dev/null || echo dev)
COMMIT  ?= $(shell git rev-parse --short HEAD 2>/dev/null || echo none)
DATE    ?= $(shell date -u +%Y-%m-%dT%H:%M:%SZ)
LDFLAGS := -s -w -X main.version=$(VERSION) -X main.commit=$(COMMIT) -X main.date=$(DATE)

# Default: build for the host architecture
build:
	CGO_ENABLED=0 go build -ldflags="$(LDFLAGS)" -o bin/blackdot ./cmd/blackdot/

# Build for both x86_64 and arm64 Linux
build-linux: bin/blackdot-linux-amd64 bin/blackdot-linux-arm64
	@echo "Built both architectures. Use bin/blackdot to auto-select."
	@cp scripts/blackdot-wrapper.sh bin/blackdot
	@chmod +x bin/blackdot

bin/blackdot-linux-amd64:
	CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -ldflags="$(LDFLAGS)" -o $@ ./cmd/blackdot/

bin/blackdot-linux-arm64:
	CGO_ENABLED=0 GOOS=linux GOARCH=arm64 go build -ldflags="$(LDFLAGS)" -o $@ ./cmd/blackdot/

# Build for macOS (both Intel and Apple Silicon)
build-darwin: bin/blackdot-darwin-amd64 bin/blackdot-darwin-arm64

bin/blackdot-darwin-amd64:
	CGO_ENABLED=0 GOOS=darwin GOARCH=amd64 go build -ldflags="$(LDFLAGS)" -o $@ ./cmd/blackdot/

bin/blackdot-darwin-arm64:
	CGO_ENABLED=0 GOOS=darwin GOARCH=arm64 go build -ldflags="$(LDFLAGS)" -o $@ ./cmd/blackdot/

# Build everything
build-all: build-linux build-darwin

clean:
	rm -f bin/blackdot bin/blackdot-*

test:
	go test ./...

.PHONY: build build-linux build-darwin build-all clean test
