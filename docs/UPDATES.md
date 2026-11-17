# Publishing in-app updates

Version 1.5.8 adds Sparkle 2.10.1. Settings → Check for Updates compares the installed bundle build with the signed feed, then offers download, verification, installation, and relaunch. Background checking and unattended installation are off by default. Versions 1.5.7 and earlier require one manual upgrade to install this updater.

The app uses separate `appcast-arm64.xml` and `appcast-x86_64.xml` assets from the latest GitHub Release. Keep both feeds and their signed ZIP archives in each new release; publishing only a DMG would break subsequent checks. The public key is in `Info.plist`. Its private key is stored only in the publishing Mac's login Keychain under the Sparkle account `app.trafficlightsplus.mac`; never commit or upload it.

1. Increment both version strings in `Info.plist` and update `CHANGELOG.md`.
2. Run `swift test --disable-keychain --disable-netrc -Xswiftc -warnings-as-errors`.
3. Run `./scripts/package-updates.sh`. This builds both architectures, verifies the application bundles, and uses Sparkle's tools to sign the ZIP archives and feeds. Signing requires access to the dedicated update-signing key, not GitHub credentials. `SPARKLE_ED_KEY_FILE` can optionally point to a protected private key file on a publishing machine.
4. Create a GitHub Release draft targeting the tested source commit. Upload both ZIP files, both appcast XML files, and optional DMGs. Complete the GitHub CI checks before publishing as the latest release.
5. Test checking from the current version and an older Sparkle-enabled build, including download, installation, and relaunch. Test that a changed update archive fails signature verification.

Swift Package Manager credential lookup is disabled in the build script because the dependency and its binary release are public. Downloaded dependency archives are still checked against SwiftPM's pinned checksum. The packaged application embeds Sparkle and its signed helper programs; `validate-release-asset.sh` checks the framework, feed URL, key, version, architecture, and code signatures.

## 中文

从 1.5.8 开始，“检查更新”可以完成版本判断、下载、签名验证、安装与重启。1.5.7 及更早版本需要先手动升级一次。默认不进行后台检查或无人值守安装。

后续每次发布都要上传两个架构的 ZIP 安装包和对应的 `appcast-*.xml`，再设为最新 Release。不要只上传 DMG。运行 `scripts/package-updates.sh` 可生成并验证这些文件。更新签名私钥保存在本机登录钥匙串中，账户为 `app.trafficlightsplus.mac`，不属于 GitHub 凭据，也不能提交到仓库。
