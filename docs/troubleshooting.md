# Troubleshooting and feedback

[Documentation index](./index.md)

## Server setup

Launch GitHub Copilot CLI from your project root and run `/lsp show`. You should see a "cpp" server configured.

- If the server is missing, check the [installation](./installation.md) and [Copilot CLI configuration](./configuration.md).
- If authentication fails, check [GitHub login and alternative authentication methods](./authentication.md). On Linux, also check the [runtime and keyring requirements](./installation.md#linux-requirements).
- If automatic configuration discovery fails, ensure there is exactly one `compile_commands.json` in the workspace folder, or use an explicit `cpp-lsp.json`. See [automatic discovery](./configuration.md#minimal-configuration-automatic-discovery) and [generating compile commands](./compile-commands.md).
- If background indexing uses too much CPU or memory, see [disabling WCI](./indexing.md#disabling-wci) for the setting and its trade-offs.
- For questions about which files are indexed, see [indexing](./indexing.md).

## Logs

Additional detailed logs are stored in a session-specific directory at `$TEMP/mscppls/<session-id>/logs`. Before attaching any logs to a public issue, review the content of the log to remove any sensitive information.

Use `--log-dir <path>` to choose a log directory and `--log-level <level>` to set logging verbosity from 0 (errors only) to 9 (verbose). The `--stderr` flag keeps standard error output available for debugging. See the [command line reference](./command-line-options.md) and [launch flag configuration](./configuration.md#customizing-copilot-cli-launch-flags).

## Reporting feedback

To report a problem or suggest an improvement to the Microsoft C++ Language Server, [open an issue on this repo](https://github.com/microsoft/cpp-language-server/issues/new). Please include the operating system, version of GitHub Copilot CLI and Microsoft C++ Language Server (reported with `--version`), and any relevant configuration or project files in your report.