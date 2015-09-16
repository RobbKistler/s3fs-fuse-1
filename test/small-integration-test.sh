#!/bin/bash

set -o xtrace
set -o errexit


# Require root
REQUIRE_ROOT=require-root.sh
#source $REQUIRE_ROOT
source integration-test-common.sh

function exit_handler {
    stop_s3proxy
    retry 30 fusermount -u $TEST_BUCKET_MOUNT_POINT_1
}
trap exit_handler EXIT

start_s3proxy

# Mount the bucket
stdbuf -oL -eL $S3FS $TEST_BUCKET_1 $TEST_BUCKET_MOUNT_POINT_1 \
    -o createbucket \
    -o enable_content_md5 \
    -o passwd_file=$S3FS_CREDENTIALS_FILE \
    -o sigv2 \
    -o singlepart_copy_limit=$((10 * 1024)) \
    -o url=${S3_URL} \
    -o use_path_request_style -f -o f2 -d -d |& stdbuf -oL -eL sed -u "s/^/s3fs: /" &

retry 30 grep $TEST_BUCKET_MOUNT_POINT_1 /proc/mounts || exit 1

./integration-test-main.sh $TEST_BUCKET_MOUNT_POINT_1

echo "All tests complete."
