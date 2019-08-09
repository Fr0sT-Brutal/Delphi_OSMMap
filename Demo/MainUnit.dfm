object MainForm: TMainForm
  Left = 16
  Top = 116
  Caption = 'Test of OSM map control'
  ClientHeight = 720
  ClientWidth = 1003
  Color = clBtnFace
  DoubleBuffered = True
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -14
  Font.Name = 'MS Sans Serif'
  Font.Style = []
  OldCreateOrder = False
  Position = poScreenCenter
  OnClose = FormClose
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  PixelsPerInch = 120
  TextHeight = 16
  object Splitter1: TSplitter
    Left = 767
    Top = 0
    Width = 8
    Height = 576
    Margins.Left = 4
    Margins.Top = 4
    Margins.Right = 4
    Margins.Bottom = 4
    Align = alRight
    Beveled = True
  end
  object Panel1: TPanel
    Left = 0
    Top = 0
    Width = 767
    Height = 576
    Margins.Left = 4
    Margins.Top = 4
    Margins.Right = 4
    Margins.Bottom = 4
    Align = alClient
    BevelOuter = bvNone
    TabOrder = 0
    object mMap: TScrollBox
      Left = 0
      Top = 0
      Width = 767
      Height = 576
      HorzScrollBar.Tracking = True
      VertScrollBar.Smooth = True
      VertScrollBar.Tracking = True
      Align = alClient
      AutoScroll = False
      DoubleBuffered = True
      DragCursor = crSizeAll
      ParentDoubleBuffered = False
      TabOrder = 0
      OnMouseMove = mMapMouseMove
    end
  end
  object Panel2: TPanel
    Left = 775
    Top = 0
    Width = 228
    Height = 576
    Margins.Left = 4
    Margins.Top = 4
    Margins.Right = 4
    Margins.Bottom = 4
    Align = alRight
    BevelOuter = bvNone
    TabOrder = 1
    object btnZoomIn: TSpeedButton
      Left = 100
      Top = 13
      Width = 51
      Height = 36
      Margins.Left = 4
      Margins.Top = 4
      Margins.Right = 4
      Margins.Bottom = 4
      Glyph.Data = {
        66010000424D6601000000000000760000002800000014000000140000000100
        040000000000F000000000000000000000001000000000000000000000000000
        8000008000000080800080000000800080008080000080808000C0C0C0000000
        FF0000FF000000FFFF00FF000000FF00FF00FFFF0000FFFFFF00EEEEEEEEEEEE
        EEEEEEEE0000EEEEEEEEEEEEEEEEEEEE0000EEEEEEEEEEEEEEEEEEEE0000EEEE
        EEE000000EEEEEEE0000EEEEEE0FFFFFF0EEEEEE0000EEEEE0FFFFFFFF0EEEEE
        0000EEEE0FFFFFFFFFF0EEEE0000EEE0FFFFFCCFFFF0EEEE0000EEE0FFFFFCCF
        FFFF0EEE0000EEE0FFFCCCCCCFFF0EEE0000EEE0FFFCCCCCCFFF0EEE0000EEE0
        FFFFFCCFFFFF0EEE0000EEE0FFFFFCCFFFF0EEEE0000EEEE0FFFFFFFFFF0EEEE
        0000EEEEE0FFFFFFFF0EEEEE0000EEEEEE0FFFFFF0EEEEEE0000EEEEEEE00000
        0EEEEEEE0000EEEEEEEEEEEEEEEEEEEE0000EEEEEEEEEEEEEEEEEEEE0000EEEE
        EEEEEEEEEEEEEEEE0000}
      OnClick = btnZoomInClick
    end
    object btnZoomOut: TSpeedButton
      Left = 164
      Top = 13
      Width = 51
      Height = 36
      Margins.Left = 4
      Margins.Top = 4
      Margins.Right = 4
      Margins.Bottom = 4
      Glyph.Data = {
        66010000424D6601000000000000760000002800000014000000140000000100
        040000000000F000000000000000000000001000000000000000000000000000
        8000008000000080800080000000800080008080000080808000C0C0C0000000
        FF0000FF000000FFFF00FF000000FF00FF00FFFF0000FFFFFF00EEEEEEEEEEEE
        EEEEEEEE0000EEEEEEEEEEEEEEEEEEEE0000EEEEEEEEEEEEEEEEEEEE0000EEEE
        EEE000000EEEEEEE0000EEEEEE0FFFFFF0EEEEEE0000EEEEE0FFFFFFFF0EEEEE
        0000EEEE0FFFFFFFFFF0EEEE0000EEE0FFFFFFFFFFF0EEEE0000EEE0FFFFFFFF
        FFFF0EEE0000EEE0FFFCCCCCCFFF0EEE0000EEE0FFFCCCCCCFFF0EEE0000EEE0
        FFFFFFFFFFFF0EEE0000EEE0FFFFFFFFFFF0EEEE0000EEEE0FFFFFFFFFF0EEEE
        0000EEEEE0FFFFFFFF0EEEEE0000EEEEEE0FFFFFF0EEEEEE0000EEEEEEE00000
        0EEEEEEE0000EEEEEEEEEEEEEEEEEEEE0000EEEEEEEEEEEEEEEEEEEE0000EEEE
        EEEEEEEEEEEEEEEE0000}
      OnClick = btnZoomOutClick
    end
    object Label1: TLabel
      Left = 16
      Top = 488
      Width = 41
      Height = 16
      Caption = 'Label1'
    end
    object Label2: TLabel
      Left = 16
      Top = 512
      Width = 41
      Height = 16
      Caption = 'Label2'
    end
    object lblZoom: TLabel
      Left = 7
      Top = 13
      Width = 74
      Height = 36
      AutoSize = False
      Font.Charset = RUSSIAN_CHARSET
      Font.Color = clWindowText
      Font.Height = -17
      Font.Name = 'Tahoma'
      Font.Style = [fsBold]
      ParentFont = False
      Layout = tlCenter
    end
    object Button1: TButton
      Left = 24
      Top = 256
      Width = 177
      Height = 33
      Caption = 'Save layer'
      TabOrder = 0
      OnClick = Button1Click
    end
  end
  object mLog: TMemo
    Left = 0
    Top = 576
    Width = 1003
    Height = 144
    Align = alBottom
    TabOrder = 2
  end
end
