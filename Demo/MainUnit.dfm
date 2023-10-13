object MainForm: TMainForm
  Left = 16
  Top = 116
  Caption = 'Test of OSM map control'
  ClientHeight = 855
  ClientWidth = 975
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
    Left = 739
    Top = 0
    Width = 8
    Height = 711
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
    Width = 739
    Height = 711
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
      Width = 739
      Height = 711
      Align = alClient
      TabOrder = 0
      OnMouseDown = mMapMouseDown
      OnMouseMove = mMapMouseMove
    end
  end
  object Panel2: TPanel
    Left = 747
    Top = 0
    Width = 228
    Height = 711
    Margins.Left = 4
    Margins.Top = 4
    Margins.Right = 4
    Margins.Bottom = 4
    Align = alRight
    BevelOuter = bvNone
    DoubleBuffered = True
    FullRepaint = False
    ParentDoubleBuffered = False
    TabOrder = 1
    object chbCacheUseFiles: TCheckBox
      Left = 16
      Top = 246
      Width = 145
      Height = 17
      Caption = 'Use file cache'
      Checked = True
      State = cbChecked
      TabOrder = 1
      OnClick = chbCacheUseFilesClick
    end
    object chbCacheSaveFiles: TCheckBox
      Left = 16
      Top = 270
      Width = 145
      Height = 17
      Caption = 'Save files to cache'
      Checked = True
      State = cbChecked
      TabOrder = 2
      OnClick = chbCacheSaveFilesClick
    end
    object GridPanel1: TGridPanel
      Left = 0
      Top = 0
      Width = 228
      Height = 711
      Align = alClient
      ColumnCollection = <
        item
          Value = 100.000000000000000000
        end>
      ControlCollection = <
        item
          Column = 0
          Control = Panel3
          Row = 0
        end
        item
          Column = 0
          Control = Panel4
          Row = 1
        end
        item
          Column = 0
          Control = Panel5
          Row = 2
        end
        item
          Column = 0
          Control = Panel6
          Row = 3
        end
        item
          Column = 0
          Control = Panel7
          Row = 4
        end
        item
          Column = 0
          Control = Panel8
          Row = 5
        end>
      RowCollection = <
        item
          SizeStyle = ssAbsolute
          Value = 50.000000000000000000
        end
        item
          SizeStyle = ssAbsolute
          Value = 50.000000000000000000
        end
        item
          SizeStyle = ssAbsolute
          Value = 160.000000000000000000
        end
        item
          SizeStyle = ssAbsolute
          Value = 200.000000000000000000
        end
        item
          SizeStyle = ssAbsolute
          Value = 140.000000000000000000
        end
        item
          SizeStyle = ssAbsolute
          Value = 50.000000000000000000
        end
        item
          SizeStyle = ssAuto
        end>
      TabOrder = 0
      object Panel3: TPanel
        Left = 1
        Top = 1
        Width = 226
        Height = 50
        Align = alClient
        BevelOuter = bvNone
        TabOrder = 0
        object lblZoom: TLabel
          AlignWithMargins = True
          Left = 3
          Top = 3
          Width = 108
          Height = 47
          Align = alClient
          Alignment = taCenter
          AutoSize = False
          Font.Charset = RUSSIAN_CHARSET
          Font.Color = clWindowText
          Font.Height = -17
          Font.Name = 'Tahoma'
          Font.Style = [fsBold]
          ParentFont = False
          Layout = tlCenter
          WordWrap = True
        end
        object btnZoomIn: TSpeedButton
          AlignWithMargins = True
          Left = 173
          Top = 3
          Width = 50
          Height = 44
          Align = alRight
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
          AlignWithMargins = True
          Left = 117
          Top = 3
          Width = 50
          Height = 44
          Align = alRight
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
      end
      object Panel4: TPanel
        Left = 1
        Top = 51
        Width = 226
        Height = 50
        Align = alClient
        BevelOuter = bvNone
        TabOrder = 1
        object Label3: TLabel
          AlignWithMargins = True
          Left = 3
          Top = 3
          Width = 108
          Height = 47
          Align = alClient
          Alignment = taCenter
          Caption = 'Mouse mode'
          Layout = tlCenter
          WordWrap = True
        end
        object btnMouseModePan: TSpeedButton
          AlignWithMargins = True
          Left = 173
          Top = 3
          Width = 50
          Height = 44
          Align = alRight
          GroupIndex = 1
          Down = True
          Glyph.Data = {
            36030000424D3603000000000000360000002800000010000000100000000100
            1800000000000003000000000000000000000000000000000000C0C0C0C0C0C0
            C0C0C0C0C0C09EAFC696C1E28FC3E88FC3E88FC3E88CC1E76EACDD7A9DCEC0C0
            C0C0C0C0C0C0C0C0C0C0C0C0C0C0C0C0C0C0C0C0C0C06D96D0B5E3F1BFEDF4BF
            EDF4BFEDF4B1DDEC9CCBE3558ED9AFB8C3C0C0C0C0C0C0C0C0C0C0C0C0C0C0C0
            C0C0C08AA5CA68A0DFB9E8F1B7E4F0B1DBECAAD3E8A2C9E3A2C9E373A5DD86A3
            CBC0C0C0C0C0C0C0C0C0C0C0C0C0C0C0BDBFC14B87D8B2DFF2BEEDF3B5E5F0AC
            D9EAA5CDE5A2C9E3A2C9E396C0E14985D7BFBFC0C0C0C0C0C0C0C0C0C0C0C0C0
            9BAEC76FA4E1C8F0F7C2EFF5BEECF4B7E7F1ADDCEBA6CFE6A2C9E3A2C9E3679C
            DB86A3CBC0C0C0C0C0C0C0C0C0C0C0C06A95D1AAD3EFCEF1F8C8F0F6C2EEF5BF
            ECF4B9E9F2AFDEECA7D1E7A2C9E398C2E24B86D7BCBEC1C0C0C0C0C0C083A2CC
            77A8E3D6F3FACCEDF7C6EBF7C9F0F7C4EEF5BFEDF4BCEBF3B2E1EEA9D4E8A3CA
            E36298DB9DAEC7C0C0C08CA6CA5E94DCD2EAF9DCF3FBA6CCEED6F3FAD0F1F9CB
            F1F8C6EFF6C2EEF5BFECF4B5E4EFAAD6E973A5DD88A4CBC0C0C04783D7CFE4F8
            E5F5FDCFE6F88AB5E8DCF4FCBEDFF5D1F2F9BEE5F5BFE8F5C4EEF67CB2E3B6E5
            F083B6E2799DCEC0C0C0407FD6BFDAF5CEE2F75D93DC99BFEBE0F4FC96BFEAD6
            F2FAC1E5F591C0E9C7F0F678B0E49DDEF181C2E86E97D0C0C0C094AAC86391D2
            5D8FD35B90D28DBEEDDEF4FD68A3E3D4F2FBB3DBF360A5E4C7EFF87CBFEA82CC
            ED97D2EE6191D2C0C0C0C0C0C0C0C0C0C0C0C03E83D4B6D8F4DFF1FD4991DED6
            F1FCB3D9F368AAE6CDF1F998CDED87C6ECA2D4EE6492D2C0C0C0C0C0C0C0C0C0
            BEC0C2377ED5DEF0FCC5DDF66AA2E3E0F4FDC9E3F783B7E8D6F4FBA5CCEE649A
            DE5992DB96ABC8C0C0C0C0C0C0C0C0C0C0C0C07FA0CC7FABE46699DE83AEE6EA
            F6FEB8D4F287B3E7D7EEFB73A5E29DAEC7B0B8C3C0C0C0C0C0C0C0C0C0C0C0C0
            C0C0C0C0C0C097ACC8A9B5C4799DCE7BA8E35B91DC80A0CC4F88D680A0CCC0C0
            C0C0C0C0C0C0C0C0C0C0C0C0C0C0C0C0C0C0C0C0C0C0C0C0C0C0C0C0C0C0C09A
            ADC7B2B9C3C0C0C0C0C0C0C0C0C0C0C0C0C0C0C0C0C0C0C0C0C0}
          OnClick = btnMouseModePanClick
        end
        object btnMouseModeSel: TSpeedButton
          AlignWithMargins = True
          Left = 117
          Top = 3
          Width = 50
          Height = 44
          Align = alRight
          GroupIndex = 1
          Glyph.Data = {
            36030000424D3603000000000000360000002800000010000000100000000100
            1800000000000003000000000000000000000000000000000000D59281EA6442
            D08F7EACACACACACACACACACACACACACACACACACACACACACACACACACACACACAC
            ACD08F7EEA6442D59281E15F3DF0C8BAE15F3DE15F3DE15F3DE15F3DE15F3DE1
            5F3DE15F3DE15F3DE15F3DE15F3DE15F3DE15F3DF0C8BAE15F3DCC8D7CD65937
            DD9B84DFD2C4DFD2C4DFD2C4DFD2C4DFD2C4DFD2C4DFD2C4DFD2C4DFD2C4DFD2
            C4DD9B84D65937CC8D7CC0C0C0CB5331DFD2C4D7C7B7D7C7B7D7C7B7D7C7B7D7
            C7B7D7C7B7D7C7B7D7C7B7D7C7B7D7C7B7DFD2C4CB5331C0C0C0C0C0C0BF4D2B
            DED1C3D7C6B6D7C6B6D7C6B6D7C6B6D7C6B6D7C6B6D7C6B6D7C6B6D7C6B6D7C6
            B6DED1C3BF4D2BC0C0C0C0C0C0B54725E1D5C9D5C5B5D5C5B5D5C5B5D5C5B5D5
            C5B5D5C5B5D5C5B5D5C5B5D5C5B5D5C5B5DDD0C2B54725C0C0C0C0C0C0AE4523
            E5DBD0DACBBDD5C5B5D5C5B5D5C5B5D5C5B5D5C5B5D5C5B5D5C5B5D5C5B5D5C5
            B5DDCFC2AE4523C0C0C0C0C0C0AB4422E6DDD3E0D4C9DBCEC1D5C6B6D4C4B5D4
            C5B5D4C4B5D4C5B5D4C4B5D4C4B5D4C4B5DDCFC2AB4422C0C0C0C0C0C0AC4725
            E8DFD7E2D7CCE2D7CCE0D4C9D8CBBDD4C5B5D3C4B5D3C4B5D3C4B5D3C4B5D3C4
            B5DCCFC2AC4725C0C0C0C0C0C0B14E2CE9E1D9E3D9D0E3D9D0E3D9D0E3D9D0E1
            D7CCDCCFC3D8CBBDD5C7B9D4C5B7D4C5B7DDD2C5B14E2CC0C0C0C0C0C0BB5735
            EAE3DDE4DCD4E4DCD4E4DCD4E4DCD4E4DCD4E4DCD4E4DCD4E4DCD4E4DCD4E4DC
            D4EAE3DDBB5735C0C0C0C0C0C0C5613FEBE5DEE6DED6E6DED6E6DED6E6DED6E6
            DED6E6DED6E6DED6E6DED6E6DED6E6DED6EBE5DEC5613FC0C0C0C0C0C0D16D4B
            ECE6E0E7E0D8E7E0D8E7E0D8E7E0D8E7E0D8E7E0D8E7E0D8E7E0D8E7E0D8E7E0
            D8ECE6E0D16D4BC0C0C0CF9C8BDC7755E6B3A0ECE7E0ECE7E0ECE7E0ECE7E0EC
            E7E0ECE7E0ECE7E0ECE7E0ECE7E0ECE7E0E6B3A0DC7755CF9C8BE6805EF0C8BA
            E6805EE6805EE6805EE6805EE6805EE6805EE6805EE6805EE6805EE6805EE680
            5EE6805EF0C8BAE6805ED6A392ED8765D6A392C0C0C0C0C0C0C0C0C0C0C0C0C0
            C0C0C0C0C0C0C0C0C0C0C0C0C0C0C0C0C0D6A392ED8765D6A392}
          OnClick = btnMouseModeSelClick
        end
      end
      object Panel5: TPanel
        Left = 1
        Top = 101
        Width = 226
        Height = 160
        Align = alClient
        BevelOuter = bvNone
        TabOrder = 2
        object rgProxy: TRadioGroup
          AlignWithMargins = True
          Left = 3
          Top = 3
          Width = 220
          Height = 96
          Align = alTop
          Caption = ' Proxy '
          ItemIndex = 1
          Items.Strings = (
            'No proxy'
            'System default'
            'Custom')
          TabOrder = 0
        end
        object eProxyAddr: TEdit
          AlignWithMargins = True
          Left = 6
          Top = 105
          Width = 211
          Height = 24
          TabOrder = 1
          TextHint = 'host:port'
        end
        object cbProvider: TComboBox
          Left = 8
          Top = 136
          Width = 209
          Height = 24
          Style = csDropDownList
          TabOrder = 2
          OnChange = cbProviderChange
        end
      end
      object Panel6: TPanel
        Left = 1
        Top = 261
        Width = 226
        Height = 200
        Align = alClient
        BevelOuter = bvNone
        TabOrder = 3
        DesignSize = (
          226
          200)
        object Label6: TLabel
          Left = 3
          Top = 144
          Width = 85
          Height = 16
          Caption = 'Visible Layers'
        end
        object btnSaveView: TButton
          AlignWithMargins = True
          Left = 3
          Top = 39
          Width = 220
          Height = 30
          Align = alTop
          Caption = 'Save current view'
          TabOrder = 0
          OnClick = btnSaveViewClick
        end
        object btnAddRandomMapMarks: TButton
          AlignWithMargins = True
          Left = 3
          Top = 75
          Width = 220
          Height = 30
          Align = alTop
          Caption = 'Add 100 random marks'
          TabOrder = 1
          OnClick = btnAddRandomMapMarksClick
        end
        object btnTest: TButton
          AlignWithMargins = True
          Left = 3
          Top = 111
          Width = 220
          Height = 30
          Align = alTop
          Caption = 'Run test suite'
          TabOrder = 2
          OnClick = btnTestClick
        end
        object chbLayer1: TCheckBox
          Tag = 1
          Left = 97
          Top = 144
          Width = 33
          Height = 17
          Caption = '1'
          Checked = True
          State = cbChecked
          TabOrder = 3
          OnClick = chbLayer1Click
        end
        object chbLayer2: TCheckBox
          Tag = 2
          Left = 129
          Top = 144
          Width = 33
          Height = 17
          Caption = '2'
          Checked = True
          State = cbChecked
          TabOrder = 4
          OnClick = chbLayer1Click
        end
        object chbLayer3: TCheckBox
          Tag = 4
          Left = 193
          Top = 144
          Width = 33
          Height = 17
          Caption = '4'
          Checked = True
          State = cbChecked
          TabOrder = 5
          OnClick = chbLayer1Click
        end
        object chbLayer4: TCheckBox
          Tag = 3
          Left = 161
          Top = 144
          Width = 33
          Height = 17
          Caption = '3'
          Checked = True
          State = cbChecked
          TabOrder = 6
          OnClick = chbLayer1Click
        end
        object btnSaveMap: TButton
          AlignWithMargins = True
          Left = 3
          Top = 3
          Width = 220
          Height = 30
          Align = alTop
          Caption = 'Save whole map'
          TabOrder = 7
          OnClick = btnSaveMapClick
        end
        object btnAddRoute: TButton
          Left = 3
          Top = 167
          Width = 220
          Height = 30
          Anchors = []
          Caption = 'Add random route'
          TabOrder = 8
          OnClick = btnAddRouteClick
        end
      end
      object Panel7: TPanel
        Left = 1
        Top = 461
        Width = 226
        Height = 140
        Align = alClient
        BevelOuter = bvNone
        TabOrder = 4
        object Label4: TLabel
          AlignWithMargins = True
          Left = 3
          Top = 52
          Width = 220
          Height = 16
          Align = alTop
          Caption = 'Latitude'
        end
        object Label5: TLabel
          AlignWithMargins = True
          Left = 3
          Top = 3
          Width = 220
          Height = 16
          Align = alTop
          Caption = 'Longitude'
        end
        object editLatitude: TEdit
          AlignWithMargins = True
          Left = 3
          Top = 71
          Width = 220
          Height = 24
          Align = alTop
          TabOrder = 1
          Text = '-31.953512'
          TextHint = 'Latitude'
        end
        object editLongitude: TEdit
          AlignWithMargins = True
          Left = 3
          Top = 22
          Width = 220
          Height = 24
          Align = alTop
          TabOrder = 0
          Text = '115.857048'
          TextHint = 'Longitude'
        end
        object btnGoLatLong: TButton
          AlignWithMargins = True
          Left = 3
          Top = 101
          Width = 220
          Height = 33
          Align = alClient
          Caption = 'Navigate'
          TabOrder = 2
          OnClick = btnGoLatLongClick
        end
      end
      object Panel8: TPanel
        Left = 1
        Top = 601
        Width = 226
        Height = 50
        Align = alClient
        BevelOuter = bvNone
        TabOrder = 5
        object Label1: TLabel
          AlignWithMargins = True
          Left = 3
          Top = 3
          Width = 220
          Height = 16
          Align = alTop
          Caption = 'Pixels: %d : %d'
        end
        object Label2: TLabel
          AlignWithMargins = True
          Left = 3
          Top = 22
          Width = 220
          Height = 16
          Align = alTop
          Caption = 'Geo coords: %.3f : %.3f'
        end
      end
    end
  end
  object mLog: TMemo
    Left = 0
    Top = 711
    Width = 975
    Height = 144
    Align = alBottom
    ScrollBars = ssVertical
    TabOrder = 2
  end
end
