# FalloutCraft F4SE plugin: SIGF's reproducible build

FalloutCraft (zeyvu, MIT, built on chasmlol's SkyCraft) ships its Fallout 4 side as `commonlibf4-template.dll`, an F4SE
plugin compiled inside libxse/commonlibf4-template with libxse/commonlibf4 (both GPL-3.0). The binary is therefore
distributed under the GPL, and whoever redistributes it owes its Corresponding Source. Upstream's release (v0.1.3,
commit `70032ac`) does not record which template / library commits built its DLL, so the SIGF app ships **our own
build** of the same sources, every repository pinned to a 40-character commit. `package-fusion.mjs` uses this DLL
(pinned sha256) instead of upstream's and writes every repository + commit into `SOURCE.txt` next to the plugin.

Files:

| Path | What |
|---|---|
| `orchestrator/scripts/build-falloutcraft.ps1` | The build: tools, clones at pinned commits (verified), upstream's build steps, toolchain record |
| `orchestrator/fusions/falloutcraft/commonlibf4-template.dll` | The DLL we ship (reference build below) |
| `orchestrator/fusions/falloutcraft/build-info.json` | Its provenance: sources + commits, toolchain versions, commands, sha256 |
| `orchestrator/fusions/falloutcraft/xmake-requires.lock` | xmake's package lock (spdlog, cmake, ninja + the xmake-repo commit) |

## Pinned sources

| Repository | Commit | License | Why this commit |
|---|---|---|---|
| github.com/zeyvu/FalloutCraft | `70032ac7ec66749a45099e08611f9ec9c399235b` | MIT | tag v0.1.3 (the release we package) |
| github.com/libxse/commonlibf4-template | `e70c24ab6d1b12478a9fc09ff99aedb73d1f394a` | GPL-3.0 | newest template commit (2026-09-02), before v0.1.3 (2026-10-04); still its HEAD |
| github.com/libxse/commonlibf4 | `16cff6870d92d0018e25c971a7bbd42d91f97871` | GPL-3.0 | the template's submodule pointer at that commit (2026-09-02, "xmake build rules"); targets runtime 1.11.240 (`RUNTIME_LATEST`) |
| github.com/libxse/commonlib-shared | `9fbb74d628134ab4ea3a3cf5c0ed3f7eeabbd01d` | GPL-3.0 | commonlibf4's submodule pointer at that commit |
| github.com/gabime/spdlog | `486b55554f11c9cccc913e11a87085b2a91f706f` (v1.16.0) | MIT | pinned by commonlib-shared (`add_requires("spdlog v1.16.0")`), the one linked package |
| github.com/xmake-io/xmake-repo | `8238b08ac745dd641958d827149689c6c2f592a7` | Apache-2.0 | package recipes (spdlog source URL + hash), not linked |

Why the template's own submodule pointer and not commonlibf4's newest pre-release commit (`7c8c6f8`, 2026-09-22):
upstream's documented build (FalloutCraft README, "Building from source") is `git clone --recurse-submodules
libxse/commonlibf4-template`, which checks out exactly `e70c24a` + `16cff68` + `9fbb74d`; FalloutCraft's sources use
none of the APIs added in `16cff68..7c8c6f8`. We built both on the same VM: the `7c8c6f8` build
(`e8e536e0...d048`) has the same section sizes, exports, imports and F4SE version data as the `16cff68` one, so the
choice changes nothing measurable; we ship the one upstream's procedure produces.

## Toolchain (reference build)

- Visual Studio Build Tools 2026 18.10.3, workload `Microsoft.VisualStudio.Workload.VCTools --includeRecommended`:
  MSVC 14.51.36231, `cl` 19.51.36260 (the same compiler build as upstream's DLL: identical Rich header), Windows SDK 10.0.26100.0
- xmake 3.1.1 (`xmake-v3.1.1.win64.zip`, sha256 `33fdf2f3...b4a2`), MinGit 2.56.0 (sha256 `064b440f...f718`)
- spdlog built by xmake with CMake 4.3.4 + Ninja 1.13.2 from xmake-repo
- Windows Server 2025 Datacenter (EC2 AMI `Windows_Server-2025-English-Full-Base-2026.09.17`), as SYSTEM over SSM

The VS bootstrapper (`aka.ms/vs/18/stable`) always installs the current 18.x, so a later rebuild may get a newer
MSVC: `build-info.json` records what was used. To match bytes, use MSVC 14.51.

## Commands

On a clean Windows x64 machine (nothing else needed; the script downloads git, xmake and the VS Build Tools):

```powershell
powershell -ExecutionPolicy Bypass -File orchestrator\scripts\build-falloutcraft.ps1 -InstallTools -VerifyRepro
# -> C:\fcbuild\out\commonlibf4-template.dll (.pdb, build-info.json, xmake-requires.lock, build.log)
```

What it runs, after cloning each repository and checking out its pinned commit:

```bat
cd C:\fcbuild\commonlibf4-template
git submodule update --init --recursive --force       & rem verified: 16cff68 / 9fbb74d
copy /Y ..\FalloutCraft\FO4_ModFiles\*.cpp src\
copy /Y ..\FalloutCraft\FO4_ModFiles\*.h src\
copy /Y ..\FalloutCraft\FO4_ModFiles\xmake.lua xmake.lua
xmake repo --update                                   & rem then xmake-repo checked out at 8238b08
xmake f -c -y -p windows -a x64 -m release --policies=package.requires_lock --cxflags=/Brepro --ldflags=/Brepro --shflags=/Brepro
xmake build -r -y
```

Upstream's steps exactly (the default `release` mode: FalloutCraft's xmake.lua only declares `mode.debug` and
`mode.releasedbg`, so like upstream's DLL this one is built without `/O2`), plus `/Brepro`: the PE timestamp becomes a
content hash and `__DATE__` / `__TIME__` expand to `1`, so the same toolchain in the same folder (`C:\fcbuild`, the
paths end up in `__FILE__` strings and the PDB path) gives the same bytes. `XSE_FO4_GAME_PATH` / `XSE_FO4_MODS_PATH`
are cleared: the build never installs into a game.

## Result

| | Ours | Upstream v0.1.3 (`FO4_Release/.../commonlibf4-template.dll`) |
|---|---|---|
| sha256 | `7467081787e80b3388cdb15dfd9fce2778a83f7fb9d0a1b715c1351b4aeb0c30` | `47ceec457386fea066f74d5b84272443099e87ff690f8edee96f9049e7d845c3` |
| size | 3,114,496 B | 3,115,520 B |
| rebuild (`-VerifyRepro`) | identical sha256 | n/a |
| exports | `F4SEPlugin_Load` (1), `F4SEPlugin_Preload` (2), `F4SEPlugin_Version` (3) | same |
| `F4SEPlugin_Version` | dataVersion 1, pluginVersion 0, name `commonlibf4-template`, author `libxse`, addressIndependence 4 (Address Library), structureIndependence 4, compatible `1.11.240.0` only, xseMinimum 0 | same (and same RVA `0x2c7540`) |
| imports | 26 DLLs, same functions (D3DCompiler_47, d3d11, dxgi, dbghelp, MSVCP140, VCRUNTIME140(_1), UCRT, ...) | same set |
| Rich header (compiler builds) | 36260 / 35721 / 33145 / 30729 | identical |
| VERSIONINFO | FileVersion 0.0.0.0, "F4SE plugin template using CommonLibF4", "GPL-3.0 License" | same |
| `.text` / `.rdata` virtual size | 2,422,828 / 479,554 | 2,422,924 / 480,450 |

Differences, all explained: the timestamp (`/Brepro` hash vs 2026-10-04 00:37:25 UTC); the PDB path
(`C:\fcbuild\...` vs `C:\Users\ihansi\Documents\GitHub\FalloutCraft\...`) and `__FILE__` source paths (`.rdata`
-896 B); the anonymous-namespace hashes in RTTI names (path-derived); `__DATE__` / `__TIME__`: upstream's log line
"SkyCraft (FalloutCraft) plugin build Oct  4 2026 02:37:21" reads "plugin build 1 1" in ours (also the crash log
header), and the two differently sized literals cost upstream one more `std::format` instantiation (`.text` +96 B, one
more `.pdata` entry). Every printable string is otherwise identical.

Not verified in game: nobody launched Fallout 4. Loading the plugin with F4SE 0.7.9 on 1.11.240 (check
`Documents\My Games\Fallout4\F4SE\commonlibf4-template.log`) and a FalloutCraft session with Minecraft is a human step.

## Updating

New upstream release or new pins: change the parameters (or defaults) of `build-falloutcraft.ps1`, build on a
temporary Windows VM (never mod-gpu, never a team PC), copy the outputs into `orchestrator/fusions/falloutcraft/`, set
`FUSIONS.falloutcraft.linked` commits and `rebuild.dll.sha256` / `toolchain` / `packages` in `package-fusion.mjs`,
then `node orchestrator/scripts/package-fusion.mjs falloutcraft --fixture` and the tests.
`--upstream-dll` packages upstream's binary instead (then the source is not known exactly).
