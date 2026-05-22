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

**一律使用 `scripts/build-custom.sh`，不要手動敲 lazbuild。**

```bash
scripts/build-custom.sh              # build 主程式 + 部署到 E:\tools\doublecmd\
scripts/build-custom.sh --full       # 同時重 build components/plugins（首次 / 依賴變更時）
scripts/build-custom.sh --no-deploy  # 只 build 不部署
```

Script 強制 `HEAD == custom/main` 才能 build，避免在 feature branch 上 build 出「只有單一 feature 的 exe」（曾踩過：在 `feature/goto-paste-path` 上 build 後 deploy，使用者以為 tab-style / shift-letter 等 feature「失效」，其實是 exe 本來就沒包含）。

可用 env 覆蓋：`LAZBUILD` / `FPC` / `LAZDIR` / `DEPLOY`。

產出：`doublecmd.exe`（專案根目錄）+ 自動 copy 到 `$DEPLOY`（預設 `E:\tools\doublecmd\doublecmd.exe`）。如果目標 exe 正在執行，copy 會失敗並印 PowerShell kill 指令給使用者自己跑（不主動 kill）。

### Build 注意事項
- `src/doublecmd.lpr` 使用 `{$R doublecmd.manifest.res}` 而非 `.rc`（windres workaround）
- `packagefiles.xml` 是 Lazarus build cache，含本機路徑，不要 commit
- Components 和 Plugins 只需首次或依賴變更時重新 build（用 `--full`）
- `scripts/build-custom.sh` 只在 `custom/main` 維護，不會合進 feature branch / 上游

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
  - **`~` 家目錄展開**：`~/.claude/data` → `C:\Users\<user>\.claude\data`（Windows 取 `USERPROFILE`，*nix 取 `$HOME`）。bare `~` 也能用；`~user/foo` 不展開
  - **單/雙引號自動 strip**：`"E:\foo bar"` → `E:\foo bar`
  - **行折換 (line wrap) 合併**：原 paste 內含 `\n` + 後續空白縮排會被收回單行；wrap 處剛好碰到 `/` 或 `\` 時靜默 join，否則插入一個空格保留可能存在的真實檔名空格
  - **多餘連續空格自動修復**：含 2+ 連續空格的路徑（terminal wrap padding 或排版誤差），逐 span 嘗試 collapse 0 / 1 空格組合，**只有當變體真實存在 (mbFileExists / mbDirectoryExists)** 才採用；不存在則保持原樣。例：`C:\Users\foo\.     claude\data` → `C:\Users\foo\.claude\data`
  - **檔案 → parent 目錄 + select 該檔案**（既有行為，整合進新流程）
  - **目錄 → 進入後游標落在第一個非 `..` 項目**
- 修改檔案：
  - `src/udcutils.pas` — `NormalizePastedPath()` helper（去引號 + git-bash 轉換 + line wrap 合併 + `~` 展開）；`RepairWhitespacePath()` helper（連續空格 collapse + 存在性驗證）
  - `src/filesources/ufilesourceutil.pas` — `NavigatePastedPath()` 共用導航函式（local path 場景才呼叫 `RepairWhitespacePath`，避免動到 VFS 路徑）
  - `src/fileviews/ufileview.pas` — 新增 `RequestActiveFirstNonParent: Boolean` public property
  - `src/fileviews/uorderedfileview.pas` — `ConsumeFirstNonParentRequest()` 在 load 完成後選第一個非 `..`
  - `src/fileviews/ucolumnsfileview.pas` + `ufileviewwithgrid.pas` — `DisplayFileListChanged` 內 hook flag
  - `src/fileviews/ufileviewheader.pas` — `onKeyRETURN` 改呼叫 `NavigatePastedPath`
  - `src/umaincommands.pas` — `cm_PastePathAndGo` 從 clipboard 讀路徑
  - `src/uglobs.pas` — 預設 hotkey `Alt+Shift+D`
- **踩過的坑**：
  1. `RequestActiveFirstNonParent` 一開始放在 `protected` section，從 `ufilesourceutil.pas` (非 descendant) 寫不進去 → 必須移到 `public`。FPC 的 `protected` 同 Delphi：descendant only，不是 same-unit。
  2. **Race condition**：`ClearFiles` 在新目錄載入前會 fire `fvnDisplayFileListChanged` 但 FFiles 為空。如果這時消費 flag → flag 被吃掉但沒選到檔，等真正 load 完成時 flag 已 clear。修法：`ConsumeFirstNonParentRequest` 看到 `FFiles.Count = 0` 直接 return False，**不**清 flag，讓下次 display update（檔載入後）才消費。
  3. **新 cm_ command 三個地方都要動**（看 `umaincommands.pas` 開頭的 RECIPE 註解）：
     - `umaincommands.pas` — 在 `published` 區宣告 + 實作 procedure
     - `fmain.lfm` — 加 `actXxxName: TAction` entry（同 cm_ 名），category + tag 跟相鄰命令一致
     - `fmain.pas` — 在 TfrmMain 的 published fields 加 `actXxxName: TAction;`
     - `uglobs.pas` — 加 `AddIfNotExists` 預設 hotkey
     少了 fmain action → 按 hotkey 系統會 **「ding」** 但無作用（dispatcher 找不到 action）。
  4. **bump `hkVersion`**（`uglobs.pas`）才會讓 `LoadDefaultHotkeyBindings` 重跑進新預設 binding。判斷式是 `HotMan.Version < hkVersion`，沒 bump → 既有 install 的 `shortcuts.scf` 不會吃到新 hotkey。

### 8. Mkdir Full-Path Support (`feature/mkdir-full-path`)
- F7 (mkdir, `cm_MakeDir`) dialog 輸入支援完整路徑 + 自動建立中間缺失目錄（mkdir -p 行為）。輸入 normalize：
  - **單/雙引號 strip**：`"E:\foo\bar"` → `E:\foo\bar`
  - **git-bash 格式**：`/c/Users/foo/lora/raw` → `C:\Users\foo\lora\raw`
  - **`~` 家目錄展開**：`~/projects/foo/bar` → `C:\Users\<user>\projects\foo\bar`
  - **forward slash → backslash**（Windows）：`E:/foo/bar/raw/` → `E:\foo\bar\raw\`
  - **自動建多層**：絕對或相對皆可，中間任意層數不存在都會被一次建起
  - **建完自動 navigate 進新目錄**：若新目錄的 parent ≠ 目前 panel path（跨層或絕對路徑指他處），自動把 panel 切到新目錄。單層直接子目錄維持上游 `SetActiveFile`（cursor 移過去）行為
- 修改檔案：
  - `src/udcutils.pas` — `NormalizeMakeDirPath()` helper
  - `src/umaincommands.pas` — `cm_MakeDir` 在 `ShowMkDir` 回傳後、`CreateCreateDirectoryOperation` 之前呼叫 normalize；尾段判斷新目錄是否跨層，決定 `SetActiveFile` 或 `CurrentPath :=`
- **踩過的坑 / 根因分析**：
  1. **`ForceDirectoriesUAC` 對 forward slash 是 silent failure**：它 loop 找 `PathDelim`（Windows = `\`）切 segment 建立每層。對 `E:/foo/bar/` 看不到任何 `\` → loop 完整跑完 → return `Result := True` 但啥都沒建。**必須先把 `/` 換 `\` 才能 work**。
  2. **`ForceDirectoriesUAC` 對 `E:\` 起頭其實 OK**：Windows API `GetFileAttributesW('E:')` 回 0x10 (FILE_ATTRIBUTE_DIRECTORY) — 被視為 E 槽 current dir 存在，所以 loop 在 `E:` 跳過，從 `E:\foo` 開始建。原本懷疑會在 drive letter 死掉是錯的。
  3. **`fmkdir.pas` dialog 只做 `TrimPath`**：只 trim 每段尾端的 whitespace/`.`（Windows），不做格式 normalize、不轉 `/`、不展開 `~`。所有 input normalize 都要在 cm_MakeDir 接收 sPath 後自己做。
  4. **`ShowMkDir` dialog 預設值是 active file 的 NameNoExt**：如果游標在檔案上按 F7，預設帶該檔名（不是空白）。
  5. **上游 `SetActiveFile(name)` 只在 current listing 找**：mkdir 完叫它 select 跨層的新目錄一定 silent miss（new dir 不在 panel 顯示中），體感像「啥都沒發生」。要嘛 navigate 進去，要嘛先把 panel 切到 parent 再 SetActiveFile。我們選前者。
  6. **GetPathType 有兩個版本**：`DCStrUtils.GetPathType` (free function) 認 Windows drive letter `E:` 為 absolute；`TFileSource.GetPathType` (default method) 只認 leading `/`。`TFileSystemFileSource.GetPathType` override 回去呼叫前者。寫 logic 時用前者比較不會被 base class 騙到。

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
