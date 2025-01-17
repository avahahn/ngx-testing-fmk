#!/bin/bash

# gets executed ON REMOTE HOST
#function current_dir_is_nginx_repo() {
#	local tok
#	tok=$(basename -s .git `git config --get remote.origin.url` 2> /dev/null)
#	if [[ "$tok" == "nginx" ]]; then
#		ret="true"
#		return 0
#	else
#		ret="false"
#		return 0
#	fi
#}

# The following functions are all run on a VM
# Through an SSH connection. Make sure not to
# use any external functions in them.

function build_nginx_remote() {
	auto/configure \
		--with-threads \
		--with-http_ssl_module \
		--with-http_v2_module \
		--with-http_v3_module \
		--with-http_realip_module \
		--with-http_addition_module \
		--with-http_sub_module \
		--with-http_dav_module \
		--with-http_flv_module \
		--with-http_gzip_static_module \
		--with-http_auth_request_module \
		--with-http_random_index_module \
		--with-http_secure_link_module \
		--with-http_slice_module \
		--with-http_stub_status_module \
		--with-stream_ssl_module \
		--with-stream_realip_module \
		--with-stream_ssl_preread_module \
		--with-debug && \
	make -j3
	return $?
}

function test_nginx_remote() {
	TEST_NGINX_VERBOSE=1 TEST_NGINX_CATLOG=1 prove -vw -j 3 .
	return $?
}

function clean_nginx_remote() {
	make clean
	return $?
}

function build_otel_remote() {
	mkdir -p build && cd build && \
	cmake -DNGX_OTEL_NGINX_BUILD_DIR=../../nginx/objs .. && \
	make -j3
	return $?
}

function test_otel_remote() {
	echo "UNIMPLEMENTED!"
}

function clean_otel_remote() {
	rm -rf build
}
