---
name: setup-cpp-language-server
description: Checks that configuration files are correctly set up for using the LSP tool with C++.
---

Using the LSP tool with C++ requires three configuration files before it will work correctly:

1. A `.github/lsp.json` file that specifies how to launch the language server. It should have content like this:

```json
{
  "lspServers": {
    "cpp": {
      "command": "mscppls",
      "args": ["--lsp-config", ".mscppls/cpp-lsp.json"],
      "fileExtensions": {
        ".cpp": "cpp",
        ".cxx": "cpp",
        ".c": "cpp",
        ".cc": "cpp",
        ".hpp": "cpp",
        ".hxx": "cpp",
        ".hh": "cpp",
        ".h": "cpp"
      },
      "requestTimeoutMs": 1000000
    }
  }
}
```

2. A `.mscppls/cpp-lsp.json` file that configures the path to the `compile_commands.json` file. This file **must** follow the schema below, where all paths are relative to the `.mscppls` directory. `repositoryPath` is the relative path to the repository root and `compileCommands` is the relative path to the `compile_commands.json` file.

```json
{
 "repositoryPath": "../",
 "compileCommands": "../build/compile_commands.json"
}
```

3. A `compile_commands.json` file that specifies the compile command lines for each file in the project. This file can exist anywhere in the project and is typically produced by the build system.

Your job is to ensure these configuration files are correctly set up.

1. If all required files exist and appear correct, stop. All checks have passed and it's okay to run the C++ LSP tools. Note that your built-in search tools often ignore files in the build directory, so double-check using terminal commands.
2. If `compile_commands.json` does not exist, help the user create the file for their project. Don't complete any other tasks and ensure the `compile_commands.json` file is created before continuing.
  a. For CMake projects, it's often possible to produce the file by including `-DCMAKE_EXPORT_COMPILE_COMMANDS=ON`. This option is not supported when using the Visual Studio generators (default for CMake on Windows), but it is supported with Ninja and Makefile generators.
  b. For MSBuild-based C++ projects (`.vcxproj`, `.sln`, `.slnx`), use [`msbuild-extractor-sample`](https://github.com/microsoft/msbuild-extractor-sample/releases) to generate the file, e.g. `msbuild-extractor-sample.exe --solution path\to\app.sln -c Debug -a x64 -o compile_commands.json`.
3. If `.mscppls/cpp-lsp.json` does not exist, create it based on the path to the `compile_commands.json` file.
4. If `.github/lsp.json` does not exist or does not have an entry for C++, create or update it to include the configuration shown above. Make sure the `args` field points to the correct path to `cpp-lsp.json`.
5. If you made any changes to `compile_commands.json`, `.mscppls/cpp-lsp.json`, or `.github/lsp.json`, guide the user to restart their chat session before using the C++ LSP tools. The tools need to be restarted.