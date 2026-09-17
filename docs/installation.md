# Installation

[Documentation index](./index.md)

## Copilot CLI plugin

The recommended way to get started is to install the [`cpp-language-server` plugin from the copilot-plugins marketplace](https://github.com/github/copilot-plugins). From within GitHub Copilot CLI, run:

```text
/plugin install cpp-language-server@copilot-plugins
```

This bundles the language server and auto-updates with the latest version, so you don't need to install the npm package manually. Continue with [authentication](./authentication.md) and the [quick start](../README.md#quick-start).

## npm

The Microsoft C++ Language Server is distributed via npm.

- Install: `npm install -g @microsoft/cpp-language-server`
- Update: `npm update -g @microsoft/cpp-language-server`
- Uninstall: `npm uninstall -g @microsoft/cpp-language-server`

Installing the Microsoft C++ Language Server will add a new executable named `mscppls` to your environment. This executable acts both as an LSP server and as a utility to set certain configuration options.

## Supported platforms

- **Windows**: x64, arm64
- **macOS**: x64, arm64
- **Linux (glibc)**: x64, arm64, arm32 (Ubuntu 18.04+, Debian 10+, RHEL 8+)
- **Linux (musl/Alpine)**: x64, arm64, arm32 (Alpine 3.x+)

### Linux requirements

On Linux, the language server loads `libcurl` and `libsecret` at runtime for
telemetry, authentication, and credential storage.
Most distributions include these by default. If they are missing:

- **Debian/Ubuntu**: `sudo apt-get install libcurl4 libsecret-1-0 gnome-keyring`
- **RHEL/CentOS**: `sudo yum install libcurl libsecret gnome-keyring`
- **Alpine**: `apk add libcurl libsecret gnome-keyring`

On ARM (arm64/arm32), `libatomic` is also required:

- **Debian/Ubuntu**: `sudo apt-get install libatomic1`
- **Alpine**: `apk add libatomic`

`gnome-keyring` is needed to save authentication tokens securely. On headless
environments (WSL, SSH, containers) where no keyring daemon is available, the
server will prompt with alternative options.