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
- 顯示磁碟資訊：標籤、類型、總容量、剩餘空間（使用 `TDriveWatcher.GetDrivesList`）
- 修改檔案：
  - `src/filesources/filesystem/ufilesystemfilesource.pas` — `IsPathAtRoot` / `GetParentDir` / `SetCurrentWorkingDirectory`
  - `src/filesources/filesystem/ufilesystemlistoperation.pas` — drives listing + 磁碟根目錄顯式加入 `..`
  - `src/fileviews/ufileview.pas` — `ChangePathToChild` / `ChangePathToParent`
- **踩過的坑**：Windows `FindFirstEx('E:\*')` 在磁碟根目錄**不會**回傳 `..` 條目（跟一般目錄行為不同）。需要在 list operation 中手動加入。

### 2. Shift+Letter Drive Switch (`feature/shift-letter-drive-switch`)
- 按 Shift+E 直接切換到 `E:\`，Shift+C 切換到 `C:\` 等（模擬 FreeCommander 行為）
- Quick Search 開啟時不攔截（仍可正常輸入大寫字母搜尋）
- 修改檔案：`src/fileviews/uorderedfileview.pas` — `DoHandleKeyDown`
- **踩過的坑**：條件檢查不能用 `Shift * KeyModifiersShortcutNoText = []`（某些情況會造成判斷失效），改用簡單的 `(ssShift in Shift) and (Shift * [ssAlt, ssCtrl] = [])`。

### 3. Custom Tab Style (`feature/tab-style`)
- Tab 有明確邊框分隔、active tab 白底粗體 + 藍色頂線、增加 padding
- 僅 Windows 平台生效（owner-draw via `PaintWindow`）
- 修改檔案：`src/ufileviewnotebook.pas` — `PaintWindow` / `DoChange` / constructor
- **踩過的坑**：在 `PaintWindow` 裡繪製文字**必須**用 `DrawTextW + PWideChar(UTF8Decode(...))`，不能用 `DrawText + PChar`。FPC 的 `PChar = PAnsiChar`，`DrawText` 對應 `DrawTextA`，CJK/Unicode 字會顯示亂碼。

### 4. About Custom Build Label (`feature/about-custom-build`)
- About 對話框顯示「Custom Build by rasercheng」藍色粗體標籤
- 修改檔案：`src/fAbout.pas`, `src/fAbout.lfm`

### 5. Column Auto-Fit (`feature/column-auto-fit`)
- 在欄位分隔線上 double-click，左邊欄位自動調整寬度至符合最長檔名
- 修改檔案：`src/fileviews/ucolumnsfileview.pas` — `TDrawGridEx.DblClick` + `AutoAdjustColumn`
- **踩過的坑**：LCL 內建的 `goDblClickAutoSize` 選項在 `FixedCols=0` 時**完全不會觸發**。原因是 header 區的 click 進入 `gzFixedRows` zone（不是 `gzFixedCols`），MouseUp 走 `gsRowMoving` 分支呼叫 `RestoreCursor` 把 `FCursorState` 重設為 `gcsDefault`，DblClick 檢查 `FCursorState=gcsColWidthChanging` 就失敗。**必須自己 override `DblClick`**，用 `FMouseDownX/Y` + `OffsetToColRow`/`ColRowToOffset` 判斷是否在 header 的欄位分隔線附近（tolerance 4px）。

### 6. Thumbnail Zoom with Ctrl+Wheel (`feature/thumb-zoom`)
- 縮圖模式下 Ctrl+滾輪放大/縮小縮圖（每次 16px，範圍 32-512px）
- 沒按 Ctrl 時滾輪照常捲動
- 修改檔案：`src/fileviews/uthumbfileview.pas` — `TThumbDrawGrid.DoMouseWheelDown/Up`
- 實作方式：修改 `gThumbSize` 全域變數 → 呼叫 `UpdateView` 重新計算 cell 大小 → `FThumbView.Reload` 刷新縮圖
- 參考 `TBriefDrawGrid` 的 `gZoomWithCtrlWheel` 實作（但縮圖改尺寸而非字型）

### 7. Paste-Path Navigation (`feature/goto-paste-path`)
- 路徑編輯框（`cm_EditPath`）+ 新 hotkey `Alt+Shift+D`（`cm_PastePathAndGo`）支援：
  - **git-bash 路徑格式**：`/e/github/foo` → 自動轉成 `E:\github\foo`
  - **單/雙引號自動 strip**：`"E:\foo bar"` → `E:\foo bar`
  - **檔案 → parent 目錄 + select 該檔案**（既有行為，整合進新流程）
  - **目錄 → 進入後游標落在第一個非 `..` 項目**
- 修改檔案：
  - `src/udcutils.pas` — `NormalizePastedPath()` helper（去引號 + git-bash 轉換）
  - `src/filesources/ufilesourceutil.pas` — `NavigatePastedPath()` 共用導航函式
  - `src/fileviews/ufileview.pas` — 新增 `RequestActiveFirstNonParent: Boolean` public property
  - `src/fileviews/uorderedfileview.pas` — `ConsumeFirstNonParentRequest()` 在 load 完成後選第一個非 `..`
  - `src/fileviews/ucolumnsfileview.pas` + `ufileviewwithgrid.pas` — `DisplayFileListChanged` 內 hook flag
  - `src/fileviews/ufileviewheader.pas` — `onKeyRETURN` 改呼叫 `NavigatePastedPath`
  - `src/umaincommands.pas` — `cm_PastePathAndGo` 從 clipboard 讀路徑
  - `src/uglobs.pas` — 預設 hotkey `Alt+Shift+D`
- **踩過的坑**：
  1. `RequestActiveFirstNonParent` 一開始放在 `protected` section，從 `ufilesourceutil.pas` (非 descendant) 寫不進去 → 必須移到 `public`。FPC 的 `protected` 同 Delphi：descendant only，不是 same-unit。
  2. **Race condition**：`ClearFiles` 在新目錄載入前會 fire `fvnDisplayFileListChanged` 但 FFiles 為空。如果這時消費 flag → flag 被吃掉但沒選到檔，等真正 load 完成時 flag 已 clear。修法：`ConsumeFirstNonParentRequest` 看到 `FFiles.Count = 0` 直接 return False，**不**清 flag，讓下次 display update（檔載入後）才消費。

---

## 開發 Tips & 踩過的坑總結

### Free Pascal / LCL 通用陷阱
- **`PChar` 在 `{$H+}` 模式下 = `PAnsiChar`**。呼叫 Win32 API 時若要處理 Unicode/CJK 字串，**一定要**用 `PWideChar(UTF8Decode(...))` + API 的 `W` 版本（`DrawTextW`、`SetTextColorW` 等）。`Windows.SetTextColor` 是 overload，需要完整前綴才能避免被 LCL 版本遮蔽。
- **`TCustomGrid` 的 `goDblClickAutoSize`** 在 `FixedCols=0` 時無效（見 Column Auto-Fit 的坑）。需要自己 override `DblClick`。
- **`AutoAdjustColumn` 在 `TCustomDrawGrid` 是空實作**（只有 `TCustomStringGrid` 有預設實作）。DrawGrid 子類需自己 override 測量內容寬度。

### TFileView key event 流程
Key event 依序經過：
1. `fMain.FormKeyDown` (KeyPreview=True) — 處理 VK_BACK/ESCAPE/RETURN/SPACE/TAB + `CheckCommandLine`
2. `TFileViewWithMainCtrl.MainControlKeyDown` — 呼叫 `DoHandleKeyDown`
3. `TColumnsFileView.DoHandleKeyDown` → `TFileViewWithGrid.DoHandleKeyDown` → `TOrderedFileView.DoHandleKeyDown` → `TFileView.DoHandleKeyDown`
4. `TOrderedFileView.DoHandleKeyDown` 裡會先呼叫 `quickSearch.CheckSearchOrFilter(Key)`，**自訂的 key handler 要放在這個呼叫之前**

### 驅動程式資訊查詢
- `TDriveWatcher.GetDrivesList` 回傳 `TDrivesList`，每個 `PDrive` 有 `Path` (含 `:\`)、`DriveLabel`、`DriveType`、`IsMediaAvailable`
- `uOSUtils.GetDiskFreeSpace(Path, out Free, out Total)` 取得容量（注意要加 `uOSUtils.` 前綴避免和 Windows API 同名函式衝突）

### Branch 工作流
- 新 session 修改舊功能時，**記得切換到對應的 feature branch** 做修改，而不是直接在 `custom/main` 上改。然後再 merge 回 `custom/main`。
- 檢查 feature 對應的 branch：看 CLAUDE.md 裡每個功能後面的 `feature/xxx`。

### Debug 建議
- 遇到「功能沒觸發」的狀況，**優先查 key/event 傳遞鏈**（哪個 handler 先攔截、哪個條件判斷失效），不要假設問題在自訂邏輯裡。
- `Shift * KeyModifiersShortcutNoText` 這類位元運算條件太「嚴」，遇到奇怪組合時改用最簡單的 `in Shift` / `* [ssAlt, ssCtrl] = []` 的組合。
