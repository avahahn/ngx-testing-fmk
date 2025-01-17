# Testing Framework
This is a set of scripts that roughly does the following:
- launches available libvirt VMs on host
- synchronizes code and test code to each VM
- runs a build script on each VM
- runs a test script on each VM
- collects job status and logs and stores them locally

## Prerequisites
- SECRET.sh must contain the following
  - USERN=<username on your VMs> 
  - PASSP=<password for said user>
- sshpass, virsh, libvirt, etc
- cloned repos of nginx, nginx-tests, and nginx-otel

## About those VMs....
- hostname and libvirt domain name need to be same for each
- username and password should be the same on all of them
- whatever your test functions need (see `nginx.sh`)
  - git
  - make
  - gcc
  - zlib
  - pcre
  - openssl
  - rsyncz
  - perl and perl-utils (for prove)

For Otel module build and tests:
  - cmake
  - c-ares
  - linux-headers
  - g++ / clang++ / etc

### FreeBSD
- need to install bash
- need to set login shell to bash

### Fedora
- install zlib-ng-compat-devel and zlib-ng-compat-static for zlib, not zlibrary-devel or zlib-ng-devel.
- fedora also seems to need the openssl-devel-engine package.

### Alpine
- need to install clang instead of gcc

## Usage
Invoke `test.sh` with some or all of the following flags:
- `--nginx <nginx>` takes an nginx code directory and builds it on remote hosts
- `--otel <otel>` takes an nginx-otel directory and builds it on remote hosts
- `--tests <tests>` takes an nginx-tests directory and runs tests on remote hosts
    requires that `--nginx=...` also be supplied. If otel was supplied this also
    triggers testing in otel directory.

Logs are in logging directory shown. They are split out into files per VM per phase.
User may set test_log_dir to provide their own logging directory.
