# Configuring the MSBuild Extractor for Custom Build Systems

[`microsoft/msbuild-extractor-sample`](https://github.com/microsoft/msbuild-extractor-sample)
generates a `compile_commands.json` (a clang compilation database) from MSBuild C++ projects so
C++ language services can initialize their LSP server and provide code intelligence. For a normal
`.sln`/`.vcxproj` built with an installed Visual Studio it auto-detects the toolchain through
`vswhere.exe` and usually needs no configuration. Other MSBuild setups can still need configuration
(for example multiple Visual Studio installs, a specific platform toolset or SDK, or projects that
must be restored first); the `generate-compile-commands` skill covers those. The setup below is for
a **custom** toolchain: a
hermetic or vendored toolset that ships inside the repo and is activated by a wrapper script,
which the automatic detection won't find on its own.

## Signs you need a configuration skill

You probably need one if the default setup does not just work for your repo. The first sign is
visible up front, before you run anything; the rest show up after extraction:

- Up front, in how the repo builds: it vendors its own toolchain (a checked-in or
  package-restored compiler, Windows SDK, and MSBuild/targets) and builds through a wrapper or
  environment-activation script rather than an installed Visual Studio, so stock `vswhere`
  auto-detection will not match it.
- The extractor finishes but produces an empty or nearly empty `compile_commands.json`.
- Your editor shows red squiggles and errors on code that builds fine normally.
- IntelliSense can't find standard headers, or seems to use the wrong compiler version.
- The optional `--validate` check (it runs the real compiler on the extracted commands) fails on
  sources that build fine in your normal build, with a toolchain error rather than an error in
  your own code.
- The extractor seems to hang or takes a very long time on a large project.

These usually mean the extractor found a different toolchain than the one your repo actually
builds with. The fix is to point it at your repo's own build tools (out-of-process mode), which
the example below shows how to do.

To verify, inspect the generated `compile_commands.json` before assuming the toolchain is wrong:

- Check it is not empty: it should have roughly one entry per translation unit. In PowerShell,
  `(Get-Content .mscppls\compile_commands.json -Raw | ConvertFrom-Json).Count`.
- Open one entry and confirm its `command`/`arguments` reference the compiler you actually build
  with (your repo's `cl.exe`, not a system Visual Studio one) and include your project's include
  paths and defines.
- In the CLI, run `/lsp show` to confirm the `cpp` server is configured, then ask a navigation
  question (for example where a symbol is defined); if it resolves, the database is being used.

## Settings to capture

| Flag | Why |
|---|---|
| `--msbuild-path` | Run the repo's own MSBuild out-of-process so its targets and SDK resolve |
| `--vc-targets-path` | Pin the vendored VC targets (use an absolute path) |
| `--cl-path` | Pin the same compiler the repo builds with (use an absolute path) |
| `--use-dev-env` | Read toolchain paths from an activated developer environment instead of relying on `vswhere.exe` auto-detection |
| `-c` / `-a` | The repo's configuration and platform |
| `--msbuild-property BuildProjectReferences=false` | Skip deep reference graphs that otherwise hang |
| `--msbuild-property KEY=VALUE` | Any repo-specific property the build needs |

Point the extractor at a real `.sln`, `.slnx`, or `.vcxproj` file.

## Designing the SKILL

A skill is a folder with a `SKILL.md`: YAML frontmatter (`name`, `description`) plus a body with
the pinned extraction command and any project lookup. Keep it generic and document only what is
different about your repo. The `description` is what makes the assistant auto-invoke the skill,
so phrase it with the words users type (generate, regenerate, or refresh compile commands; set
up C++ IntelliSense).

## What to put in your SKILL

These keep the generated database matched to your real build, so encode them in your `SKILL.md`.

Bake into the extraction command:

- Use absolute paths for `--vc-targets-path` and `--cl-path`.
- Prefer out-of-process mode (`--msbuild-path`) in a vendored repo; when you have an activated developer environment (for example EWDK), `--use-dev-env` can also pin extraction to the intended toolchain.
- Point at a `.sln` or a specific `.vcxproj`, not a generated or aggregate project file.

Capture as prerequisites or notes in the skill body:

- Restore first if the project's targets come from a package: `msbuild <sln> /t:restore`.
- Omit `--validate` for IntelliSense setup; it recompiles every file and is slow.
- Always regenerate fresh; never reuse a stale `compile_commands.json`.
- Pin the extractor version and verify its SHA256 (releases ship a self-contained single-file exe).

## Example: Windows driver samples with the EWDK

[`microsoft/Windows-driver-samples`](https://github.com/microsoft/Windows-driver-samples) built
with the **Enterprise WDK (EWDK)** is a fully public version of this case. The EWDK is a free,
self-contained command-line toolchain (an ISO you mount) that bundles MSBuild, the compiler,
the Windows SDK, and the WDK, and is activated by `LaunchBuildEnv.cmd`. Because it ships its
own tools, point the extractor at the EWDK explicitly.

The driver projects pull their build logic in through `$(VCTargetsPath)` (the
`WindowsKernelModeDriver10.0` toolset) and reference no NuGet packages, so the EWDK already
provides everything and there is no `/t:restore` step.

Where things live (EWDK mounted at `D:\`, repo at `C:\src\Windows-driver-samples`). Folder names
track the EWDK release, so confirm them after mounting. This example is build 28000.1839, which
ships Visual Studio 18 Build Tools, MSVC 14.50.35717, and WDK 10.0.28000.0:

| Item | Path |
|---|---|
| Activation wrapper | `D:\LaunchBuildEnv.cmd` |
| MSBuild | `D:\Program Files\Microsoft Visual Studio\18\BuildTools\MSBuild\Current\Bin\MSBuild.exe` |
| VC targets | `D:\Program Files\Microsoft Visual Studio\18\BuildTools\MSBuild\Microsoft\VC\v180` |
| Compiler | `D:\Program Files\Microsoft Visual Studio\18\BuildTools\VC\Tools\MSVC\14.50.35717\bin\Hostx64\x64\cl.exe` |
| Example solution | `C:\src\Windows-driver-samples\general\echo\kmdf\kmdfecho.sln` |

The reliable way to run it is from an activated EWDK shell, so the extractor uses the EWDK
toolchain instead of any Visual Studio that also happens to be installed on the machine.

A skill that captures it:

````markdown
---
name: wdk-samples-generate-compile-commands
description: Generate compile_commands.json for the Windows driver samples built with the EWDK. Use when setting up C++ IntelliSense or extracting compile commands from WDK .vcxproj/.sln files.
---

# Generate compile_commands.json for the Windows driver samples (EWDK)

The EWDK is self-contained and bundles the WDK, so there is no NuGet restore step. Run from an
activated EWDK shell and let the extractor read the toolchain from the environment.

## Prerequisites

- Mount the EWDK ISO (for example as `D:`) and start its shell: `D:\LaunchBuildEnv.cmd`.
- Confirm the toolchain is active: `where cl.exe` resolves under the mounted EWDK.

## Extraction command

From the activated EWDK shell, in the repo root:

```powershell
.tools\msbuild-extractor-sample.exe `
  --use-dev-env `
  --solution general\echo\kmdf\kmdfecho.sln `
  -c Debug -a x64 `
  -o compile_commands.json
```

`--use-dev-env` reads the toolchain environment the EWDK exports (`VCToolsInstallDir`,
`VCTargetsPath`, `WindowsSdkDir`, `INCLUDE`, `LIB`), which pins extraction to the EWDK.

## Alternative: explicit paths

If you cannot use an activated shell, pin the EWDK tools by hand. On a machine that also has
Visual Studio installed, prefer the activated shell so the extractor does not pick up the system
toolchain.

```powershell
.tools\msbuild-extractor-sample.exe `
  --msbuild-path "D:\Program Files\Microsoft Visual Studio\18\BuildTools\MSBuild\Current\Bin\MSBuild.exe" `
  --solution general\echo\kmdf\kmdfecho.sln `
  -c Debug -a x64 `
  --vc-targets-path "D:\Program Files\Microsoft Visual Studio\18\BuildTools\MSBuild\Microsoft\VC\v180" `
  --cl-path "D:\Program Files\Microsoft Visual Studio\18\BuildTools\VC\Tools\MSVC\14.50.35717\bin\Hostx64\x64\cl.exe" `
  -o compile_commands.json
```

## Notes

- The EWDK bundles the WDK, so the driver `.vcxproj` files resolve their targets without a NuGet restore.
- The version folders (`18`, `v180`, `14.50.35717`, `10.0.28000.0`) track the EWDK build; confirm them after mounting.
- Point at the `.sln` or a specific `.vcxproj`, not a generated or aggregate project file.
````

### Invoking the skill to generate compile_commands.json

- "Generate compile_commands.json for the kmdfecho driver sample"
- "Set up C++ IntelliSense for the Windows driver samples using the EWDK"
