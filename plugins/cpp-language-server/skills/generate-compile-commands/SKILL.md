---
name: generate-compile-commands
description: Generate compile_commands.json (clang compilation database) for the C++ language server. Covers MSBuild (.sln, .slnx, .vcxproj) via microsoft/msbuild-extractor-sample and CMake projects via CMAKE_EXPORT_COMPILE_COMMANDS. Use whenever the user asks to "regenerate compile commands", "regenerate the project", "reload the project", "load the project", "refresh compile commands", or otherwise needs a fresh compilation database for mscppls.
---

# Generate compile_commands.json

The C++ language server needs a `compile_commands.json` (clang compilation database) to understand a project. How you produce one depends on the build system: CMake can export it directly, MSBuild needs an external extractor.

Always regenerate `compile_commands.json` when this skill runs, even if one already exists for the project. For MSBuild, write it to `.mscppls\compile_commands.json` at the workspace root (the examples below do this); mscppls auto-discovers any `compile_commands.json` within the workspace, so no `cpp-lsp.json` is required. Add `.mscppls/` to `.gitignore` so it does not get committed. mscppls hot-reloads the file content; `/restart` is only needed after changing the plugin's `lsp.json` or the workspace `cpp-lsp.json` (those are read once at LSP startup).

Do not mix build systems in one database. Which build system applies is a selection decision, not a guess: work through **Selecting the build system** below before running anything, then follow the matching section exactly.

## Selecting the build system (do this first)

Choose the build system before producing anything, in precedence order: (1) explicit user intent (asked for CMake or the MSBuild extractor); (2) committed configuration (a committed `msbuild-extractor.json` declares MSBuild; a committed CMake preset or established configure declares CMake); (3) workspace context (a `.sln`/`.slnx`/`.vcxproj` selected as the workspace or target is MSBuild); (4) the repo's build docs.

**Hard rule (narrow trigger).** Run the MSBuild extractor and reject a CMake- or Ninja-produced `compile_commands.json` only when (a) a committed `msbuild-extractor.json` is present, or (b) the task is explicitly MSBuild, or (c) a specific `.sln`/`.slnx`/`.vcxproj` is the selected workspace or target. Then use the extractor even if a `CMakeLists.txt` also exists; the finish check rejects a CMake-written database. The trigger is the selection decision, not mere presence: an incidental or stale `.sln`/`.slnx`/`.vcxproj` with none of (a)/(b)/(c) holding does not make the task MSBuild and does not reject CMake.

**Inverse guard.** If user intent or committed configuration selects CMake, CMake wins even when a solution file exists, and a CMake-only repo (no committed solution, no `.vcxproj`, no `msbuild-extractor.json`) uses the CMake export path. This rule never forbids CMake outright. **Tie-break:** if both a committed CMake config (`CMakePresets.json`, `CMakeSettings.json`) and a committed `msbuild-extractor.json` exist, explicit user CMake intent still wins; absent explicit CMake intent, the committed `msbuild-extractor.json` makes this an MSBuild extractor task.

## CMake projects

CMake writes `compile_commands.json` itself; no external extractor needed. It exports the file at **configure** time, so a single configure step is enough. Follow this recipe exactly. Non-negotiable rules for CMake projects:

- **Use the Ninja generator.** Pass `-G Ninja` explicitly. Do not let CMake pick its default generator (on Windows the default is a Visual Studio generator, which produces a per-configuration MSBuild layout instead of a single `compile_commands.json` at the expected path, or none at all). The generator must be Ninja.
- **Use the MSVC toolchain (`cl.exe`), never g++ or clang.** Configure from a Developer environment so `cl.exe` is the active compiler (a Developer Command Prompt / Developer PowerShell for VS, or after running `vcvarsall.bat x64`). If any g++, gcc, clang, or clang-cl is on `PATH`, CMake may select it: prevent that by setting the compiler explicitly with `-DCMAKE_C_COMPILER=cl -DCMAKE_CXX_COMPILER=cl`. The compiler in every entry must be `cl.exe`. Do not use g++, gcc, clang, or clang-cl.
- **Configure into the in-tree `build` directory.** Pass `-B build`. The file must land at `build\compile_commands.json`. Do not configure into `out\build`, `build\<config>`, a temporary directory, or a session-state path. The tooling only checks `build\compile_commands.json`, `compile_commands.json` (repository root), and `.mscppls\compile_commands.json`.
- **Enable export.** Pass `-DCMAKE_EXPORT_COMPILE_COMMANDS=ON`. Without it CMake writes nothing.
- **Do not pin a build type.** Do not pass `-DCMAKE_BUILD_TYPE`. The reference output is produced without a build type, so each project applies its own default; forcing a build type (for example Debug) changes the optimization and runtime flags (`/Od /RTC1 -MDd` instead of the project default) and makes every entry differ from the reference.
- **Do not run a full build to get the file.** Ninja plus `CMAKE_EXPORT_COMPILE_COMMANDS=ON` writes `compile_commands.json` during configure, before anything compiles. A full `cmake --build` is not required and only adds time (and timeout risk). Configure, confirm the file exists, and stop.

### Run it directly in one step

Configure once, from a Developer environment, with all settings pinned:

```powershell
cmake -S . -B build -G Ninja `
  -DCMAKE_EXPORT_COMPILE_COMMANDS=ON `
  -DCMAKE_C_COMPILER=cl -DCMAKE_CXX_COMPILER=cl
```

`-G Ninja` matches the reference generator. `-DCMAKE_C_COMPILER=cl -DCMAKE_CXX_COMPILER=cl` forces MSVC even when g++/clang are on `PATH`, and resolves to the same `cl.exe` the Developer environment already provides. `-B build` fixes the output location the tooling checks. Do not add `-DCMAKE_BUILD_TYPE`: the reference is generated without one.

After configure, verify the file is where it must be, then stop:

```powershell
Test-Path build\compile_commands.json
```

If it exists, you are done. Do not re-configure to "confirm", do not switch generators, and do not explore the repository further.

### Stale build directory

If `build\CMakeCache.txt` already exists from an earlier configure that used a different generator, build directory, or compiler, remove only the `build` directory and rerun the pinned configure. Do not preserve a cache that points at a non-Ninja generator or a non-MSVC compiler, and do not try to reconfigure over it.

```powershell
if (Test-Path build\CMakeCache.txt) { Remove-Item build -Recurse -Force }
```

### Settings to pin and things to avoid

The recipe is deliberately minimal. Each pinned setting maps to a known failure:

- **Pin** `-G Ninja`, `-DCMAKE_C_COMPILER=cl -DCMAKE_CXX_COMPILER=cl`, `-B build`, and `-DCMAKE_EXPORT_COMPILE_COMMANDS=ON`. That set reproduces the reference (Ninja, MSVC, in-tree `build`, export on). Do not pass `-DCMAKE_BUILD_TYPE`; the reference does not pin one, so forcing it makes every entry differ.
- **Do not** omit `-G Ninja` and accept CMake's default generator: on Windows that selects a Visual Studio generator and the compilation database will not match.
- **Do not** let CMake auto-detect the compiler when g++, gcc, clang, or clang-cl may be on `PATH`. Configure in a Developer environment and set `CMAKE_C_COMPILER` / `CMAKE_CXX_COMPILER` to `cl`.
- **Do not** change `-B build` to `out\build`, a nested per-config folder, a temp path, or a session-state path. The file must be at `build\compile_commands.json`.
- **Do not** run a full `cmake --build build` just to produce the file, and do not spend extra turns exploring or reconfiguring. Configure exports the file directly.

### Refresh

CMake regenerates `build\compile_commands.json` on the next configure (re-run the pinned `cmake -S . -B build -G Ninja ...` command above). The refresh story for CMake is "re-run cmake configure"; the MSBuild-specific sections below do not apply. Point the workspace `cpp-lsp.json` at the file if one is used:

```json
{
  "version": 1,
  "repositoryPath": "../",
  "compileCommands": "../build/compile_commands.json"
}
```

### CMake troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| Entries reference g++, gcc, clang, or clang-cl | CMake auto-detected a non-MSVC compiler from `PATH` | Configure from a Developer environment and pass `-DCMAKE_C_COMPILER=cl -DCMAKE_CXX_COMPILER=cl`; delete `build` and reconfigure |
| No `compile_commands.json`, or a Visual Studio solution/`.vcxproj` layout appears in `build` | Default (Visual Studio) generator was used | Pass `-G Ninja` explicitly; delete `build` and reconfigure |
| `build\compile_commands.json` not found by the tooling | Configured into a different directory (`out\build`, a nested config folder, a temp or session path) | Reconfigure with `-B build`; the file must be at `build\compile_commands.json` |
| Configure succeeds but no database is written | `-DCMAKE_EXPORT_COMPILE_COMMANDS=ON` was omitted | Add the flag and reconfigure |
| `cl` not found during configure | Not in a Developer environment | Start a Developer Command Prompt / Developer PowerShell for VS, or run `vcvarsall.bat x64`, then reconfigure |

## MSBuild projects

For MSBuild (`.sln`, `.slnx`, `.vcxproj`), the **only** correct way to produce `compile_commands.json` is the external extractor [`microsoft/msbuild-extractor-sample`](https://github.com/microsoft/msbuild-extractor-sample). You must run it. Non-negotiable rules for MSBuild projects:

- **Do run the extractor.** For any `.sln`, `.slnx`, or `.vcxproj` project, running the extractor is the required step. Producing a compilation database without it is a failure.
- **Do not hand-write, guess, or synthesize** a `compile_commands.json`, and do not copy or edit an existing one by hand.
- **Do not invoke `cl.exe`, `clang`, or `clang-cl` directly** to build a compile database, and do not scrape a build log. The extractor does this correctly via design-time evaluation.
- **Do not compile the project first.** Extraction is design-time: it evaluates projects and runs `GetClCommandLines`; it does **not** compile anything and does not need build outputs to exist.

### Run it directly in one step

The extractor is fast and design-time, so a **single invocation** is expected. Do not explore the repository extensively, run a test build, or re-run the extractor to "confirm" the result. Locate the project file, resolve the configuration once (tiered procedure below), run the command once, and stop. One retry is allowed only after a nonzero extractor exit: if it failed because restore/init-generated props, targets, or package files are missing (common in C++/WinRT and restore-heavy repos), run the repo's documented restore or init once (e.g. `nuget restore`; not a test build), then retry extraction once. After a successful extraction with output present, stop.

1. If a committed `msbuild-extractor.json` names `solutions`, pass exactly that declared solution and pass the config's path with `--config` (Tier 1); skip independent discovery. If the declared solution is missing, fall back to discovery and warn. Otherwise find the primary committed solution at its conventional location (typically a single `.sln` or `.slnx` at the repository root or a top-level source folder). Do not invent a solution name and do not create a new solution.
2. If there is no solution but a single `.vcxproj`, use `--project <that .vcxproj>`. If several committed solutions exist, pick the primary product solution (conventional root location, or the one the build docs name), not a sample, test, or benchmark solution.
3. Produce **one real configuration** per source file. Do not pass `--all-configurations`, `--merge`, `--deduplicate`, or `--validate` unless the user explicitly asks: a merged union of all configurations matches no actual build command and is not deterministic across machines with different installed platforms. The correct database contains exactly the switches from one concrete configuration and platform.
4. Determine the correct configuration and platform with the tiered procedure below, then run the extractor once.

### Choosing the configuration and platform (do this, do not assume)

The correct configuration and platform are the **project's own default**, never a fixed value and never `Debug`/`x64` as an unstated fallback. Resolve in order: (1) **explicit user config/platform**, if named; (2) **committed `msbuild-extractor.json`** (Tier 1 below), authoritative for configuration, platform, and inputs; (3) **the selected solution or project's declared or default configuration and platform** (Tier 2 below), from repository metadata; (4) **if still unresolved**, ask the user in an interactive session, or classify the ambiguity as unresolved and record it in an autonomous run. Never prefer `x64` over `Win32`/`ARM64` or `Debug` over `Release`. Follow the tiers in order.

#### Tier 1: a committed `msbuild-extractor.json` exists (primary, correct by construction)

A committed `msbuild-extractor.json` next to the solution already declares the intended `configuration`, `platform`, and inputs, and reproduces identically on any machine and installed platform set. Pass its path **explicitly** with `--config`, and pass the declared `solutions` value as `--solution`; that plus `-o` is the whole command. Do **not** pass `-c`/`-a` (they would override the committed configuration and platform), and do **not** rely on bare auto-discovery: the v0.3.0 extractor auto-discovers `msbuild-extractor.json` only from the current working directory, so running from any other directory silently falls back to `Debug`/`x64` and produces a wrong-platform database. Passing `--config` is robust to the working directory.

```powershell
New-Item -ItemType Directory -Path .mscppls -Force | Out-Null
msbuild-extractor-sample.exe `
  --config <path>\msbuild-extractor.json `
  --solution <the declared solution> `
  -o .mscppls\compile_commands.json
```

Use a repo-root-relative or absolute path for `--config`. If the declared solution is missing, fall back to Tier 2 discovery and warn. Leave the config file untouched. (A future extractor could auto-discover the config by walking up from the solution directory; until then, pass `--config` explicitly.)

#### Tier 2: no committed config (determine the solution's own default)

This tier applies **only when no committed `msbuild-extractor.json` exists**. If one exists, use Tier 1 (`--config`) and do not derive or pass `-c`/`-a`. With no committed config, do **not** run the extractor bare and silently accept its built-in `Debug`/`x64` fallback, which is correct only when that happens to be this solution's own default. Read the declared default and pass it explicitly with `-c`/`-a`:

- **`.sln`:** the first entry of `GlobalSection(SolutionConfigurationPlatforms)` is the default (for example `Debug|Win32`). If its platform is concrete (`Win32`, `x64`, `ARM64`), use it. If it is an alias (`Mixed Platforms`, `Any CPU`), resolve it through the C++ project's `GlobalSection(ProjectConfigurationPlatforms)` entry (the right-hand side of `{GUID}.Debug|Mixed Platforms.ActiveCfg = Debug|Win32` gives the concrete platform).
- **`.slnx`:** read the first declared `<BuildType>`/`<Platform>` pair, then validate it against the selected C++ project's available configurations. If the pair is an alias or absent, resolve it through the leaf `.vcxproj`'s `ProjectConfiguration` list (below) rather than guessing.
- **A lone `.vcxproj`:** the first `ProjectConfiguration` item, or the empty-value defaults guarded by `Condition="'$(Configuration)'==''"` / `Condition="'$(Platform)'==''"`.

Then run the extractor with that exact configuration and platform:

```powershell
New-Item -ItemType Directory -Path .mscppls -Force | Out-Null
msbuild-extractor-sample.exe `
  --solution <the committed .sln or .slnx> `
  -c <the solution's default configuration> -a <the solution's default platform> `
  -o .mscppls\compile_commands.json
```

For a single-project repository with no solution, use `--project <the committed .vcxproj>` with the project's own default `-c`/`-a`. The extractor auto-detects Visual Studio via `vswhere.exe` and resolves the MSVC toolchain automatically.

After a successful Tier 2 run, offer to write a `msbuild-extractor.json` next to the solution capturing that default and recommend committing it, so later runs (via Tier 1 `--config`) and teammates reproduce it without re-deriving, for example:

```json
{
  "solutions": ["MySolution.sln"],
  "configuration": "Debug",
  "platform": "Win32"
}
```

Write `Debug`/`x64` here only if that is genuinely this solution's default. It is not a safe generic value.

#### Never invent a configuration

If you cannot determine the default configuration or platform from the solution and project files: in an interactive session ask the user which they build; in an autonomous run classify the ambiguity as unresolved and record it. Never fall back to `Debug`/`x64` or any guess: a wrong configuration produces a database whose switches do not match how the code is compiled.

### Flags to use and flags to avoid

Changing the flag set changes the entry set, the most common way to produce the wrong database.

- **Tier 1:** `--config <path>` + `--solution` (or `--project`) + `-o`. The committed config supplies configuration and platform, so omit `-c`/`-a` (they would override it).
- **Tier 2:** add `-c`/`-a` set to the solution's own default; never hardcode `Debug`, `x64`, or any platform.
- **Do not pass** `--all-configurations`, `--merge`, `--deduplicate`, or `--validate` unless the user asks; `--validate` compiles every TU with `cl.exe` and is slow.
- **Do not create, edit, or delete a committed `msbuild-extractor.json`.** Authoring a new one is only the offered follow-up after a Tier 2 run.

### If the extractor is not already available

The extractor is typically already built and available: try `msbuild-extractor-sample.exe` on `PATH`, or `.tools\msbuild-extractor-sample.exe`, before downloading. If present, use it and skip the download.

If it is not present, download the pinned release and verify its SHA256 before trusting it. The binary is self-contained, with no .NET runtime needed.

```powershell
$version  = 'v0.3.0'
$expected = '543c5cc6b57a1b3eb46b11e56b8f35a9ca8676106426bde6041ca2dc2e06f13c'
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

When upgrading the pinned version, get the new SHA256 from the `digest` field of the asset at `https://api.github.com/repos/microsoft/msbuild-extractor-sample/releases/latest`. If downloaded to `.tools\`, invoke `.tools\msbuild-extractor-sample.exe` in the recipes above.

### Developer environment (fallback only)

The default path passes no toolchain-selection flags and lets the extractor resolve MSVC via `vswhere`. Do not add `--use-dev-env` routinely. Use it only when default `vswhere` resolution fails, or when the user explicitly wants to index the already-active Developer environment (a Developer Command Prompt / Developer PowerShell, or a shell where `vcvarsall.bat` set `VCINSTALLDIR`, `INCLUDE`, `LIB`). It makes the extractor honor that environment instead of re-resolving via `vswhere`:

```powershell
msbuild-extractor-sample.exe `
  --use-dev-env `
  --solution <the committed .sln or .slnx> `
  -o .mscppls\compile_commands.json
```

(In Tier 2, add `-c`/`-a`.) Like `--vs-instance`, `--list-instances`, and `--msbuild-path`, `--use-dev-env` is an escape hatch for resolution failure or vendored toolchains, not a default-path flag.

#### Multiple VS installs

If `vswhere` picks the wrong one, list and select explicitly:

```powershell
msbuild-extractor-sample.exe --list-instances
msbuild-extractor-sample.exe --vs-instance <id> --solution <the committed .sln or .slnx> -o .mscppls\compile_commands.json
```

(Add `-c`/`-a` in Tier 2 as above.)

#### Multiple configurations (only when the user asks)

Only on explicit request, add `--all-configurations --merge --deduplicate` to merge every configuration into one entry per source file. This union matches no single build command and is not deterministic across machines with different installed platforms. Still skip `--validate` (it compiles every TU with `cl.exe /c` and is slow).

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

Config equivalent: these are exactly the settings to **commit** so every checkout resolves the same toolchain. Because the EWDK paths above are absolute and machine-specific, the portable committed form is to activate the toolchain first and set `"useDevEnv": true` in `msbuild-extractor.json`:

```jsonc
{
  "solutions": ["general\\echo\\kmdf\\kmdfecho.sln"],
  "configuration": "Debug",
  "platform": "x64",
  "useDevEnv": true,
  "output": ".mscppls\\compile_commands.json"
}
```

If a repo genuinely pins fixed toolchain paths, set `msBuildPath`, `vcTargetsPath`, `clPath`, and any `msBuildProperties` in the config instead — but keep them relative where possible so teammates' checkouts resolve them.

The extractor cannot consume `dirs.proj` or aggregate `.proj` files; point it at a real leaf `.vcxproj` (or `.sln`).

If the repo needs initialization for its props, targets, and dependencies to resolve, initialize it once, then run the extractor.

> **Note:** Verify initialization at most once; avoid re-checking the same state (for example a build environment variable) or re-requesting approval in a loop.
> If you can't confirm initialization, initialize the repo (or ask the user once), then run the extractor. Use `--msbuild-path` to select the intended MSBuild for vendored toolchains, but don’t treat it as a substitute for repo initialization.

### Manual merge fallback

A manual merge is only for the rare case where the user asks to combine configurations and the projects need conflicting `--platform`, `--configuration`, or `--msbuild-property` flags, requiring separate invocations. Write each output to a distinct file under `.mscppls\` (e.g. `.mscppls\compile_commands_debug.json`), then merge:

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

`@($all.Values)` forces an array even with a single entry; otherwise `ConvertTo-Json` emits a bare object, which is not a valid compilation database.

### Finish check

Before finishing, confirm all four: the extractor was invoked in this session; `.mscppls\compile_commands.json` exists; it is nonempty valid JSON (an array of entries); and it was produced by the extractor, not by CMake or Ninja (the accepted file is the extractor's `.mscppls\compile_commands.json`, not a `compile_commands.json` in a CMake build directory).

If the only database present was written by CMake for an MSBuild task under the narrow (a)/(b)/(c) trigger of **Selecting the build system**, the task is not done: run the extractor. On a CMake-only or explicitly-CMake repository, a CMake-produced database is correct and passes.

## Troubleshooting

These cover the MSBuild extractor path. For CMake, build-system errors come from `cmake` itself.

| Symptom | Cause | Fix |
|---|---|---|
| Wrong entries, or database looks like `Debug`/`x64` when the project builds something else | A committed `msbuild-extractor.json` was not passed with `--config`, so cwd auto-discovery missed it and the extractor fell back to `Debug`/`x64`; or the wrong `-c`/`-a`; or extra flags changed the entry set | In Tier 1 pass the committed config explicitly with `--config <path>` (bare auto-discovery only works from the config's own directory); else Tier 2 with `-c`/`-a`; pass no `--all-configurations`/`--merge`/`--deduplicate`/`--validate`; offer to commit a `msbuild-extractor.json` capturing it |
| `Configuration '...' not found in <project>. Available: ...` | The requested `-c`/`-a` is not one this project defines | Pick the listed pair matching the solution's declared default and re-run |
| Wrong solution extracted | Several committed solutions exist and a sample/test one was picked | If a committed `msbuild-extractor.json` exists, use its `solutions` entry; otherwise use the primary product solution, not a sample or test one |
| `compile_commands.json` produced by CMake for an MSBuild task | The CMake path was taken although a committed `msbuild-extractor.json`, an explicit MSBuild task, or a selected `.sln`/`.slnx`/`.vcxproj` made this MSBuild | Under trigger (a)/(b)/(c) of **Selecting the build system**, run the extractor and use its `.mscppls\compile_commands.json`; if the user selected CMake or the repo is CMake-only, the CMake database is correct |
| `REGDB_E_INVALIDVALUE`, or commands point at the wrong `cl.exe` | In-proc MSBuild picked a system VS install instead of the vendored toolchain | Switch to out-of-process mode with `--msbuild-path` and pin `--vc-targets-path`/`--cl-path` |
| Extractor hangs | Transitive project-reference evaluation on a deep graph | Add `--msbuild-property BuildProjectReferences=false` |
| `--validate` reports missing module `.ifc` | Module producer not built | Build dependencies first, or skip `--validate` |
| LSP doesn't see new entries | mscppls observer is still hashing the new file | Wait a few seconds; mscppls hot-reloads, so do **not** `/restart` |
| `vswhere` picks the wrong VS install | Multiple VS instances present | `--list-instances` then `--vs-instance <id>` |

For extractor diagnostics, re-run the same command and read its stderr inline; don't redirect to a file.
