#!/bin/bash -e

#
# By default tests run against a local s3proxy instance.  To run against 
# Amazon S3, specify the following variables:
#
# S3FS_CREDENTIALS_FILE=keyfile      s3fs format key file
# TEST_BUCKET_1=bucket               Name of bucket to use 
# S3PROXY_BINARY=""                  Leave empty 
# S3_URL="http://s3.amazonaws.com"   Specify Amazon server
#
# Example: 
#
# S3FS_CREDENTIALS_FILE=keyfile TEST_BUCKET_1=bucket S3PROXY_BINARY="" S3_URL="http://s3.amazonaws.com" ./small-integration-test.sh
#

S3FS=../src/s3fs

# Override these values with as specified above
: ${S3_URL:="http://127.0.0.1:8080"}
: ${S3FS_CREDENTIALS_FILE:="passwd-s3fs"}
: ${TEST_BUCKET_1:="s3fs-integration-test"}

S3PROXY_VERSION="1.4.0"
S3PROXY_BINARY=${S3PROXY_BINARY-"s3proxy-${S3PROXY_VERSION}"}

if [ ! -f "$S3FS_CREDENTIALS_FILE" ]
then
	echo "Missing credentials file: $S3FS_CREDENTIALS_FILE"
	exit 1
fi
chmod 600 "$S3FS_CREDENTIALS_FILE"

TEST_BUCKET_MOUNT_POINT_1=${TEST_BUCKET_1}
if [ ! -d $TEST_BUCKET_MOUNT_POINT_1 ]
then
	mkdir -p $TEST_BUCKET_MOUNT_POINT_1
fi

function retry {
    set +o errexit
    N=$1; shift;
    status=0
    for i in $(seq $N); do
        $@
        status=$?
        if [ $status == 0 ]; then
            break
        fi
        sleep 1
    done

    if [ $status != 0 ]; then
        echo "timeout waiting for $@"
    fi
    set -o errexit
    return $status
}

function start_s3proxy {
    if [ -n "${S3PROXY_BINARY}" ]
    then
        if [ ! -e "${S3PROXY_BINARY}" ]; then
            wget "https://github.com/andrewgaul/s3proxy/releases/download/s3proxy-${S3PROXY_VERSION}/s3proxy" \
                --quiet -O "${S3PROXY_BINARY}"
            chmod +x "${S3PROXY_BINARY}"
        fi

        stdbuf -oL -eL java -jar "$S3PROXY_BINARY" --properties s3proxy.conf | stdbuf -oL -eL sed -u "s/^/s3proxy: /" &

        # wait for S3Proxy to start
        for i in $(seq 30);
        do
            if exec 3<>"/dev/tcp/127.0.0.1/8080";
            then
                exec 3<&-  # Close for read
                exec 3>&-  # Close for write
                break
            fi
            sleep 1
        done

        S3PROXY_PID=$(netstat -lpnt | grep :8080 | awk '{ print $7 }' | sed -u 's|/java||')
    fi
}

function stop_s3proxy {
    if [ -n "${S3PROXY_PID}" ]
    then
        kill $S3PROXY_PID
        wait $S3PROXY_PID
    fi
}
