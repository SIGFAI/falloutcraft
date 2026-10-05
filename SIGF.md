# FalloutCraft, mirrored for the SIGF app

**FalloutCraft is made by [zeyvu](https://github.com/zeyvu), built on [SkyCraft](https://github.com/chasmlol/SkyCraft)
by [chasmlol](https://github.com/chasmlol).** All credit for the mod goes to them. The original project, its issues and
its updates live at **https://github.com/zeyvu/FalloutCraft**. Go there to report bugs, follow development or support
the authors.

This repository is a mirror kept by SIGFAI so the SIGF app can install FalloutCraft in one click. It holds:

1. the upstream source tree, unchanged, at tag `v0.1.3`, commit
   [`70032ac7ec66749a45099e08611f9ec9c399235b`](https://github.com/zeyvu/FalloutCraft/tree/70032ac7ec66749a45099e08611f9ec9c399235b),
   at the root of this repository;
2. the libraries the Fallout 4 plugin is compiled with, vendored as plain files under `vendor/` at pinned commits;
3. SIGF's build script and build record for the plugin, under `sigf/`;
4. `mashup.json`, the SIGF app recipe (added by a later commit), and the release `v0.1.3`, whose assets are what the app
   downloads.

The upstream files are not modified. The first commit only adds `SIGF.md`, `vendor/` and `sigf/`. Upstream's
`.gitmodules` (a leftover from SkyCraft, naming a submodule this tree does not contain) is kept as it was.

## Licenses

| Part | License | Where |
|---|---|---|
| FalloutCraft (everything outside `vendor/` and `sigf/`) | MIT, Copyright chasmlol (SkyCraft) and zeyvu (FalloutCraft) | `LICENSE` |
| commonlibf4-template, `vendor/commonlibf4-template/` | GPL-3.0 with the Modding Exception | its `LICENSE`, `EXCEPTIONS` |
| CommonLibF4, `vendor/commonlibf4-template/lib/commonlibf4/` | GPL-3.0 with the Modding Exception | its `LICENSE`, `EXCEPTIONS` |
| commonlib-shared, `vendor/commonlibf4-template/lib/commonlibf4/lib/commonlib-shared/` | GPL-3.0 with the Modding Exception | its `LICENSE`, `EXCEPTIONS` |
| spdlog v1.16.0, `vendor/spdlog/` | MIT, Copyright Gabi Melman | its `LICENSE` |
| `sigf/` (build script and records) | MIT | this file |

The plugin `commonlibf4-template.dll` is FalloutCraft's `FO4_ModFiles/` compiled inside the template and linked with
CommonLibF4, commonlib-shared and spdlog, so the plugin binary is distributed under the GPL-3.0; FalloutCraft's own code
stays MIT. Every LICENSE, EXCEPTIONS and NOTICE file is kept where its project put it.

## Vendored sources

| Path | Repository | Commit | License |
|---|---|---|---|
| `vendor/commonlibf4-template` | https://github.com/libxse/commonlibf4-template | `e70c24ab6d1b12478a9fc09ff99aedb73d1f394a` | GPL-3.0 |
| `vendor/commonlibf4-template/lib/commonlibf4` (the template's submodule) | https://github.com/libxse/commonlibf4 | `16cff6870d92d0018e25c971a7bbd42d91f97871` | GPL-3.0 |
| `vendor/commonlibf4-template/lib/commonlibf4/lib/commonlib-shared` (CommonLibF4's submodule) | https://github.com/libxse/commonlib-shared | `9fbb74d628134ab4ea3a3cf5c0ed3f7eeabbd01d` | GPL-3.0 |
| `vendor/spdlog` (tag `v1.16.0`, pinned by commonlib-shared, built by xmake) | https://github.com/gabime/spdlog | `486b55554f11c9cccc913e11a87085b2a91f706f` | MIT |

Each folder is byte-for-byte the tree of that commit (same git tree hash, nested submodules filled in the same way), so
`git rev-parse HEAD:vendor/spdlog` here equals `git rev-parse 486b555^{tree}` in spdlog's repository. Not vendored
because nothing from them is in the plugin: the xmake package recipes (https://github.com/xmake-io/xmake-repo at
`8238b08ac745dd641958d827149689c6c2f592a7`, Apache-2.0) and the CMake / Ninja that xmake used to build spdlog.

## The release binaries

The release `v0.1.3` of this repository has two assets:

- `falloutcraft-fallout4.zip`: unpacked into Fallout 4's `Data` folder. It holds `F4SE/Plugins/commonlibf4-template.dll`,
  **built by SIGF from exactly the sources in this repository** (FalloutCraft at `70032ac` plus the four vendored
  trees above, xmake package recipes at `8238b08`), sha256
  `7467081787e80b3388cdb15dfd9fce2778a83f7fb9d0a1b715c1351b4aeb0c30`, 3,114,496 bytes; upstream's
  `FalloutCraft_README.txt` (as `F4SE/Plugins/FalloutCraft/README.txt`) and `LICENSE`, unchanged; and a `SOURCE.txt` pointing here. SIGF ships its own build instead
  of upstream's DLL (`FO4_Release/`) because upstream does not record which template and library commits built theirs.
- `falloutcraft.mrpack`: a Modrinth pack for the Minecraft side: upstream's `falloutcraft-0.1.3.jar` from the
  [v0.1.3 release](https://github.com/zeyvu/FalloutCraft/releases/tag/v0.1.3), unchanged (sha256 `86f54f0e...f092`,
  built by upstream from `fabric/` in this tree), upstream's LICENSE, and a download link (Modrinth, not rehosted) for
  Fabric API.

The sha256 of every asset, and of every file inside the zip, is in `mashup.json`.

## Rebuilding the plugin

`sigf/` has what produced the shipped DLL:

| File | What |
|---|---|
| `sigf/build-falloutcraft.ps1` | The build: installs the tools, clones each repository above and checks out its pinned commit (verified), runs upstream's build steps, records the toolchain |
| `sigf/build-falloutcraft.md` | Why these commits, the toolchain, the exact commands, and how our DLL compares to upstream's |
| `sigf/build-info.json` | The reference build's record: sources and commits, toolchain versions, commands, sha256 of the DLL and of a second rebuild (identical) |
| `sigf/xmake-requires.lock` | xmake's package lock from that build (spdlog v1.16.0, cmake, ninja, xmake-repo commit) |

(`build-falloutcraft.md` names them by their paths in SIGF's own repository, `orchestrator/scripts/` and
`orchestrator/fusions/falloutcraft/`.)

On a clean Windows x64 machine:

```powershell
powershell -ExecutionPolicy Bypass -File sigf\build-falloutcraft.ps1 -InstallTools -VerifyRepro
# -> C:\fcbuild\out\commonlibf4-template.dll
```

The script clones the original repositories at the commits above, which are the trees vendored here. To build from this
mirror alone, the steps are upstream's (README, "Building from source"):

```bat
xcopy /E /I vendor\commonlibf4-template C:\fcbuild\commonlibf4-template
cd C:\fcbuild\commonlibf4-template
copy /Y <this repo>\FO4_ModFiles\*.cpp src\
copy /Y <this repo>\FO4_ModFiles\*.h src\
copy /Y <this repo>\FO4_ModFiles\xmake.lua xmake.lua
xmake f -c -y -p windows -a x64 -m release --cxflags=/Brepro --ldflags=/Brepro --shflags=/Brepro
xmake build -r -y
```

with Visual Studio Build Tools 2026 (MSVC 14.51.36231, Windows SDK 10.0.26100.0) and xmake 3.1.1. xmake fetches spdlog
v1.16.0 itself (the same source as `vendor/spdlog`). The same toolchain in the same folder (`C:\fcbuild`) gives the same
bytes. The Fabric jar builds with JDK 25: `gradlew build` (see upstream's README).

## Why this mirror exists

The SIGF app (https://sigf.ai) installs mods with recipes (`mashup.json`) whose downloads come only from release assets
of SIGFAI repositories. This mirror makes FalloutCraft available there, credited to zeyvu and chasmlol, and carries the
GPL Corresponding Source of the plugin binary next to it. If you are an author and want this changed or taken down,
open an issue here.
