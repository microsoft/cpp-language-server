# Generating compile commands

[Documentation index](./README.md)

The language server uses a [`compile_commands.json` file](https://clang.llvm.org/docs/JSONCompilationDatabase.html) to understand how each translation unit in your project is built. Generate this file with your build system, then follow the [configuration guide](./configuration.md) to point the language server at it or use automatic discovery.

## Generate with Copilot CLI

For CMake or MSBuild (vcxproj) projects, run the [`generate-compile-commands` skill](../plugins/cpp-language-server/skills/generate-compile-commands/SKILL.md) in GitHub Copilot CLI with a prompt like "regenerate compile commands" or "load project" to generate the file and configure the language server. The skill is included with the `cpp-language-server` plugin.

If you don't want to use the skill, follow the build-system guidance below.

## CMake

CMake projects that use the Ninja or Makefile generators can easily create a `compile_commands.json` by setting the [`CMAKE_EXPORT_COMPILE_COMMANDS` variable](https://cmake.org/cmake/help/latest/variable/CMAKE_EXPORT_COMPILE_COMMANDS.html) during configuration. For CMake projects that typically use other generators, first check if it is possible as a one-off to configure the project using the Ninja or Makefile generator, as this is the easiest way to get `compile_commands.json`.

Add `-DCMAKE_EXPORT_COMPILE_COMMANDS=ON` to your CMake configuration command.

For AI assistance with this step, try adding [this skill](../skills/setup-cpp-language-server/SKILL.md) to GitHub Copilot CLI and running it. [Learn more about skills](https://docs.github.com/en/copilot/how-tos/copilot-cli/customize-copilot/create-skills) with the GitHub Copilot CLI documentation.

## MSBuild (vcxproj)

Improved support for MSBuild projects is planned for a future release of the Microsoft C++ Language Server.

For now, refer to [this sample application](https://github.com/microsoft/msbuild-extractor-sample) for an example of how to generate `compile_commands.json` from MSBuild projects. While the sample application is designed to work out-of-the-box for many projects, it may require adaptation for complex projects.

## Other build systems

Refer to your build system vendor's documentation.

For custom or non-standard builds, we recommend capturing the steps to generate `compile_commands.json` in a project-specific skill so the process is reproducible for you and your team. Once you've worked out the commands needed to produce the file, save them as a skill (for example, in your project's `skills/` directory) following the [GitHub Copilot CLI skills documentation](https://docs.github.com/en/copilot/how-tos/copilot-cli/customize-copilot/create-skills). The [`setup-cpp-language-server` skill](../skills/setup-cpp-language-server/SKILL.md) is a good starting template to adapt.

For guidance on authoring a project-specific skill, see [authoring an extractor skill](../AUTHORING_EXTRACTOR_SKILL.md).