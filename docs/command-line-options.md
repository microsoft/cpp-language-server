# Command line options for `mscppls`

[Documentation index](./README.md)

Use these options with `npx @microsoft/cpp-language-server [options]` or `mscppls [options]` if [installed globally](./installation.md#npm). To pass options whenever Copilot CLI launches the server, add them to the `args` in your [LSP configuration](./configuration.md#customizing-copilot-cli-launch-flags).

| Option | Description |
| --- | --- |
| `--help` or `-h` | Shows a help message with a description of all options. |
| `--version` | Shows version information and exits. |
| `--accept-eula` | Permanently accepts the end-user license agreement (EULA). The EULA only needs to be accepted once. However, it is safe to redundantly include this option with any other option, which can be helpful in automated environments. |
| `--stderr` | Do not redirect stderr to `/dev/null`. Useful for debugging. |
| `--login` | Interactively log in to GitHub. |
| `--force-login` | Force interactive login, even if the user has already logged in. |
| `--allow-plaintext-secret-storage` | Allow storing credentials in plaintext if secure system storage is unavailable. |
| `--login-hostname <host>` | GitHub hostname to use when obtaining a token from the GitHub CLI (`gh auth token`). Enables GitHub Enterprise Cloud support; requires the GitHub CLI to be installed and authenticated. If unspecified, the GitHub CLI's default host is used. |
| `--log-dir <path>` | Specify the directory for log files. If unspecified, the system temp directory is used. |
| `--log-level <level>` | Set the logging verbosity from 0 (errors only) to 9 (verbose). |
| `--lsp-config <path>` | Optional path to the `cpp-lsp.json` file. If relative, the path will be resolved relative to the current working directory of the `mscppls` process, which is typically the project root when launched from GitHub Copilot CLI. |
| `--allow-missing-lsp-config` | Enables fallback to automatic `compile_commands.json` discovery when `--lsp-config` is specified but the configuration file does not exist. |
| `--disable-telemetry` | Permanently disables sending telemetry data. |

## Disable telemetry

Run `npx @microsoft/cpp-language-server --disable-telemetry` (or `mscppls --disable-telemetry` if installed directly) to permanently disable telemetry. See the [data collection notice](../README.md#data-collection) for details.