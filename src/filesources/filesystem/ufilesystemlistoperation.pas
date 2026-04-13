unit uFileSystemListOperation;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils,
  uFileSourceListOperation,
  uFileSource
  ;

type

  { TFileSystemListOperation }

  TFileSystemListOperation = class(TFileSourceListOperation)
  private
    procedure FlatView(const APath: String);
  public
    constructor Create(aFileSource: IFileSource; aPath: String); override;
    procedure MainExecute; override;
  end;

implementation

uses
  DCOSUtils, uFile, uFindEx, uOSUtils, uFileSystemFileSource
{$IF DEFINED(MSWINDOWS)}
  , Windows, uDrive, uDriveWatcher, uMyWindows, uFileProperty
{$ENDIF}
  ;

procedure TFileSystemListOperation.FlatView(const APath: String);
var
  AFile: TFile;
  sr: TSearchRecEx;
begin
  try
    if FindFirstEx(APath + '*', 0, sr) = 0 then
    repeat
      CheckOperationState;

      if (sr.Name = '.') or (sr.Name = '..') then Continue;

      if FPS_ISDIR(sr.Attr) then
        FlatView(APath + sr.Name + DirectorySeparator)
      else begin
        AFile := TFileSystemFileSource.CreateFile(APath, @sr);
        FFiles.Add(AFile);
      end;
    until FindNextEx(sr) <> 0;
  finally
    FindCloseEx(sr);
  end;
end;

constructor TFileSystemListOperation.Create(aFileSource: IFileSource; aPath: String);
begin
  FFiles := TFiles.Create(aPath);
  inherited Create(aFileSource, aPath);
end;

procedure TFileSystemListOperation.MainExecute;
var
  AFile: TFile;
  sr: TSearchRecEx;
  IsRootPath, Found: Boolean;
{$IF DEFINED(MSWINDOWS)}
  DriveList: TDrivesList;
  Drive: PDrive;
  DriveIdx: Integer;
  DriveName: String;
  FreeSize, TotalSize: Int64;
{$ENDIF}
begin
  FFiles.Clear;

  if FFlatView then
  begin
    FlatView(Path);
    Exit;
  end;

{$IF DEFINED(MSWINDOWS)}
  // At drives root: list all available drives with full info
  if ExcludeTrailingPathDelimiter(Path) = '' then
  begin
    DriveList := TDriveWatcher.GetDrivesList;
    try
      for DriveIdx := 0 to DriveList.Count - 1 do
      begin
        Drive := DriveList[DriveIdx];
        AFile := TFileSystemFileSource.CreateFile(PathDelim);
        AFile.Attributes := faFolder;

        // Name: "E: VolLabel" or "H: Label (\\server\share)" for network
        DriveName := UpCase(Drive^.Path[1]) + ':';
        if Drive^.DriveLabel <> '' then
          DriveName := DriveName + ' ' + Drive^.DriveLabel;

        AFile.Name := DriveName;

        // Type: drive type description
        case Drive^.DriveType of
          dtHardDisk:     AFile.TypeProperty.Value := 'Local Disk';
          dtNetwork:      AFile.TypeProperty.Value := 'Network Drive';
          dtOptical:      AFile.TypeProperty.Value := 'CD/DVD Drive';
          dtFlash:        AFile.TypeProperty.Value := 'Flash Drive';
          dtFloppy:       AFile.TypeProperty.Value := 'Floppy Drive';
          dtRamDisk:      AFile.TypeProperty.Value := 'RAM Disk';
          dtRemovable,
          dtRemovableUsb: AFile.TypeProperty.Value := 'Removable Drive';
        end;

        // Size: total drive size; CompressedSize: free space
        if Drive^.IsMediaAvailable then
        begin
          if uOSUtils.GetDiskFreeSpace(Drive^.Path, FreeSize, TotalSize) then
          begin
            AFile.SizeProperty := TFileSizeProperty.Create(TotalSize);
            AFile.CompressedSizeProperty := TFileCompressedSizeProperty.Create(FreeSize);
          end;
        end;

        FFiles.Add(AFile);
      end;
    finally
      FreeAndNil(DriveList);
    end;
    Exit;
  end;
{$ENDIF}

  IsRootPath := FileSource.IsPathAtRoot(Path);

  Found := FindFirstEx(FFiles.Path + '*', 0, sr) = 0;
  try
    if not Found then
    begin
      { No files have been found. }

      if not IsRootPath then
      begin
        AFile := TFileSystemFileSource.CreateFile(Path);
        AFile.Name := '..';
        AFile.Attributes := faFolder;
        FFiles.Add(AFile);
      end;
    end
    else
    begin
      repeat
        CheckOperationState;

        if sr.Name='.' then Continue;

        // Don't include '..' in the root directory.
        if (sr.Name='..') and IsRootPath then
          Continue;

        AFile := TFileSystemFileSource.CreateFile(Path, @sr);
        FFiles.Add(AFile);
      until FindNextEx(sr)<>0;
    end;
  finally
    FindCloseEx(sr);
  end;
end;

end.

