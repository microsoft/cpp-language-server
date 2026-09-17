# Authentication

[Documentation index](./index.md)

## Logging in to GitHub

Before using the Microsoft C++ Language Server, you must accept the end-user license agreement (EULA), which is distributed as [`EULA/LICENSE.txt`](https://www.npmjs.com/package/@microsoft/cpp-language-server?activeTab=code) in the npm package. Accept the agreement by running `npx @microsoft/cpp-language-server --accept-eula` (or `mscppls --accept-eula` if installed directly). You only need to accept the EULA once.

Using the Microsoft C++ Language Server requires an active GitHub Copilot subscription. Before using the language server for the first time, log in to GitHub by running `npx @microsoft/cpp-language-server --login` (or `mscppls --login` if installed directly) and following the on-screen instructions.

## Alternative authentication methods

By default, the language server stores your GitHub tokens in system secret storage. On Linux, this requires `libsecret`. If you are running the language server in a constrained environment where system secret storage is unavailable, run `npx @microsoft/cpp-language-server --login --allow-plaintext-secret-storage` (or `mscppls --login --allow-plaintext-secret-storage` if installed directly) to allow storing the tokens in plaintext.

Alternatively, you can independently generate a GitHub token (such as a PAT) and save it in the `MSCPPLS_GITHUB_TOKEN` environment variable. The token does not need to have any scopes.

### Using the GitHub CLI (GitHub Enterprise Cloud)

If no token is found in system secret storage or the `MSCPPLS_GITHUB_TOKEN` environment variable, the language server will fall back to the [GitHub CLI](https://cli.github.com/) and run `gh auth token` to obtain a token for the current session. This requires the GitHub CLI (`gh`) to already be installed and on your `PATH`, and that you have authenticated with it (for example, via `gh auth login`). The token is used only for the current session and is not stored by the language server.

This is the recommended way to use the language server with **GitHub Enterprise Cloud**. Authenticate the GitHub CLI against your enterprise host and then point the language server at the same host with `--login-hostname`:

```text
gh auth login --hostname myenterprise.ghe.com
mscppls --login-hostname myenterprise.ghe.com
```

The `--login-hostname` value is passed through to `gh auth token --hostname <host>`. If omitted, the GitHub CLI's default host (`github.com`) is used. Classic personal access tokens (those beginning with `ghp_`) returned by the GitHub CLI are rejected.

`--login-hostname` can be added to the `args` in `lsp.json` to pass it every time the language server launches. See [customizing Copilot CLI launch flags](./configuration.md#customizing-copilot-cli-launch-flags).