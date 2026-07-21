---
name: generate-compile-commands
description: Generate compile_commands.json (clang compilation database) for the C++ language server. Covers MSBuild (.sln, .slnx, .vcxproj) via microsoft/msbuild-extractor-sample and CMake projects via CMAKE_EXPORT_COMPILE_COMMANDS. Use whenever the user asks to "regenerate compile commands", "regenerate the project", "reload the project", "load the project", "refresh compile commands", or otherwise needs a fresh compilation database for mscppls.
---

# Generate compile_commands.json

The C++ language server needs a `compile_commands.json` (clang compilation database) to understand a project. How you produce one depends on the build system: CMake can export it directly, MSBuild needs an external extractor.

Always regenerate `compile_commands.json` when this skill runs, even if one already exists for the project. For MSBuild, write it to `.mscppls\compile_commands.json` at the workspace root (the examples below do this); mscppls auto-discovers any `compile_commands.json` within the workspace, so no `cpp-lsp.json` is required. Add `.mscppls/` to `.gitignore` so it does not get committed. mscppls hot-reloads the file content; `/restart` is only needed after changing the plugin's `lsp.json` or the workspace `cpp-lsp.json` (those are read once at LSP startup).

## CMake projects

CMake writes `compile_commands.json` itself; no external extractor needed. Enable it at configure time:

```bash
cmake -S . -B build -DCMAKE_EXPORT_COMPILE_COMMANDS=ON
cmake --build build
```

Or persist it in the project so every configure picks it up:

```cmake
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
```

The file lands at `<build-dir>/compile_commands.json` (whatever directory you passed to `-B`). Point the workspace `cpp-lsp.json` at it:

```json
{
  "version": 1,
  "repositoryPath": "../",
  "compileCommands": "../build/compile_commands.json"
}
```

CMake regenerates the file on the next configure (e.g. running `cmake -B build` again, or `cmake --build build` after editing `CMakeLists.txt`). The refresh story for CMake is "re-run cmake configure"; the MSBuild-specific sections below do not apply.

## MSBuild projects

For MSBuild (`.sln`, `.slnx`, `.vcxproj`), generate `compile_commands.json` with [`microsoft/msbuild-extractor-sample`](https://github.com/microsoft/msbuild-extractor-sample). Extraction is design-time: it evaluates projects and runs `GetClCommandLines`, it does **not** compile anything.

### Get the extractor

Download the pinned release and verify its SHA256 before trusting it. The binary is self-contained, with no .NET runtime needed.

```powershell
$version  = 'v0.2.0'
$expected = '01a5e2d399c3cb84d3136d0b6ef7b84a05900838ddc3b1f710b9394c8c2936ce'
$exe      = ".tools\msbuild-extractor-sample.exe"

if (-not (Test-Path $exe) -or (Get-FileHash $exe -Algorithm SHA256).Hash -ne $expected.ToUpper()) {
  New-Item -ItemType Directory -Path ".tools" -Force | Out-Null
  $tmp = "$exe.download"
  Invoke-WebRequest -Uri "https://github.com/microsoft/msbuild-extractor-sample/releases/download/$version/msbuild-extractor-sample.exe" -OutFile $tmp
  $actual = (Get-FileHash $tmp -Algorithm SHA256).Hash
  if ($actual -ne $expected.ToUpper()) {
    Remove-Item $tmp -Force
    throw "SHA256 mismatch`n  expected: $expected`n  actual:   $actual"
  }
  Move-Item $tmp $exe -Force
}
```

When upgrading the pinned version, get the new SHA256 from the `digest` field of the asset at `https://api.github.com/repos/microsoft/msbuild-extractor-sample/releases/latest`.

### Run it

For a typical project on a workstation with Visual Studio installed, the extractor auto-detects Visual Studio via `vswhere.exe` and resolves `VCTargetsPath`, `VCToolsInstallDir`, and `cl.exe` automatically. Solution-based extraction is the simplest entry point:

```powershell
New-Item -ItemType Directory -Path .mscppls -Force | Out-Null
.tools\msbuild-extractor-sample.exe `
  --solution myapp.sln `
  -c Debug -a x64 `
  -o .mscppls\compile_commands.json
```

`-c` is `--configuration` (default `Debug`), `-a` is `--platform` (e.g. `x64`, `Win32`, `ARM64`), `-o` is `--output`. `--solution` accepts `.sln` and `.slnx`; it is repeatable for cross-solution work. `--project` works the same way for individual `.vcxproj` files (also repeatable, deduplicates entries).

#### From a Developer Command Prompt or activated vcvars shell

If you launched a Developer Command Prompt / Developer PowerShell for VS, or ran `vcvarsall.bat x64`, the toolchain env vars (`VCINSTALLDIR`, `VCToolsInstallDir`, `INCLUDE`, `LIB`, etc.) are already set in the current shell. Pass `--use-dev-env` to make the extractor honor them rather than re-resolving via `vswhere`:

```powershell
.tools\msbuild-extractor-sample.exe `
  --use-dev-env `
  --solution myapp.sln `
  -c Debug -a x64 `
  -o .mscppls\compile_commands.json
```

This guarantees the LSP indexes against the exact same toolchain the developer is building with. Use it whenever the project depends on a specific VS version, SDK, or side-by-side toolchain that the default `vswhere` heuristic might not pick.

#### Multiple VS installs

If `vswhere` picks the wrong one, list and select explicitly:

```powershell
.tools\msbuild-extractor-sample.exe --list-instances
.tools\msbuild-extractor-sample.exe --vs-instance <id> --solution myapp.sln -c Debug -a x64
```

#### Multi-configuration projects

Prefer the built-in flags over manual merging; they produce one IntelliSense-friendly entry per source file across all configurations:

```powershell
.tools\msbuild-extractor-sample.exe `
  --solution myapp.sln `
  --all-configurations --merge --deduplicate `
  -o .mscppls\compile_commands.json
```

Skip `--validate` during normal LSP setup. It compiles every TU with `cl.exe /c` and is slow. Reach for it only when debugging the extractor itself.

### Advanced: out-of-process mode for vendored or hermetic-toolchain repos

Some repos vendor a hermetic toolchain (MSBuild, the C++ compiler, Windows SDK headers, targets files) into the repo itself, for example as NuGet packages, a mounted toolchain ISO, or a `.tools\` directory. Builds are driven by a wrapper or environment-activation script (`build.cmd`, `init.cmd`, `LaunchBuildEnv.cmd`, etc.) that sets `PATH`, `VCTargetsPath`, `INCLUDE`, and `LIB` to point at the vendored versions. A fully public example is [`microsoft/Windows-driver-samples`](https://github.com/microsoft/Windows-driver-samples) built with the Enterprise WDK (EWDK), a self-contained command-line toolchain you mount and activate with `LaunchBuildEnv.cmd`.

If you let the extractor's default **in-process** MSBuild evaluation run in such a repo:

- It loads the MSBuild API from the running .NET host, which then probes the system Visual Studio install for targets, not the repo's vendored MSBuild.
- The compile commands point at the system `cl.exe`, which is a different version than the one the repo actually builds with. The LSP then fails to find the right intrinsics, conformance flags, or module `.ifc` files and reports phantom errors.
- Tightly integrated environments may fail outright with `REGDB_E_INVALIDVALUE` because the in-proc API tries to read VS COM registration that the vendored toolchain doesn't provide.

The fix is **out-of-process mode**: spawn the repo's own MSBuild.exe via `--msbuild-path`, and pin the targets and compiler paths to match what the repo's normal build uses.

| Flag | Why |
|---|---|
| `--msbuild-path <wrapper-or-msbuild.exe>` | Drive the repo's own MSBuild (e.g. `build.cmd`) out-of-proc, so vendored targets/SDKs resolve correctly |
| `--vc-targets-path <repo path to VC\v170>` | Point at the vendored VC targets so MSBuild does not probe a global VS |
| `--cl-path <repo path to cl.exe>` | Pin the LSP to the same compiler version the repo builds with. Critical for matching intrinsics, std-lib paths, and module IFCs |
| `--msbuild-property BuildProjectReferences=false` | Skip transitive project-reference evaluation; vendored-toolchain repos often have deep graphs where this otherwise hangs |
| `--msbuild-property <repo-specific>=<value>` | Some repos need extra properties to evaluate correctly. Check the repo's build docs |

Example (the Windows driver samples built with the Enterprise WDK; the version folders track the EWDK build, here `18` / `v180` / `14.50.35717`, so confirm them after mounting):

```powershell
.tools\msbuild-extractor-sample.exe `
  --msbuild-path "D:\Program Files\Microsoft Visual Studio\18\BuildTools\MSBuild\Current\Bin\MSBuild.exe" `
  --solution general\echo\kmdf\kmdfecho.sln `
  -c Debug -a x64 `
  --vc-targets-path "D:\Program Files\Microsoft Visual Studio\18\BuildTools\MSBuild\Microsoft\VC\v180" `
  --cl-path "D:\Program Files\Microsoft Visual Studio\18\BuildTools\VC\Tools\MSVC\14.50.35717\bin\Hostx64\x64\cl.exe" `
  -o .mscppls\compile_commands.json
```

When the toolchain is already activated in the current shell (for example after running the EWDK's `LaunchBuildEnv.cmd`), pass `--use-dev-env` instead of the explicit `--msbuild-path`, `--vc-targets-path`, and `--cl-path`, and the extractor reads those paths from the environment.

The extractor cannot consume `dirs.proj` or aggregate `.proj` files; point it at a real leaf `.vcxproj` (or `.sln`).

If the repo needs initialization for its props, targets, and dependencies to resolve, initialize it once, then run the extractor.

> **Note:** Verify initialization at most once; avoid re-checking the same state (for example a build environment variable) or re-requesting approval in a loop.
> If you can't confirm initialization, initialize the repo (or ask the user once), then run the extractor. Use `--msbuild-path` to select the intended MSBuild for vendored toolchains, but don’t treat it as a substitute for repo initialization.

### Manual merge fallback

`--all-configurations --merge --deduplicate` handles almost every multi-config case. Reach for a manual merge only when projects genuinely need conflicting `--platform`, `--configuration`, or `--msbuild-property` flags and have to be extracted in separate invocations. Write each invocation's output to a distinct file under `.mscppls\` (e.g. `.mscppls\compile_commands_debug.json`), then merge:

```powershell
$all = @{}
Get-ChildItem .mscppls\compile_commands_*.json | ForEach-Object {
  (Get-Content $_ -Raw | ConvertFrom-Json) | ForEach-Object {
    $key = $_.file.ToLowerInvariant()
    if (-not $all.ContainsKey($key)) { $all[$key] = $_ }
  }
}
ConvertTo-Json -InputObject @($all.Values) -Depth 6 | Set-Content .mscppls\compile_commands.json -Encoding UTF8
```

`@($all.Values)` forces an array even with a single entry; otherwise `ConvertTo-Json` emits a bare object and the file is not a valid compilation database.

## Troubleshooting

These cover the MSBuild extractor path. For CMake, build-system errors come from `cmake` itself.

| Symptom | Cause | Fix |
|---|---|---|
| `REGDB_E_INVALIDVALUE`, or compile commands point at the wrong `cl.exe` | In-proc MSBuild picked up a system VS install instead of the repo's vendored toolchain | Switch to out-of-process mode with `--msbuild-path` and pin `--vc-targets-path` / `--cl-path` |
| Extractor hangs | Transitive project-reference evaluation on a deep build graph | Add `--msbuild-property BuildProjectReferences=false` |
| `--validate` reports missing module `.ifc` | Module producer not built | Build dependencies first, or just skip `--validate` |
| LSP doesn't see newly extracted entries | mscppls observer is still hashing the new file | Wait a few seconds; mscppls hot-reloads, so do **not** `/restart` |
| `vswhere` picks the wrong VS install | Multiple VS instances present | `--list-instances` then `--vs-instance <id>` |

For extractor diagnostics, re-run the same command and read its stderr inline; don't redirect to a file.
