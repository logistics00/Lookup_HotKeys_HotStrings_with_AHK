;================= Class_LV_Colors v1.0.0 =================
; ListView row and cell coloring class - provides functionality to set individual
; colors for ListView rows and cells with support for alternate row/column coloring.
#Requires AutoHotkey v2.0+
#SingleInstance Force

Class LV_Colors {
   ; New : 25-01-24
   ; __New : (LV, StaticMode, NoSort, NoSizing) : Create a new LV_Colors instance for the given ListView
   ; LV : object - ListView control object
   ; StaticMode : bool - Enable static mode for sorted lists (optional)
   ; NoSort : bool - Prevent sorting by header clicks (optional)
   ; NoSizing : bool - Prevent column resizing (optional)
   __New(LV, StaticMode := False, NoSort := False, NoSizing := False) {
      If (LV.Type != 'ListView')
         Throw TypeError('LV_Colors requires a ListView control!', -1, LV.Type)
      ; Set LVS_EX_DOUBLEBUFFER (0x010000) style to avoid drawing issues.
      LV.Opt('+LV0x010000')
      ; Get the default colors
      BkClr := SendMessage(0x1025, 0, 0, LV) ; LVM_GETTEXTBKCOLOR
      TxClr := SendMessage(0x1023, 0, 0, LV) ; LVM_GETTEXTCOLOR
      ; Get the header control
      Header := SendMessage(0x101F, 0, 0, LV) ; LVM_GETHEADER
      ; Set other properties
      This.LV := LV
      This.HWND := LV.HWND
      This.Header := Header
      This.BkClr := BkCLr
      This.TxClr := Txclr
      This.IsStatic := !!StaticMode
      This.AltCols := False
      This.AltRows := False
      This.SelColors := False
      This.NoSort(!!NoSort)
      This.NoSizing(!!NoSizing)
      This.ShowColors()
      This.RowCount := LV.GetCount()
      This.ColCount := LV.GetCount('Col')
      This.Rows := Map()
      This.Rows.Capacity := This.RowCount
      This.Cells := Map()
      This.Cells.Capacity := This.RowCount
   }
   
   ; New : 25-01-24
   ; __Delete : () : Destructor - cleanup when object is destroyed
   __Delete() {
      This.ShowColors(False)
      If WinExist(This.HWND)
         WinRedraw(This.HWND)
   }
   
   ; New : 25-01-24
   ; Clear : (AltRows, AltCols) : Clears all row and cell colors
   ; AltRows : bool - Also clear alternating row colors (optional)
   ; AltCols : bool - Also clear alternating column colors (optional)
   ; Returns : bool - True on success
   Clear(AltRows := False, AltCols := False) {
      If (AltCols)
         This.AltCols := False
      If (AltRows)
         This.AltRows := False
      This.Rows.Clear()
      This.Rows.Capacity := This.RowCount
      This.Cells.Clear()
      This.Cells.Capacity := This.RowCount
      Return True
   }
   
   ; New : 25-01-24
   ; UpdateProps : () : Updates the RowCount, ColCount, BkClr, and TxClr properties
   ; Returns : bool - True on success, False if HWND invalid
   UpdateProps() {
      If !(This.HWND)
         Return False
      This.BkClr := SendMessage(0x1025, 0, 0, This.LV) ; LVM_GETTEXTBKCOLOR
      This.TxClr := SendMessage(0x1023, 0, 0, This.LV) ; LVM_GETTEXTCOLOR
      This.RowCount := This.LV.GetCount()
      This.Colcount := This.LV.GetCount('Col')
      If WinExist(This.HWND)
         WinRedraw(This.HWND)
      Return True
   }
   
   ; New : 25-01-24
   ; AlternateRows : (BkColor, TxColor) : Sets background and/or text color for even row numbers
   ; BkColor : string|int - Background color (RGB or color name) (optional)
   ; TxColor : string|int - Text color (RGB or color name) (optional)
   ; Returns : bool - True on success, False on failure
   AlternateRows(BkColor := '', TxColor := '') {
      If !(This.HWND)
         Return False
      This.AltRows := False
      If (BkColor = '') && (TxColor = '')
         Return True
      BkBGR := This.BGR(BkColor)
      TxBGR := This.BGR(TxColor)
      If (BkBGR = '') && (TxBGR = '')
         Return False
      This.ARB := (BkBGR != '') ? BkBGR : This.BkClr
      This.ART := (TxBGR != '') ? TxBGR : This.TxClr
      This.AltRows := True
      Return True
   }
   
   ; New : 25-01-24
   ; AlternateCols : (BkColor, TxColor) : Sets background and/or text color for even column numbers
   ; BkColor : string|int - Background color (RGB or color name) (optional)
   ; TxColor : string|int - Text color (RGB or color name) (optional)
   ; Returns : bool - True on success, False on failure
   AlternateCols(BkColor := '', TxColor := '') {
      If !(This.HWND)
         Return False
      This.AltCols := False
      If (BkColor = '') && (TxColor = '')
         Return True
      BkBGR := This.BGR(BkColor)
      TxBGR := This.BGR(TxColor)
      If (BkBGR = '') && (TxBGR = '')
         Return False
      This.ACB := (BkBGR != '') ? BkBGR : This.BkClr
      This.ACT := (TxBGR != '') ? TxBGR : This.TxClr
      This.AltCols := True
      Return True
   }
   
   ; New : 25-01-24
   ; SelectionColors : (BkColor, TxColor) : Sets background and/or text color for selected rows
   ; BkColor : string|int - Background color (RGB or color name) (optional)
   ; TxColor : string|int - Text color (RGB or color name) (optional)
   ; Returns : bool - True on success, False on failure
   SelectionColors(BkColor := '', TxColor := '') {
      If !(This.HWND)
         Return False
      This.SelColors := False
      If (BkColor = '') && (TxColor = '')
         Return True
      BkBGR := This.BGR(BkColor)
      TxBGR := This.BGR(TxColor)
      If (BkBGR = '') && (TxBGR = '')
         Return False
      This.SELB := BkBGR
      This.SELT := TxBGR
      This.SelColors := True
      Return True
   }
   
   ; New : 25-01-24
   ; Row : (Row, BkColor, TxColor) : Sets background and/or text color for the specified row
   ; Row : int - Row number to color
   ; BkColor : string|int - Background color (RGB or color name) (optional)
   ; TxColor : string|int - Text color (RGB or color name) (optional)
   ; Returns : bool - True on success, False on failure
   Row(Row, BkColor := '', TxColor := '') {
      If !(This.HWND)
         Return False
      If (Row >This.RowCount)
         Return False
      If This.IsStatic
         Row := This.MapIndexToID(Row)
      If This.Rows.Has(Row)
         This.Rows.Delete(Row)
      If (BkColor = '') && (TxColor = '')
         Return True
      BkBGR := This.BGR(BkColor)
      TxBGR := This.BGR(TxColor)
      If (BkBGR = '') && (TxBGR = '')
         Return False
      This.Rows[Row] := Map('B', (BkBGR != '') ? BkBGR : This.BkClr, 'T', (TxBGR != '') ? TxBGR : This.TxClr)
      Return True
   }
   
   ; New : 25-01-24
   ; Cell : (Row, Col, BkColor, TxColor) : Sets background and/or text color for the specified cell
   ; Row : int - Row number
   ; Col : int - Column number
   ; BkColor : string|int - Background color (RGB or color name) (optional)
   ; TxColor : string|int - Text color (RGB or color name) (optional)
   ; Returns : bool - True on success, False on failure
   Cell(Row, Col, BkColor := '', TxColor := '') {
      If !(This.HWND)
         Return False
      If (Row > This.RowCount) || (Col > This.ColCount)
         Return False
      If This.IsStatic
         Row := This.MapIndexToID(Row)
      If This.Cells.Has(Row) && This.Cells[Row].Has(Col)
         This.Cells[Row].Delete(Col)
      If (BkColor = '') && (TxColor = '')
         Return True
      BkBGR := This.BGR(BkColor)
      TxBGR := This.BGR(TxColor)
      If (BkBGR = '') && (TxBGR = '')
         Return False
      If !This.Cells.Has(Row)
         This.Cells[Row] := [], This.Cells[Row].Capacity := This.ColCount
      If (Col > This.Cells[Row].Length)
         This.Cells[Row].Length := Col
      This.Cells[Row][Col] := Map('B', (BkBGR != '') ? BkBGR : This.BkClr, 'T', (TxBGR != '') ? TxBGR : This.TxClr)
      Return True
   }
   
   ; New : 25-01-24
   ; NoSort : (Apply) : Prevents/allows sorting by click on a header item for this ListView
   ; Apply : bool - True to prevent sorting, False to allow (optional)
   ; Returns : bool - True on success, False if HWND invalid
   NoSort(Apply := True) {
      If !(This.HWND)
         Return False
      This.LV.Opt((Apply ? '+' : '-') . 'NoSort')
      Return True
   }
   
   ; New : 25-01-24
   ; NoSizing : (Apply) : Prevents/allows resizing of columns for this ListView
   ; Apply : bool - True to prevent resizing, False to allow (optional)
   ; Returns : bool - True on success, False if Header invalid
   NoSizing(Apply := True) {
      If !(This.Header)
         Return False
      ControlSetStyle((Apply ? '+' : '-') . '0x0800', This.Header) ; HDS_NOSIZING = 0x0800
      Return True
   }
   
   ; New : 25-01-24
   ; ShowColors : (Apply) : Adds/removes a message handler for NM_CUSTOMDRAW notifications of this ListView
   ; Apply : bool - True to enable colors, False to disable (optional)
   ; Returns : bool - True on success
   ShowColors(Apply := True) {
      If (Apply) && !This.HasOwnProp('OnNotifyFunc') {
         This.OnNotifyFunc := ObjBindMethod(This, 'NM_CUSTOMDRAW')
         This.LV.OnNotify(-12, This.OnNotifyFunc)
         WinRedraw(This.HWND)
      }
      Else If !(Apply) && This.HasOwnProp('OnNotifyFunc') {
         This.LV.OnNotify(-12, This.OnNotifyFunc, 0)
         This.OnNotifyFunc := ''
         This.DeleteProp('OnNotifyFunc')
         WinRedraw(This.HWND)
      }
      Return True
   }
   
   ; New : 25-01-24
   ; NM_CUSTOMDRAW : (LV, L) : Internal message handler for NM_CUSTOMDRAW notifications
   ; LV : object - ListView control object
   ; L : ptr - LPARAM containing NMLVCUSTOMDRAW structure
   ; Returns : int - Custom draw return code
   NM_CUSTOMDRAW(LV, L) {
      Static SizeNMHDR := A_PtrSize * 3
      Static SizeNCD := SizeNMHDR + 16 + (A_PtrSize * 5)
      Static OffItem := SizeNMHDR + 16 + (A_PtrSize * 2)
      Static OffItemState := OffItem + A_PtrSize
      Static OffCT :=  SizeNCD
      Static OffCB := OffCT + 4
      Static OffSubItem := OffCB + 4
      Critical -1
      If !(This.HWND) || (NumGet(L, 'UPtr') != This.HWND)
         Return
      DrawStage := NumGet(L + SizeNMHDR, 'UInt'),
      Row := NumGet(L + OffItem, 'UPtr') + 1,
      Col := NumGet(L + OffSubItem, 'Int') + 1,
      Item := Row - 1
      If This.IsStatic
         Row := This.MapIndexToID(Row)
      If (DrawStage = 0x030001) {
         UseAltCol := (This.AltCols) && !(Col & 1),
         ColColors := (This.Cells.Has(Row) && This.Cells[Row].Has(Col)) ? This.Cells[Row][Col] : Map('B', '', 'T', ''),
         ColB := (ColColors['B'] != '') ? ColColors['B'] : UseAltCol ? This.ACB : This.RowB,
         ColT := (ColColors['T'] != '') ? ColColors['T'] : UseAltCol ? This.ACT : This.RowT,
         NumPut('UInt', ColT, L + OffCT), NumPut('UInt', ColB, L + OffCB)
         Return (!This.AltCols && (Col > This.Cells[Row].Length)) ? 0x00 : 0x020
      }
      If (DrawStage = 0x010001) {
         If (This.SelColors) && SendMessage(0x102C, Item, 0x0002, This.HWND) {
            NumPut('UInt', NumGet(L + OffItemState, 'UInt') & ~0x0011, L + OffItemState)
            If (This.SELB != '')
               NumPut('UInt', This.SELB, L + OffCB)
            If (This.SELT != '')
               NumPut('UInt', This.SELT, L + OffCT)
            Return 0x02
         }
         UseAltRow := This.AltRows && (Item & 1),
         RowColors := This.Rows.Has(Row) ? This.Rows[Row] : '',
         This.RowB := RowColors ? RowColors['B'] : UseAltRow ? This.ARB : This.BkClr,
         This.RowT := RowColors ? RowColors['T'] : UseAltRow ? This.ART : This.TxClr
         If (This.AltCols || This.Cells.Has(Row))
            Return 0x20
         NumPut('UInt', This.RowT, L + OffCT), NumPut('UInt', This.RowB, L + OffCB)
         Return 0x00
      }
      Return (DrawStage = 0x000001) ? 0x20 : 0x00
   }
   
   ; New : 25-01-24
   ; MapIndexToID : (Row) : Provides the unique internal ID of the given row number
   ; Row : int - Row number (1-based)
   ; Returns : int - Unique internal ID for the row
   MapIndexToID(Row) {
      Return SendMessage(0x10B4, Row - 1, 0, This.HWND) ; LVM_MAPINDEXTOID
   }
   
   ; New : 25-01-24
   ; BGR : (Color, Default) : Converts colors to BGR format
   ; Color : string|int - Color as RGB integer or HTML color name
   ; Default : string - Default value to return if conversion fails (optional)
   ; Returns : int|string - BGR color value or default
   BGR(Color, Default := '') {
      Static HTML := {AQUA: 0xFFFF00, BLACK: 0x000000, BLUE: 0xFF0000, FUCHSIA: 0xFF00FF, GRAY: 0x808080, GREEN: 0x008000
                    , LIME: 0x00FF00, MAROON: 0x000080, NAVY: 0x800000, OLIVE: 0x008080, PURPLE: 0x800080, RED: 0x0000FF
                    , SILVER: 0xC0C0C0, TEAL: 0x808000, WHITE: 0xFFFFFF, YELLOW: 0x00FFFF}
      If IsInteger(Color)
         Return ((Color >> 16) & 0xFF) | (Color & 0x00FF00) | ((Color & 0xFF) << 16)
      Return (HTML.HasOwnProp(Color) ? HTML.%Color% : Default)
   }
}

;================= End of Class_LV_Colors =================
