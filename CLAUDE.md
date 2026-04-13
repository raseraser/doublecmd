# Double Commander — Custom Build

## 專案概述
這是 [Double Commander](https://github.com/doublecmd/doublecmd) 的自訂分支（fork），由 rasercheng 維護。
語言：Free Pascal / Lazarus。

## Git 架構

```
upstream  → https://github.com/doublecmd/doublecmd   （官方，唯讀）
origin    → https://github.com/raseraser/doublecmd    （我的 fork）
```

### Branch 策略

| Branch | 用途 |
|--------|------|
| `master` | 追蹤官方 upstream/master，**不要直接 commit** |
| `feature/*` | 每個功能一個 branch，從 master 分出。可單獨 PR 回官方 |
| `custom/main` | **整合 branch**，merge 所有 feature + 私有修改。用來 build exe |

### 開發新功能的流程

```bash
# 1. 確保 master 是最新的
git fetch upstream && git checkout master && git merge upstream/master

# 2. 從 master 建立 feature branch
git checkout -b feature/my-new-feature master

# 3. 開發、commit（可多次 commit）

# 4. Push feature branch
git push -u origin feature/my-new-feature

# 5. 整合到 custom/main
git checkout custom/main
git merge feature/my-new-feature
git push origin custom/main

# 6. 在 custom/main 上 build exe
```

### 同步官方更新

```bash
git fetch upstream
git checkout master && git merge upstream/master && git push origin master
# 然後 rebase 或 merge 到各 feature branch 和 custom/main
```

## Build

### 前置條件
- **Lazarus 4.6** + **FPC 3.2.2**（安裝於 `C:\lazarus`）
- FPC 內建的 `windres` 有 bug，已改用預編譯的 `doublecmd.manifest.res`

### Build 指令

```bash
LAZBUILD="C:/lazarus/lazbuild.exe"
OPTS='--lazarusdir=C:/lazarus --compiler=C:/lazarus/fpc/3.2.2/bin/x86_64-win64/fpc.exe'

# 1. Components
for pkg in components/chsdet/chsdet.lpk \
  components/multithreadprocs/multithreadprocslaz.lpk \
  components/kascrypt/kascrypt.lpk \
  components/doublecmd/doublecmd_common.lpk \
  components/Image32/Image32.lpk \
  components/KASToolBar/kascomp.lpk \
  components/viewer/viewerpackage.lpk \
  components/gifview/gifview.lpk \
  components/synunihighlighter/synuni.lpk \
  components/virtualterminal/virtualterminal.lpk; do
  "$LAZBUILD" $OPTS "$pkg"
done

# 2. Plugins
for pkg in plugins/wcx/base64/src/base64wcx.lpi \
  plugins/wcx/deb/src/deb.lpi \
  plugins/wcx/rpm/src/rpm.lpi \
  plugins/wcx/sevenzip/src/sevenzipwcx.lpi \
  plugins/wcx/unrar/src/unrar.lpi \
  plugins/wcx/zip/src/zip.lpi \
  plugins/wdx/rpm_wdx/src/rpm_wdx.lpi \
  plugins/wdx/deb_wdx/src/deb_wdx.lpi \
  plugins/wdx/audioinfo/src/AudioInfo.lpi \
  plugins/wfx/ftp/src/ftp.lpi \
  plugins/wlx/wmp/src/wmp.lpi \
  plugins/wlx/preview/src/preview.lpi \
  plugins/wlx/richview/src/richview.lpi; do
  "$LAZBUILD" $OPTS "$pkg"
done

# 3. Main executable (release mode)
"$LAZBUILD" $OPTS src/doublecmd.lpi --bm=release
```

產出：`doublecmd.exe`（專案根目錄）

### Build 注意事項
- `src/doublecmd.lpr` 使用 `{$R doublecmd.manifest.res}` 而非 `.rc`（windres workaround）
- `packagefiles.xml` 是 Lazarus build cache，含本機路徑，不要 commit
- Components 和 Plugins 只需首次或依賴變更時重新 build

## 已有的自訂功能

### 1. Drives Root Navigation (`feature/drives-root-navigation`)
- 在磁碟根目錄（如 `E:\`）顯示 `..`，點擊可導航到「所有磁碟」列表
- 修改檔案：
  - `src/filesources/filesystem/ufilesystemfilesource.pas` — IsPathAtRoot / GetParentDir
  - `src/filesources/filesystem/ufilesystemlistoperation.pas` — drives listing via GetLogicalDrives
  - `src/fileviews/ufileview.pas` — ChangePathToChild / ChangePathToParent

### 2. Shift+Letter Drive Switch (`feature/shift-letter-drive-switch`)
- 按 Shift+E 直接切換到 E:\，Shift+C 切換到 C:\ 等（模擬 FreeCommander 行為）
- Quick Search 開啟時不攔截（仍可正常輸入大寫字母搜尋）
- 修改檔案：`src/fileviews/uorderedfileview.pas` — DoHandleKeyDown

### 3. About Custom Build Label (`feature/about-custom-build`)
- About 對話框顯示「Custom Build by rasercheng」藍色粗體標籤
- 修改檔案：`src/fAbout.pas`, `src/fAbout.lfm`
