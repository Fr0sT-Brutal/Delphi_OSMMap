{
  OSM tile images cache.
  Stores tile images for the map, could read/save them from/to local files but
  doesn't request them from network.
  @seealso(OSM.NetworkRequest)

  (c) Fr0sT-Brutal https://github.com/Fr0sT-Brutal/Delphi_OSMMap

  @author(Fr0sT-Brutal (https://github.com/Fr0sT-Brutal))
}
unit OSM.TileStorage;

{$IFDEF FPC}
  {$MODE Delphi}
{$ENDIF}

interface

uses
  {$IFDEF FPC}
  LazPNG,
  {$ENDIF}
  {$IFDEF DCC}
  PngImage,
  {$ENDIF}
  SysUtils, Classes, Graphics, Math,
  OSM.SlippyMapUtils;

const
  // Amount of bytes that a single tile bitmap occupies in memory.
  // Bitmap consumes ~4 bytes per pixel. This constant could be used to
  // determine acceptable cache size knowing acceptable memory usage.
  TILE_BITMAP_SIZE = 4*TILE_IMAGE_WIDTH*TILE_IMAGE_HEIGHT;

  // Default pattern of tile file path. Placeholders are for: Zoom, X, Y.
  // Define custom patt in TTileStorage.Create to modify tiles disposition
  // (f.ex., place them all in a single folder with names like `tile_%zoom%_%x%_%y%.png`)
  DefaultTilePathPatt = '%d'+PathDelim+'%d'+PathDelim+'%d.png';

  {$IFDEF MSWINDOWS} //~ Only Windows has GDI handles limit
  GDI_HANDLES_LIMIT = 3000; // Default overall limit is 10k per process, choose reasonable number below this limit
  GDI_PER_BMP = 1;          // Number of GDI handles per `TBitmap`
  GDI_PER_PNG = 3;          // Number of GDI handles per `TPngImage`
  {$ENDIF}

type
  // Abstract object cache class indexed by tiles with fixed capacity organised as queue.
  // For internal use only
  TTileObjectCache = class
  strict protected
    type
    TTileObjectRec = record
      Tile: TTile;
      Obj: TObject;
      Size: Cardinal;
    end;
    PTileObjectRec = ^TTileObjectRec;
  strict protected
    FCache: TList;
    FTotalSize: Cardinal;
    FSizeLimit: Cardinal;
    procedure Pop; inline;
    class function NewItem(const Tile: TTile; Obj: TObject; Size: Cardinal): PTileObjectRec; inline;
    class procedure FreeItem(pItem: PTileObjectRec); inline;
  public
    constructor Create(Capacity: Cardinal; SizeLimit: Cardinal);
    destructor Destroy; override;
    procedure Push(const Tile: TTile; Obj: TObject; Size: Cardinal);
    function Find(const Tile: TTile): TObject;
    procedure Clear;
  end;

  // Flags for TTileStorage
  TTileStorageOption = (
    tsoNoFileCache,        // disable all file cache operations
    tsoReadOnlyFileCache   // disable write file cache operations
  );
  TTileStorageOptions = set of TTileStorageOption;

  // Limits of tile cache in memory
  TCacheLimits = record
    BmpCount: Cardinal;     // Total count of bitmaps, memory occupied = `BmpCount*TILE_BITMAP_SIZE`
    PngTotalSize: Cardinal; // Total memory occupied by PNG cache
    PngCount: Cardinal;     // Total count of PNG objects
    StmSize: Cardinal;      // Total memory occupied by PNG stream cache
  end;

  // Class that encapsulates memory and file cache of tile images.
  // It operates 3-level in-memory cache: `TBitmap`'s, `TPngImage`'s and `TMemoryStream`'s.
  // According to benchmarks, different actions take following percents of time:
  //   - Load PNG from file to memory  - 30%
  //   - Read PNG from memory to image - 63% (!)
  //   - Convert PNG image to Bitmap   - 6%
  //   - Drawing Bitmap to another one - 0.4%
  //
  // Alas, each PNG occupies 3 GDI handles (on Windows) and each Bitmap takes
  // about 250 kB of memory and 1 GDI handle.
  // So we have to find balance between speed and resource consumption.
  TTileStorage = class
  strict private
    FBmpCache: TTileObjectCache; // cache for TBitmap's
    FPngCache: TTileObjectCache; // cache for TPngImage's
    FStmCache: TTileObjectCache; // cache for TMemoryStream's that contain TPngImage
    FFileCacheBaseDir: string;
    FTilePathPatt: string;
    FOptions: TTileStorageOptions;

    function GetTileFilePath(const Tile: TTile): string; inline;
    function GetFromFileCache(const Tile: TTile): TMemoryStream;
    procedure StoreInFileCache(const Tile: TTile; Ms: TMemoryStream);
    procedure SetFileCacheBaseDir(const Value: string);
  public
    // Simplified constructor.
    // Divides memory limit equally between bitmaps, PNGs and streams.
    // Limits number of bitmaps and PNGs by `GDI_HANDLES_LIMIT` (on Windows)
    //   @param CacheSize - overall size of all caches. Specific limits will be spread automatically.
    //   @param TilePathPatt - custom pattern of tile files' paths
    constructor Create(CacheSize: Cardinal; const TilePathPatt: string = DefaultTilePathPatt); overload;
    // Constructor with detailed cache limits.
    //   @param CacheLimits - record with detailed cache limits
    //   @param TilePathPatt - custom pattern of tile files' paths
    constructor Create(const CacheLimits: TCacheLimits; const TilePathPatt: string = DefaultTilePathPatt); overload;
    destructor Destroy; override;
    // Tries to get bitmap for `Tile`.
    // If bitmap has been loaded from file, stores it in cache
    //   @returns Bitmap or @nil if not available locally
    function GetTile(const Tile: TTile): TBitmap;
    // Adds memory stream `Ms`, PNG and bitmap produced from it to memory and file cache. @br
    // ! **TileStorage takes ownership on `Ms` so caller should forget about it ** !
    // @raises Exception if `Ms` doesn't contain valid PNG data
    //   @param Tile - tile to store
    //   @param Ms - memory stream containing PNG image. When function returns, this \
    //     reference gets nulled even if an exception has risen.
    procedure StoreTile(const Tile: TTile; var Ms: TMemoryStream);
    // Empty all caches
    procedure ClearCache;

    // Storage options
    property Options: TTileStorageOptions read FOptions write FOptions;
    // Base directory of file cache. All cached images are released on path change
    property FileCacheBaseDir: string read FFileCacheBaseDir write SetFileCacheBaseDir;
  end;

implementation

// For some reason png.Draw(Obj.Canvas) is 35% faster than Obj.Assign(png)...
function PNGtoBitmap(png: TPngImage): TBitmap;
begin
  Result := TBitmap.Create;
  {$IFDEF FPC}
  Result.Assign(png);  {}// TODO - maybe alternative option
  {$ENDIF}
  {$IFDEF DCC}
  Result.PixelFormat := pf32bit;
  Result.SetSize(png.Width, png.Height);
  png.Draw(Result.Canvas, Rect(0, 0, png.Width, png.Height));
  {$ENDIF}
end;

{$REGION 'TTileObjectCache'}

class function TTileObjectCache.NewItem(const Tile: TTile; Obj: TObject; Size: Cardinal): PTileObjectRec;
begin
  New(Result);
  Result.Tile := Tile;
  Result.Obj := Obj;
  Result.Size := Size;
end;

class procedure TTileObjectCache.FreeItem(pItem: PTileObjectRec);
begin
  pItem.Obj.Free;
  Dispose(pItem);
end;

constructor TTileObjectCache.Create(Capacity: Cardinal; SizeLimit: Cardinal);
begin
  FCache := TList.Create;
  FCache.Capacity := Capacity;
  FSizeLimit := SizeLimit;
end;

destructor TTileObjectCache.Destroy;
begin
  Clear;
  FreeAndNil(FCache);
end;

procedure TTileObjectCache.Pop;
var pItem: PTileObjectRec;
begin
  pItem := PTileObjectRec(FCache[0]);
  Dec(FTotalSize, pItem.Size);
  FreeItem(pItem);
  FCache.Delete(0);
end;

procedure TTileObjectCache.Push(const Tile: TTile; Obj: TObject; Size: Cardinal);
begin
  // Check limit by count
  if (FCache.Capacity > 0) and (FCache.Count = FCache.Capacity) then
    Pop
  else
  // Check limit by overall size
  while FTotalSize + Size > FSizeLimit do
    Pop;

  FCache.Add(NewItem(Tile, Obj, Size));
  Inc(FTotalSize, Size);
end;

function TTileObjectCache.Find(const Tile: TTile): TObject;
var idx: Integer;
begin
  for idx := 0 to FCache.Count - 1 do
    if TilesEqual(Tile, PTileObjectRec(FCache[idx]).Tile) then
      Exit(PTileObjectRec(FCache[idx]).Obj);
  Result := nil;
end;

procedure TTileObjectCache.Clear;
begin
  while FCache.Count > 0 do
    Pop;
end;

{$ENDREGION}

{$REGION 'TTileStorage'}

constructor TTileStorage.Create(const CacheLimits: TCacheLimits; const TilePathPatt: string);
begin
  FBmpCache := TTileObjectCache.Create(CacheLimits.BmpCount, CacheLimits.BmpCount*TILE_BITMAP_SIZE);
  FPngCache := TTileObjectCache.Create(CacheLimits.PngCount, CacheLimits.PngTotalSize);
  FStmCache := TTileObjectCache.Create(0, CacheLimits.StmSize);
  FTilePathPatt := TilePathPatt;
end;

constructor TTileStorage.Create(CacheSize: Cardinal; const TilePathPatt: string);
var
  CacheLimits: TCacheLimits;
begin
  CacheLimits := Default(TCacheLimits);
  CacheLimits.BmpCount := CacheSize div (3*TILE_BITMAP_SIZE);
  {$IFDEF MSWINDOWS} // Only Windows has GDI handles limit
  // Bitmaps could occupy only a proportional part of all GDI handles
  CacheLimits.BmpCount := Min(CacheLimits.BmpCount, (GDI_HANDLES_LIMIT div (GDI_PER_BMP + GDI_PER_PNG))*GDI_PER_BMP);
  {$ENDIF}
  CacheLimits.PngTotalSize := CacheSize div 3;
  {$IFDEF MSWINDOWS} // Only Windows has GDI handles limit
  // Leave all remaining GDI handles to PNGs
  CacheLimits.PngCount := (GDI_HANDLES_LIMIT - CacheLimits.BmpCount*GDI_PER_BMP) div GDI_PER_PNG;
  {$ENDIF}
  CacheLimits.StmSize := CacheSize - CacheLimits.BmpCount*TILE_BITMAP_SIZE - CacheLimits.PngTotalSize;
  Create(CacheLimits, TilePathPatt);
end;

destructor TTileStorage.Destroy;
begin
  FreeAndNil(FBmpCache);
  FreeAndNil(FPngCache);
  FreeAndNil(FStmCache);
end;

// Helper method to construst file path of given tile
function TTileStorage.GetTileFilePath(const Tile: TTile): string;
begin
  Result := IncludeTrailingPathDelimiter(FFileCacheBaseDir) + Format(FTilePathPatt, [Tile.Zoom, Tile.ParameterX, Tile.ParameterY]);
end;

// Load tile image from file
function TTileStorage.GetFromFileCache(const Tile: TTile): TMemoryStream;
var Path: string;
begin
  Result := nil;
  Path := GetTileFilePath(Tile);
  if FileExists(Path) then
  begin
    Result := TMemoryStream.Create;
    try
      Result.LoadFromFile(Path);
    except
      Result.Clear;
    end;
    // 0 size - empty file or read error, remove file and return nil anyway
    if Result.Size = 0 then
    begin
      DeleteFile(Path);
      FreeAndNil(Result);
    end;
  end;
end;

// Save tile image to file
procedure TTileStorage.StoreInFileCache(const Tile: TTile; Ms: TMemoryStream);
var Path: string;
begin
  Path := GetTileFilePath(Tile);
  ForceDirectories(ExtractFileDir(Path));
  Ms.SaveToFile(Path);
end;

// Change cache path, clear all cached images
procedure TTileStorage.SetFileCacheBaseDir(const Value: string);
begin
  if FFileCacheBaseDir = Value then Exit;
  FFileCacheBaseDir := Value;
  ClearCache;
end;

function TTileStorage.GetTile(const Tile: TTile): TBitmap;
var
  png: TPngImage;
  ms: TMemoryStream;
begin
  // try to load from memory caches
  // Bmp cache
  Result := FBmpCache.Find(Tile) as TBitmap;
  if Result <> nil then
    Exit;
  // PNG cache
  png := FPngCache.Find(Tile) as TPngImage;

  if png = nil then
  begin
    // Stream cache
    ms := FStmCache.Find(Tile) as TMemoryStream;
    if ms = nil then
      // try to load from disk cache
      if not (tsoNoFileCache in FOptions) then
      begin
        ms := GetFromFileCache(Tile);
        // no file - exit
        if ms = nil then
          Exit;
        // stream loaded - add to cache
        FStmCache.Push(Tile, ms, ms.Size);
      end
      else
        Exit;
    // convert stream to PNG and store in cache
    png := TPngImage.Create;
    ms.Position := 0;
    png.LoadFromStream(ms);
    FPngCache.Push(Tile, png, ms.Size);
  end;
  // convert PNG to and store in cache
  Result := PNGtoBitmap(png);
  FBmpCache.Push(Tile, Result, TILE_BITMAP_SIZE);
end;

procedure TTileStorage.StoreTile(const Tile: TTile; var Ms: TMemoryStream);
var png: TPngImage;
begin
  // First try to load stream to PNG image to check if it's correct
  Ms.Position := 0;
  png := TPngImage.Create;
  try
    png.LoadFromStream(Ms);
  except on E: Exception do
    begin
      FreeAndNil(png);
      FreeAndNil(Ms); // We took ownership on Ms so clean it up
      raise;
    end;
  end;

  // Save to disk as PNG
  Ms.Position := 0;
  if ([tsoNoFileCache, tsoReadOnlyFileCache] * FOptions = []) then
    StoreInFileCache(Tile, Ms);
  // Store in stream cache
  FStmCache.Push(Tile, Ms, Ms.Size);
  // Store in PNG cache
  FPngCache.Push(Tile, png, Ms.Size);
  // Store in bitmap cache
  FBmpCache.Push(Tile, PNGtoBitmap(png), TILE_BITMAP_SIZE);
  Ms := nil; // Nullify the reference
end;

procedure TTileStorage.ClearCache;
begin
  FBmpCache.Clear;
  FPngCache.Clear;
  FStmCache.Clear;
end;

{$ENDREGION}

end.
