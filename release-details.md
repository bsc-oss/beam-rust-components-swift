# Release

Default dir is pg-rust-components-swift.

## Build
* Make sure to build `pg-ruma`, `cargo build --release`
* In pg-rust-sdk
* `unset SDKROOT && cargo xtask swift build-framework --release --target aarch64-apple-ios --target aarch64-apple-ios-sim --target x86_64-apple-ios`
* it generates `pg-rust-sdk/bindings/apple/generated/MatrixSDKFFI.xcframework`

## Zip & checksum
* From pg-rust-sdk/bindings/apple/generated : `zip -r [...]/pg-rust-components-swift/MatrixSDKFFI.xcframework.zip MatrixSDKFFI.xcframework`
* in pg-rust-components-swift, get the SHA256 checksum of the zip with `sha256sum MatrixSDKFFI.xcframework.zip`

## Copy sources
* copy sources: `rsync -a --delete ../pg-rust-sdk/bindings/apple/generated/swift/ ./Sources/MatrixRustSDK`

## Update Package.swift
* pg-rust-components-swift/Package.swift
* update the version in line: `let version = "xx.xx.xx"`
* update the checksum in line: `let checksum = "xxxx"`

## Commit and push
* git add "Package.swift", "Sources" folder
* git commit: Bump to version xx.xx.xx
* git tag
* git push --tags

## make release
* upload the xcframework.zip
    * adapt the version of publish-gitlab.sh script
    * run `./publish-gitlab.sh`
* create the gitlab release
    * add the binary as package
    * add in release notes the commit of deployed the pg-rust-sdk