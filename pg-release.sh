#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUMA_DIR="$SCRIPT_DIR/../pg-ruma"
RUST_SDK_DIR="$SCRIPT_DIR/../pg-rust-sdk"
GENERATED_DIR="$RUST_SDK_DIR/bindings/apple/generated"

# Check for version argument
if [ -z "$1" ]; then
    echo -e "${RED}Error: Version argument required${NC}"
    echo "Usage: ./pg-release.sh <version> [--skip-build] [--skip-git]"
    echo "Example: ./pg-release.sh 0.0.23"
    exit 1
fi

VERSION="$1"
SKIP_BUILD=false
SKIP_GIT=false

# Parse additional arguments
shift
while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-build)
            SKIP_BUILD=true
            shift
            ;;
        --skip-git)
            SKIP_GIT=true
            shift
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Starting release process for version ${VERSION}${NC}"
echo -e "${GREEN}========================================${NC}"

# Step 1: Build pg-ruma
if [ "$SKIP_BUILD" = false ]; then
    echo -e "\n${YELLOW}Step 1: Building pg-ruma...${NC}"
    if [ ! -d "$RUMA_DIR" ]; then
        echo -e "${RED}Error: pg-ruma directory not found at $RUMA_DIR${NC}"
        exit 1
    fi
    cd "$RUMA_DIR"
    cargo build --release
    echo -e "${GREEN}✅ pg-ruma built successfully${NC}"

    # Step 2: Build pg-rust-sdk
    echo -e "\n${YELLOW}Step 2: Building pg-rust-sdk...${NC}"
    if [ ! -d "$RUST_SDK_DIR" ]; then
        echo -e "${RED}Error: pg-rust-sdk directory not found at $RUST_SDK_DIR${NC}"
        exit 1
    fi
    cd "$RUST_SDK_DIR"
    unset SDKROOT && cargo xtask swift build-framework --release \
        --target aarch64-apple-ios \
        --target aarch64-apple-ios-sim \
        --target x86_64-apple-ios
    echo -e "${GREEN}✅ pg-rust-sdk built successfully${NC}"
else
    echo -e "\n${YELLOW}Skipping build steps (--skip-build)${NC}"
fi

# Step 3: Zip xcframework
echo -e "\n${YELLOW}Step 3: Creating xcframework zip...${NC}"
cd "$SCRIPT_DIR"
if [ ! -d "$GENERATED_DIR/MatrixSDKFFI.xcframework" ]; then
    echo -e "${RED}Error: MatrixSDKFFI.xcframework not found at $GENERATED_DIR${NC}"
    exit 1
fi

# Remove old zip if exists
rm -f MatrixSDKFFI.xcframework.zip

cd "$GENERATED_DIR"
zip -r "$SCRIPT_DIR/MatrixSDKFFI.xcframework.zip" MatrixSDKFFI.xcframework
echo -e "${GREEN}✅ xcframework zipped successfully${NC}"

# Step 4: Calculate checksum
echo -e "\n${YELLOW}Step 4: Calculating SHA256 checksum...${NC}"
cd "$SCRIPT_DIR"
CHECKSUM=$(shasum -a 256 MatrixSDKFFI.xcframework.zip | awk '{print $1}')
echo -e "Checksum: ${GREEN}$CHECKSUM${NC}"

# Step 5: Copy sources
echo -e "\n${YELLOW}Step 5: Copying sources...${NC}"
rsync -a --delete "$GENERATED_DIR/swift/" "$SCRIPT_DIR/Sources/MatrixRustSDK"
echo -e "${GREEN}✅ Sources copied successfully${NC}"

# Step 6: Update publish-gitlab.sh
echo -e "\n${YELLOW}Step 6: Updating publish-gitlab.sh...${NC}"
sed -i '' "s/^VERSION=\".*\"/VERSION=\"$VERSION\"/" "$SCRIPT_DIR/publish-gitlab.sh"
echo -e "${GREEN}✅ publish-gitlab.sh updated${NC}"

# Step 7: Publish to GitLab (must happen BEFORE updating Package.swift)
echo -e "\n${YELLOW}Step 7: Publishing to GitLab...${NC}"
cd "$SCRIPT_DIR"
./publish-gitlab.sh
echo -e "${GREEN}✅ Published to GitLab${NC}"

# Step 8: Update Package.swift (after upload, so URL is valid)
echo -e "\n${YELLOW}Step 8: Updating Package.swift...${NC}"
sed -i '' "s/^let checksum = \".*\"/let checksum = \"$CHECKSUM\"/" "$SCRIPT_DIR/Package.swift"
sed -i '' "s/^let version = \".*\"/let version = \"$VERSION\"/" "$SCRIPT_DIR/Package.swift"
echo -e "${GREEN}✅ Package.swift updated${NC}"

# Step 9: Git operations
if [ "$SKIP_GIT" = false ]; then
    echo -e "\n${YELLOW}Step 9: Git commit and tag...${NC}"
    cd "$SCRIPT_DIR"

    # Stage only the VERSION line change in publish-gitlab.sh
    # (preserve working copy so other local changes like ACCESS_TOKEN aren't committed)
    cp publish-gitlab.sh publish-gitlab.sh.bak
    git checkout publish-gitlab.sh
    sed -i '' "s/^VERSION=\".*\"/VERSION=\"$VERSION\"/" publish-gitlab.sh
    git add publish-gitlab.sh
    mv publish-gitlab.sh.bak publish-gitlab.sh

    git add Package.swift Sources/
    git commit -m "Bump to version $VERSION"
    git tag "$VERSION"
    echo -e "${GREEN}✅ Git commit and tag created${NC}"

    echo -e "\n${YELLOW}Step 10: Pushing to remote...${NC}"
    git push
    git push --tags
    echo -e "${GREEN}✅ Pushed to remote${NC}"
else
    echo -e "\n${YELLOW}Skipping git operations (--skip-git)${NC}"
    echo "To complete manually:"
    echo "  git add Package.swift Sources/"
    echo "  git commit -m \"Bump to version $VERSION\""
    echo "  git tag \"$VERSION\""
    echo "  git push --tags"
fi

echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}Release process completed for version ${VERSION}${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Summary:"
echo "  Version:  $VERSION"
echo "  Checksum: $CHECKSUM"
echo ""
echo "Next steps:"
echo "  - Create GitLab release with binary as package"
echo "  - Add pg-rust-sdk commit hash to release notes"
