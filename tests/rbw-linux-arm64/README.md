# rbw for Linux ARM64

Pre-built `rbw` binary for running dotfiles integration tests on `linux/arm64`.

The official [rbw releases](https://github.com/doy/rbw/releases) only provide
`linux/amd64` binaries. This directory contains a Dockerfile and Makefile to
build rbw from source for `linux/arm64`.

## Why

Running `linux/amd64` containers on Apple Silicon requires x86_64 emulation
(QEMU or Rosetta). Both have issues:

- **QEMU** (Apple Virtualization framework): corrupts scrypt and X25519 crypto
  operations, breaking age decryption.
- **Docker VMM**: lacks SSSE3 instruction support required by Homebrew.

Building a native `linux/arm64` test image avoids these emulation problems
entirely.

## Build

```shell
make -C tests/rbw-linux-arm64
```

This builds rbw inside a Docker container and extracts the binary to
`tests/rbw-linux-arm64/rbw`.

## Update version

```shell
make -C tests/rbw-linux-arm64 RBW_VERSION=1.16.0
```

## Clean

```shell
make -C tests/rbw-linux-arm64 clean
```
