#!/bin/bash

set -e

GITLAB_URL="https://private-registry"
PROJECT_ID="29"
PACKAGE_NAME="pg-rust-components-swift"
VERSION="0.0.30"
XCFRAMEWORK_ZIP_PATH="./MatrixSDKFFI.xcframework.zip"
ACCESS_TOKEN="" # Update value with the gitlab project access token named "release".

ZIP_FILENAME=$(basename "$XCFRAMEWORK_ZIP_PATH")

UPLOAD_URL="${GITLAB_URL}/api/v4/projects/${PROJECT_ID}/packages/generic/${PACKAGE_NAME}/${VERSION}/${ZIP_FILENAME}"

echo "Uploading $ZIP_FILENAME to $UPLOAD_URL"

curl --fail --silent --show-error --request PUT \
  --header "PRIVATE-TOKEN: ${ACCESS_TOKEN}" \
  --upload-file "${XCFRAMEWORK_ZIP_PATH}" \
  "${UPLOAD_URL}"

echo "✅ Successfully published ${ZIP_FILENAME} to GitLab Generic Package Registry."