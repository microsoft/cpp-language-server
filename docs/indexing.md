# Indexing

[Documentation index](./index.md)

## Semantic symbol indexing (WCI)

WCI is the language server's semantic symbol index. It is enabled by default and provides an indexed path for operations such as Go to Definition and Find References. Building the index uses CPU and memory, which can be more noticeable on large codebases.

### Disabling WCI

To reduce background indexing work, set `use_symbol_index` to the JSON boolean `false` in the language server's per-user `state.json` file. This setting applies to **all repositories for that user**; it does not belong in your project's `cpp-lsp.json` or Copilot CLI's `lsp.json`.

1. Close running Copilot CLI sessions that use the C++ language server.
2. Open the state file for your platform:

   | Platform | State file |
   | --- | --- |
   | Windows | `%LOCALAPPDATA%\mscppls\state.json` |
   | macOS and Linux | `$HOME/.mscppls/state.json` |

3. Add or update the `use_symbol_index` property in the existing top-level JSON object, preserving all other properties. If the file does not exist, create its parent directory and a file containing:

   ```json
   {
     "use_symbol_index": false
   }
   ```

4. Restart Copilot CLI so the language server reads the updated setting.

Disabling WCI turns off the semantic symbol index, not the language server, its browse-directory scan, or on-demand IntelliSense parsing. Definition and reference requests fall back to other parsing paths and may take longer without indexed results.

To re-enable WCI, set `use_symbol_index` to `true` and restart the language server again.

> [!IMPORTANT]
> The state file can also contain authentication data and other user settings. Do not replace an existing file with only the example above, commit it to your repository, or attach it to a public issue.

## Excluding files and customizing indexed directories

The translation units listed in `compile_commands.json` are **not** affected by the exclude settings below. The directories containing those translation units are also scanned to discover additional files (such as headers) to index for browsing and symbol search, and this scan applies a small set of default excludes. The settings in `cpp-lsp.json` customize only this additional directory scan; they are separate from the WCI setting above:

- **Add exclude globs** via `filesExclude` (hides files from the browse/symbol-index scan) and `searchExclude` (excludes files from search). These apply only to the directory scan; they do not remove the translation units listed in `compile_commands.json`. Your entries merge on top of the defaults; set a pattern to `false` to un-exclude a default.
- **Include additional directories** in the scan via `browse.path`. The scanned directories are always derived from the `compile_commands.json` entries; `browse.path` specifies further directories to index/parse on top of those. Entries support `${workspaceFolder}` substitution (resolves to `repositoryPath`).

```json
{
  "version": 1,
  "repositoryPath": "../",
  "compileCommands": "../build/compile_commands.json",
  "filesExclude": { "**/out": true, "**/third_party": true },
  "searchExclude": { "**/*.generated.h": true },
  "browse": { "path": ["${workspaceFolder}/src"] }
}
```

See [configuration](./configuration.md) for where to place `cpp-lsp.json` and how its paths are resolved.