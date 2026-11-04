object PDFBrowserForm: TPDFBrowserForm
  Left = 303
  Top = 133
  Caption = 'FreePDF64-Viewer Portable'
  ClientHeight = 566
  ClientWidth = 891
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  KeyPreview = True
  Position = poDesigned
  OnClose = FormClose
  OnCreate = FormCreate
  OnResize = FormResize
  OnShow = FormShow
  TextHeight = 15
  object TimerPDF: TTimer
    Enabled = False
    Interval = 300
    OnTimer = TimerPDFTimer
    Left = 412
    Top = 160
  end
end
