<#
FalloutCraft's Fallout 4 F4SE plugin (commonlibf4-template.dll) built from pinned sources, so the binary the SIGF app
redistributes has exactly known GPL-3.0 Corresponding Source. See build-falloutcraft.md for the why, the pins and the
result of the reference build.

  powershell -ExecutionPolicy Bypass -File build-falloutcraft.ps1 -InstallTools      (fresh Windows: tools + build)
  powershell -ExecutionPolicy Bypass -File build-falloutcraft.ps1                    (tools already on PATH)

Upstream's build (README "Building from source"): clone libxse/commonlibf4-template with its submodules, copy
FalloutCraft's FO4_ModFiles/*.cpp *.h into src/ and FO4_ModFiles/xmake.lua over the template's, `xmake build -r`.
This script does exactly that, with every repository checked out at a pinned 40-character commit (verified), the
xmake package repository pinned, and /Brepro so the same toolchain in the same folder gives the same bytes (it also
makes __DATE__ / __TIME__ expand to "1": the plugin's "plugin build" log line shows "1 1").
Writes <Out>\commonlibf4-template.dll, .pdb, build-info.json, xmake-requires.lock, build.log.
Never installs into a game: XSE_FO4_GAME_PATH / XSE_FO4_MODS_PATH are cleared for the build.
#>
param(
  [string]$Work = 'C:\fcbuild',
  [string]$Out = 'C:\fcbuild\out',
  [string]$FalloutCraftSha = '70032ac7ec66749a45099e08611f9ec9c399235b',   # zeyvu/FalloutCraft v0.1.3
  [string]$TemplateSha = 'e70c24ab6d1b12478a9fc09ff99aedb73d1f394a',       # libxse/commonlibf4-template
  [string]$CommonLibF4Sha = '16cff6870d92d0018e25c971a7bbd42d91f97871',    # libxse/commonlibf4 (the template's submodule pointer)
  [string]$CommonLibSharedSha = '9fbb74d628134ab4ea3a3cf5c0ed3f7eeabbd01d',# libxse/commonlib-shared (commonlibf4's submodule pointer)
  [string]$XmakeRepoSha = '8238b08ac745dd641958d827149689c6c2f592a7',     # xmake-io/xmake-repo (the reference build's); '' = current, recorded
  [switch]$InstallTools,
  [switch]$VerifyRepro                                                     # rebuild once more and compare the DLL bytes
)
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Tools, pinned (sha256 of the downloads). Visual Studio Build Tools has no pinned bootstrapper: the installed MSVC and
# Windows SDK versions are recorded in build-info.json instead.
$MinGit = @{ url = 'https://github.com/git-for-windows/git/releases/download/v2.56.0.windows.1/MinGit-2.56.0-64-bit.zip'; sha = '064b440ff870ed5198527e8f3a92cdf5bd2fd0fedf5e718af95e3fdaddeff718' }
$Xmake = @{ url = 'https://github.com/xmake-io/xmake/releases/download/v3.1.1/xmake-v3.1.1.win64.zip'; sha = '33fdf2f34a0e45fa731c000d59590d27b13dec7011f69cbf575004ed9279b4a2' }
$VsBootstrapper = 'https://aka.ms/vs/18/stable/vs_buildtools.exe'   # Visual Studio 2026 Build Tools (upstream's DLL: MSVC 14.51)

New-Item -ItemType Directory -Force -Path $Work, $Out | Out-Null
$log = Join-Path $Out 'build.log'
function Say($m) { $l = "$(Get-Date -Format 'HH:mm:ss') $m"; Write-Host $l; Add-Content -Path $log -Value $l -Encoding utf8 }
function Run($exe, [string[]]$argv, $cwd = $Work) {
  Say "> $exe $($argv -join ' ')"
  Push-Location $cwd
  try {
    $prev = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    & $exe @argv 2>&1 | ForEach-Object { $s = "$_"; Write-Host $s; Add-Content -Path $log -Value $s -Encoding utf8 }
    $code = $LASTEXITCODE; $ErrorActionPreference = $prev
  } finally { Pop-Location }
  if ($code -ne 0) { throw "$exe exited $code" }
}
function Fetch($spec, $file) {
  Invoke-WebRequest -UseBasicParsing $spec.url -OutFile $file
  $got = (Get-FileHash $file -Algorithm SHA256).Hash.ToLower()
  if ($got -ne $spec.sha) { throw "$file sha256 $got, pinned $($spec.sha)" }
}

$tools = Join-Path $Work 'tools'
if ($InstallTools) {
  New-Item -ItemType Directory -Force -Path $tools | Out-Null
  Say 'installing MinGit 2.56.0'
  Fetch $MinGit "$tools\mingit.zip"; Expand-Archive "$tools\mingit.zip" "$tools\git" -Force
  Say 'installing xmake 3.1.1'
  Fetch $Xmake "$tools\xmake.zip"; Expand-Archive "$tools\xmake.zip" "$tools" -Force
  Say 'installing Visual Studio 2026 Build Tools (C++ workload)'
  Invoke-WebRequest -UseBasicParsing $VsBootstrapper -OutFile "$tools\vs_buildtools.exe"
  $p = Start-Process "$tools\vs_buildtools.exe" -Wait -PassThru -ArgumentList @('--quiet', '--wait', '--norestart', '--nocache',
    '--add', 'Microsoft.VisualStudio.Workload.VCTools', '--includeRecommended')
  if ($p.ExitCode -notin 0, 3010) { throw "vs_buildtools exited $($p.ExitCode)" }
  $env:PATH = "$tools\git\cmd;$tools\xmake;$env:PATH"
}
$env:XMAKE_GLOBALDIR = Join-Path $Work 'xmake-global'   # its own package cache and package repository clone
$env:XMAKE_ROOT = 'y'                                   # SSM runs as SYSTEM
$env:XMAKE_STATS = 'n'
Remove-Item Env:XSE_FO4_GAME_PATH, Env:XSE_FO4_MODS_PATH -ErrorAction SilentlyContinue
$git = (Get-Command git).Source; $xmake = (Get-Command xmake).Source

function Checkout($url, $dir, $sha) {
  if (-not (Test-Path "$dir\.git")) { Run $git @('clone', '-q', $url, $dir) }
  Run $git @('-c', 'advice.detachedHead=false', 'checkout', '-q', '--force', $sha) $dir
  $head = (& $git -C $dir rev-parse HEAD).Trim()
  if ($head -ne $sha) { throw "$dir is at $head, wanted $sha" }
}

# 1. Sources, every repository at its pinned commit.
$fc = Join-Path $Work 'FalloutCraft'
$tpl = Join-Path $Work 'commonlibf4-template'
Checkout 'https://github.com/zeyvu/FalloutCraft' $fc $FalloutCraftSha
Checkout 'https://github.com/libxse/commonlibf4-template' $tpl $TemplateSha
Run $git @('submodule', 'update', '--init', '--recursive', '--force') $tpl
$clf4 = Join-Path $tpl 'lib\commonlibf4'
if ((& $git -C $clf4 rev-parse HEAD).Trim() -ne $CommonLibF4Sha) {
  Run $git @('fetch', '-q', 'origin') $clf4
  Run $git @('checkout', '-q', '--force', $CommonLibF4Sha) $clf4
  Run $git @('submodule', 'update', '--init', '--recursive', '--force') $clf4
}
$shared = Join-Path $clf4 'lib\commonlib-shared'
if ((& $git -C $shared rev-parse HEAD).Trim() -ne $CommonLibSharedSha) {
  Run $git @('fetch', '-q', 'origin') $shared
  Run $git @('checkout', '-q', '--force', $CommonLibSharedSha) $shared
}
$pins = [ordered]@{}
foreach ($d in @($fc, $tpl, $clf4, $shared)) {
  $pins[(Split-Path $d -Leaf)] = [ordered]@{ url = (& $git -C $d remote get-url origin).Trim(); commit = (& $git -C $d rev-parse HEAD).Trim();
    dirty = [bool](& $git -C $d status --porcelain --ignore-submodules=none) }
}
if ($pins['commonlibf4'].commit -ne $CommonLibF4Sha -or $pins['commonlib-shared'].commit -ne $CommonLibSharedSha) { throw 'submodule pins not applied' }
$nested = & $git -C $tpl submodule status --recursive
Say "submodules:`n$($nested -join "`n")"

# 2. FalloutCraft's files into the template (upstream README), nothing else changed.
Run $git @('clean', '-q', '-fdx', 'src') $tpl
Run $git @('checkout', '-q', '--', 'src', 'xmake.lua') $tpl
Copy-Item "$fc\FO4_ModFiles\*.cpp", "$fc\FO4_ModFiles\*.h" "$tpl\src\" -Force
Copy-Item "$fc\FO4_ModFiles\xmake.lua" "$tpl\xmake.lua" -Force

# 3. xmake's package repository, pinned (spdlog v1.16.0 is the one package: commonlib-shared's add_requires).
Run $xmake @('repo', '--update') $tpl
$repoDir = Join-Path $env:XMAKE_GLOBALDIR '.xmake\repositories\xmake-repo'
if ($XmakeRepoSha) {
  Run $git @('fetch', '-q', 'origin') $repoDir
  Run $git @('checkout', '-q', '--force', $XmakeRepoSha) $repoDir
}
$pins['xmake-repo'] = [ordered]@{ url = (& $git -C $repoDir remote get-url origin).Trim(); commit = (& $git -C $repoDir rev-parse HEAD).Trim() }

# 4. Build: upstream's `xmake build -r` (default mode: release, x64), plus /Brepro for deterministic output and the
# package lock file. The DLL lands in build\windows\x64\release\.
$repro = '/Brepro'
Run $xmake @('f', '-c', '-y', '-p', 'windows', '-a', 'x64', '-m', 'release', '--policies=package.requires_lock',
  "--cxflags=$repro", "--ldflags=$repro", "--shflags=$repro", '-v') $tpl
Run $xmake @('build', '-r', '-y', '-v') $tpl
$bin = Join-Path $tpl 'build\windows\x64\release'
$dll = Join-Path $bin 'commonlibf4-template.dll'
if (-not (Test-Path $dll)) { throw "no $dll" }
$sha = (Get-FileHash $dll -Algorithm SHA256).Hash.ToLower()
Say "built $dll sha256 $sha"
$repro2 = $null
if ($VerifyRepro) {
  Copy-Item $dll "$Out\first.dll" -Force
  Run $xmake @('build', '-r', '-y') $tpl
  $repro2 = (Get-FileHash $dll -Algorithm SHA256).Hash.ToLower()
  Say "rebuild sha256 $repro2 ($(if ($repro2 -eq $sha) { 'identical' } else { 'DIFFERENT' }))"
}

# 5. Toolchain record.
$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
$vs = & $vswhere -products * -latest -format json | ConvertFrom-Json
$msvc = (Get-ChildItem "$($vs[0].installationPath)\VC\Tools\MSVC" | Sort-Object Name | Select-Object -Last 1).Name
$cl = "$($vs[0].installationPath)\VC\Tools\MSVC\$msvc\bin\Hostx64\x64\cl.exe"
$clBanner = ((cmd /c "`"$cl`" 2>&1") | Select-Object -First 1)
$sdk = (Get-ChildItem "${env:ProgramFiles(x86)}\Windows Kits\10\Include" -ErrorAction SilentlyContinue | Sort-Object Name | Select-Object -Last 1).Name
$spdlog = Get-ChildItem (Join-Path $env:XMAKE_GLOBALDIR '.xmake\packages\s\spdlog') -Directory -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name
$info = [ordered]@{
  dll = [ordered]@{ file = 'commonlibf4-template.dll'; sha256 = $sha; size = (Get-Item $dll).Length; rebuild_sha256 = $repro2 }
  sources = $pins
  packages = [ordered]@{ spdlog = $spdlog }
  toolchain = [ordered]@{ visual_studio = "$($vs[0].displayName) $($vs[0].catalog.productDisplayVersion)"; msvc = $msvc; cl = "$clBanner".Trim();
    windows_sdk = $sdk; xmake = (((& $xmake --version) | Select-Object -First 1) -replace "$([char]27)\[[0-9;]*m", '' -replace ',.*$', '').Trim(); git = (& $git --version).Trim();
    os = (Get-CimInstance Win32_OperatingSystem).Caption + ' ' + [Environment]::OSVersion.Version }
  commands = @('xmake f -c -y -p windows -a x64 -m release --policies=package.requires_lock --cxflags=/Brepro --ldflags=/Brepro --shflags=/Brepro', 'xmake build -r -y')
  work = $Work
  built_at = (Get-Date).ToUniversalTime().ToString('o')
}
Copy-Item $dll, (Join-Path $bin 'commonlibf4-template.pdb') $Out -Force
if (Test-Path "$tpl\xmake-requires.lock") { Copy-Item "$tpl\xmake-requires.lock" $Out -Force }
$info | ConvertTo-Json -Depth 6 | Set-Content (Join-Path $Out 'build-info.json') -Encoding utf8
Say 'done'
