{
  OSM tile images cache.
  Stores tile images for the map, could read/save them from/to local files but
  doesn't request them from network. See OSM.NetworkRequest unit
}
unit OSM.TileStorage;

interface

uses
  SysUtils, Classes, Graphics, PngImage,
  OSM.SlippyMapUtils;

const
  // Amount of bytes that a single tile bitmap occupies in memory.
  // Bitmap consumes ~4 byte per pixel. This constant could be used to
  // determine acceptable cache size knowing acceptable memory usage.
  TILE_BITMAP_SIZE = 4*TILE_IMAGE_WIDTH*TILE_IMAGE_HEIGHT;

type
  // List of cached tile bitmaps with fixed capacity organised as queue
  TTileBitmapCache = class
  strict private
  type
    TTileBitmapRec = record
      Tile: TTile;
      Bmp: TBitmap;
    end;
    PTileBitmapRec = ^TTileBitmapRec;
  strict private
    FCache: TList;
    class function NewItem(const Tile: TTile; Bmp: TBitmap): PTileBitmapRec;
    class procedure FreeItem(pItem: PTileBitmapRec);
  public
    constructor Create(Capacity: Integer);
    destructor Destroy; override;
    procedure Push(const Tile: TTile; Bmp: TBitmap);
    function Find(const Tile: TTile): TBitmap;
  end;

  TTileStorageOption = (
    tsoNoFileCache,        // disable all file cache operations
    tsoReadOnlyFileCache   // disable write file cache operations
  );
  TTileStorageOptions = set of TTileStorageOption;

  // Class that encapsulates memory and file cache of tile images
  TTileStorage = class
  strict private
    FBmpCache: TTileBitmapCache;
    FFileCacheBaseDir: string;
    FOptions: TTileStorageOptions;

    function GetFromFileCache(const Tile: TTile): TBitmap;
    procedure StoreInFileCache(const Tile: TTile; Ms: TMemoryStream);
  public
    constructor Create(CacheSize: Integer);
    destructor Destroy; override;
    function GetTile(const Tile: TTile): TBitmap;
    procedure StoreTile(const Tile: TTile; Ms: TMemoryStream);

    property Options: TTileStorageOptions read FOptions write FOptions;
    // Base path to images on disk: <FileCacheBaseDir> \ <Zoom> \ <TileX> \ <TileY>.png
    property FileCacheBaseDir: string read FFileCacheBaseDir write FFileCacheBaseDir;
  end;

implementation

{$REGION 'TTileBitmapCache'}

class function TTileBitmapCache.NewItem(const Tile: TTile; Bmp: TBitmap): PTileBitmapRec;
begin
  New(Result);
  Result.Tile := Tile;
  Result.Bmp := Bmp;
end;

class procedure TTileBitmapCache.FreeItem(pItem: PTileBitmapRec);
begin
  pItem.Bmp.Free;
  Dispose(pItem);
end;

constructor TTileBitmapCache.Create(Capacity: Integer);
begin
  FCache := TList.Create;
  FCache.Capacity := Capacity;
end;

destructor TTileBitmapCache.Destroy;
begin
  while FCache.Count > 0 do
  begin
    FreeItem(PTileBitmapRec(FCache[0]));
    FCache.Delete(0);
  end;
  FreeAndNil(FCache);
end;

procedure TTileBitmapCache.Push(const Tile: TTile; Bmp: TBitmap);
begin
  if FCache.Count = FCache.Capacity then
  begin
    FreeItem(PTileBitmapRec(FCache[0]));
    FCache.Delete(0);
  end;
  FCache.Add(NewItem(Tile, Bmp));
end;

function TTileBitmapCache.Find(const Tile: TTile): TBitmap;
var idx: Integer;
begin
  for idx := 0 to FCache.Count - 1 do
    if TilesEqual(Tile, PTileBitmapRec(FCache[idx]).Tile) then
      Exit(PTileBitmapRec(FCache[idx]).Bmp);
  Result := nil;
end;

{$ENDREGION}

{$REGION 'TTileStorage'}

// CacheSize - capacity of image cache.
constructor TTileStorage.Create(CacheSize: Integer);
begin
  FBmpCache := TTileBitmapCache.Create(CacheSize);
end;

destructor TTileStorage.Destroy;
begin
  FreeAndNil(FBmpCache);
end;

function TTileStorage.GetFromFileCache(const Tile: TTile): TBitmap;
var
  png: TPngImage;
  Path: string;
begin
  Result := nil;
  Path := FFileCacheBaseDir + TileToSlippyMapFileSubPath(Tile);
  if FileExists(Path) then
  begin
    png := TPngImage.Create;
    png.LoadFromFile(Path);
    Result := TBitmap.Create;
    Result.Assign(png);
    FreeAndNil(png);
  end;
end;

procedure TTileStorage.StoreInFileCache(const Tile: TTile; Ms: TMemoryStream);
var
  Path: string;
begin
  Path := FFileCacheBaseDir + TileToSlippyMapFileSubPath(Tile);
  ForceDirectories(ExtractFileDir(Path));
  Ms.SaveToFile(Path);
end;

// Try to get tile bitmap, return nil if not available locally.
// If bitmap has been loaded from file, store it in cache
function TTileStorage.GetTile(const Tile: TTile): TBitmap;
begin
  // try to load from memory cache
  Result := FBmpCache.Find(Tile);
  if Result <> nil then
    Exit;

  // try to load from disk cache
  if not (tsoNoFileCache in FOptions) then
  begin
    Result := GetFromFileCache(Tile);
    if Result <> nil then
      FBmpCache.Push(Tile, Result);
  end;
end;

// Add tile PNG to memory and file cache
procedure TTileStorage.StoreTile(const Tile: TTile; Ms: TMemoryStream);
var
  png: TPngImage;
  bmp: TBitmap;
  SavePos: Int64;
begin
  png := nil;
  try
    SavePos := Ms.Position;
    // Save to disk as PNG
    if ([tsoNoFileCache, tsoReadOnlyFileCache] * FOptions = []) then
      StoreInFileCache(Tile, Ms);
    Ms.Position := SavePos;
    // Convert to bitmap and store in memory cache
    png := TPngImage.Create;
    png.LoadFromStream(Ms);
    Ms.Position := SavePos;
    bmp := TBitmap.Create;
    bmp.Assign(png);
    FBmpCache.Push(Tile, Bmp);
  finally
    FreeAndNil(png);
  end;
end;

{$ENDREGION}

end.
