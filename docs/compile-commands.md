# Generating compile commands

[Documentation index](./index.md)

The language server uses a [`compile_commands.json` file](https://clang.llvm.org/docs/JSONCompilationDatabase.html) to understand how each translation unit in your project is built. Compiler options, include paths, and preprocessor definitions all affect how the language server interprets your source files. This compilation database supplies the build context needed for accurate Go to Definition, Find References, and other semantic code intelligence.

For MSBuild-based projects on Windows, the language server can [generate this file automatically at startup](#automatic-msbuild-configuration). For other build systems or manual setup, use the guidance below, then follow the [configuration guide](./configuration.md) to point the language server at the file or use automatic discovery.

## Generate with Copilot CLI

For CMake or manual MSBuild (vcxproj) setup, run the [`generate-compile-commands` skill](../plugins/cpp-language-server/skills/generate-compile-commands/SKILL.md) in GitHub Copilot CLI with a prompt like "regenerate compile commands" or "load project" to generate the file and configure the language server. The skill is included with the `cpp-language-server` plugin. MSBuild projects using automatic configuration do not need a separate skill invocation.

If you don't want to use the skill, follow the build-system guidance below.

## CMake

CMake projects that use the Ninja or Makefile generators can easily create a `compile_commands.json` by setting the [`CMAKE_EXPORT_COMPILE_COMMANDS` variable](https://cmake.org/cmake/help/latest/variable/CMAKE_EXPORT_COMPILE_COMMANDS.html) during configuration. For CMake projects that typically use other generators, first check if it is possible as a one-off to configure the project using the Ninja or Makefile generator, as this is the easiest way to get `compile_commands.json`.

Add `-DCMAKE_EXPORT_COMPILE_COMMANDS=ON` to your CMake configuration command.

For AI assistance with this step, try adding [this skill](../skills/setup-cpp-language-server/SKILL.md) to GitHub Copilot CLI and running it. [Learn more about skills](https://docs.github.com/en/copilot/how-tos/copilot-cli/customize-copilot/create-skills) with the GitHub Copilot CLI documentation.

## MSBuild (vcxproj)

To set up an MSBuild-based project, you can either supply a `compile_commands.json` yourself or run the automatic MSBuild configuration built-in to the extension.

### Automatic MSBuild configuration

On Windows, the Microsoft C++ Language Server bundles an MSBuild compile commands extractor and runs it automatically during startup when `compile_commands.json` needs to be generated. You do not need to invoke a separate configuration skill for this automatic setup.

The generated compilation database captures your project's compiler options, include paths, and preprocessor definitions. For example, when you ask Copilot to find a function's definition or identify its callers, the language server uses that build context to interpret the code and resolve symbol relationships.

To disable automatic configuration or change how long it can run, use the settings below. If you prefer to generate the compilation database yourself, see [generating compile commands manually](#generating-compile-commands-manually).

### Configuring automatic MSBuild extraction

You can disable automatic MSBuild extraction or adjust its timeout in the language server's per-user `state.json` file on Windows. These settings apply to **all repositories for that user**; they do not belong in your project's `cpp-lsp.json` or Copilot CLI's `lsp.json`.

1. Close running Copilot CLI sessions that use the C++ language server.
2. Open `%LOCALAPPDATA%\mscppls\state.json`.
3. Add or update the following properties in the existing top-level JSON object, preserving all other properties. If the file does not exist, create its parent directory and a file containing:

   ```json
   {
     "auto_generate_compile_commands_for_msbuild": false,
     "msbuild_extractor_timeout_seconds": 120
   }
   ```

4. Restart Copilot CLI so the language server reads the updated settings.

`auto_generate_compile_commands_for_msbuild` set to the JSON boolean `false` disables automatic MSBuild extraction. To re-enable it, set the property to `true` and restart the language server again.

`msbuild_extractor_timeout_seconds` sets the timeout in seconds and applies only when automatic extraction is enabled. In the example above, automatic extraction is disabled, so the 120-second timeout has no effect until you re-enable it. Changes take effect on the next language-server startup.

> [!IMPORTANT]
> The state file can also contain authentication data and other user settings. Do not replace an existing file with only the example above, commit it to your repository, or attach it to a public issue.

### Generating compile commands manually

If you disable automatic extraction, you can still generate `compile_commands.json` with the [Copilot CLI skill](#generate-with-copilot-cli) or manually.

Refer to [this sample application](https://github.com/microsoft/msbuild-extractor-sample) for an example of how to generate `compile_commands.json` from MSBuild projects. While the sample application is designed to work out-of-the-box for many projects, it may require adaptation for complex projects.

## Other build systems

Refer to your build system vendor's documentation.

For custom or non-standard builds, we recommend capturing the steps to generate `compile_commands.json` in a project-specific skill so the process is reproducible for you and your team. Once you've worked out the commands needed to produce the file, save them as a skill (for example, in your project's `skills/` directory) following the [GitHub Copilot CLI skills documentation](https://docs.github.com/en/copilot/how-tos/copilot-cli/customize-copilot/create-skills). The [`setup-cpp-language-server` skill](../skills/setup-cpp-language-server/SKILL.md) is a good starting template to adapt.

For guidance on authoring a project-specific skill, see [authoring an extractor skill](../AUTHORING_EXTRACTOR_SKILL.md).