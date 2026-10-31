; =====================================================================
;  MinoChat - установщик в виде окна мессенджера (Inno Setup 6)
;  Сборка: двойной щелчок по build.bat (нужен установленный Inno Setup 6)
;  Результат: папка Output\MinoChat-Setup.exe
; =====================================================================
#define AppName "MinoChat"
#define AppUrl  "https://speeky-a0653.web.app"
#ifnexist "app\MinoChat.exe"
  #error Нет папки app\ с приложением. Запустите build-installer.bat в папке проекта - он сам соберёт Electron-приложение и положит его в installer\app.
#endif

[Setup]
AppId={{C41D7A2E-6B93-4F58-A0E1-3D9B52F6A7C8}
AppName={#AppName}
AppVersion=4.0
AppPublisher=MinoChat
AppCopyright=Copyright (C) MinoChat
AppPublisherURL=https://speeky-a0653.web.app
VersionInfoVersion=4.0.0.0
VersionInfoCompany=MinoChat
VersionInfoDescription=MinoChat Setup
VersionInfoProductName=MinoChat
VersionInfoProductVersion=4.0.0.0
VersionInfoCopyright=Copyright (C) MinoChat
DefaultDirName={autopf}\{#AppName}
DisableProgramGroupPage=yes
DisableReadyPage=yes
DisableFinishedPage=no
PrivilegesRequired=lowest
OutputDir=Output
OutputBaseFilename=MinoChat-Setup
SetupIconFile=minochat.ico
UninstallDisplayIcon={app}\minochat.ico
UninstallDisplayName={#AppName}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ShowLanguageDialog=no
CloseApplications=no

[Languages]
Name: "ru"; MessagesFile: "compiler:Languages\Russian.isl"

[Files]
Source: "art\*.bmp"; DestDir: "{tmp}"; Flags: dontcopy
Source: "minochat.ico"; DestDir: "{app}"; Flags: ignoreversion
Source: "app\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\{#AppName}"; Filename: "{app}\MinoChat.exe"; IconFilename: "{app}\minochat.ico"; Comment: "MinoChat - мессенджер"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\MinoChat.exe"; IconFilename: "{app}\minochat.ico"; Comment: "MinoChat - мессенджер"; Check: WantDesktop

[Registry]
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Run"; ValueType: string; ValueName: "MinoChat"; ValueData: """{app}\MinoChat.exe"""; Flags: uninsdeletevalue; Check: WantAutostart

[Code]
const
  SiteUrl = '{#AppUrl}';
  CBG    = $140805;   // #050814
  CPANEL = $210F0A;   // #0a0f21
  CTHEM  = $381C13;   // #131c38
  CME    = $FF6B2F;   // #2f6bff
  CACT   = $4D2314;   // подсветка выбранного "чата"
  CTXT   = $F8EAEC;   // #eceaf8
  CMUT   = $A88A8B;   // #8b8aa8
  COK    = $99D334;   // #34d399

var

  // боковая панель
  Side: TPanel;
  RowPn: array[0..4] of TPanel;
  RowNm: array[0..4] of TNewStaticText;
  RowPv: array[0..4] of TNewStaticText;
  HdrSub: TNewStaticText;

  // страницы
  PgA, PgB, PgC: TWizardPage;
  EdDir: TNewEdit;
  // переключатели (рисуем сами, чтобы текст всегда был светлым)
  SwOn: array[0..2] of Boolean;
  SwTrack: array[0..2] of TPanel;
  SwKnob: array[0..2] of TPanel;

  // пузыри, которые "приходят" по одному
  RevPn: array[0..29] of TPanel;
  RevPg: array[0..29] of Integer;
  RevCnt: Integer;
  Shown: array[0..4] of Boolean;

function CreateRoundRectRgn(x1, y1, x2, y2, x3, y3: Integer): LongWord;
  external 'CreateRoundRectRgn@gdi32.dll stdcall';
function GetSystemMetrics(nIndex: Integer): Integer;
  external 'GetSystemMetrics@user32.dll stdcall';
function SetWindowRgn(hWnd: HWND; hRgn: LongWord; bRedraw: Boolean): Integer;
  external 'SetWindowRgn@user32.dll stdcall';

procedure RoundCtl(C: TWinControl; R: Integer);
begin
  SetWindowRgn(C.Handle, CreateRoundRectRgn(0, 0, C.Width + 1, C.Height + 1, R, R), True);
end;

{ ---------- закрыть запущенный MinoChat (он живёт в трее и держит файлы) ---------- }
procedure KillApp;
var
  R: Integer;
begin
  Exec(ExpandConstant('{sys}\taskkill.exe'), '/F /T /IM MinoChat.exe', '', SW_HIDE, ewWaitUntilTerminated, R);
end;

function WantDesktop: Boolean;
begin
  Result := SwOn[0];
end;

function WantAutostart: Boolean;
begin
  Result := SwOn[1];
end;

{ ---------- картинки ---------- }
function PutImg(Parent: TWinControl; const FileName: String; X, Y, W, H: Integer): TBitmapImage;
begin
  if not FileExists(ExpandConstant('{tmp}\' + FileName)) then ExtractTemporaryFile(FileName);
  Result := TBitmapImage.Create(WizardForm);
  Result.Parent := Parent;
  Result.Stretch := True;
  Result.AutoSize := False;
  Result.Bitmap.LoadFromFile(ExpandConstant('{tmp}\' + FileName));
  Result.SetBounds(X, Y, W, H);
end;

{ круглая аватарка-картинка }
function PutAvatar(Parent: TWinControl; const FileName: String; X, Y, D: Integer): TPanel;
begin
  Result := TPanel.Create(WizardForm);
  Result.Parent := Parent;
  Result.BevelOuter := bvNone;
  Result.ParentBackground := False;
  Result.Color := CPANEL;
  Result.SetBounds(X, Y, D, D);
  PutImg(Result, FileName, 0, 0, D, D);
  RoundCtl(Result, D);
end;

{ ---------- строительные блоки интерфейса ---------- }
function MakeLabel(Parent: TWinControl; const Txt: String; X, Y, W, Size: Integer;
  Bold: Boolean; FontColor, BackColor: TColor): TNewStaticText;
begin
  Result := TNewStaticText.Create(WizardForm);
  Result.Parent := Parent;
  Result.WordWrap := True;
  Result.AutoSize := True;
  Result.Width := W;
  Result.Left := X;
  Result.Top := Y;
  Result.Color := BackColor;
  Result.Font.Name := 'Segoe UI';
  Result.Font.Size := Size;
  Result.Font.Color := FontColor;
  if Bold then Result.Font.Style := [fsBold];
  Result.Caption := Txt;
end;

function MakeAvatar(Parent: TWinControl; const Letter: String; X, Y, D: Integer;
  BackColor, ParentBack: TColor): TPanel;
begin
  Result := TPanel.Create(WizardForm);
  Result.Parent := Parent;
  Result.BevelOuter := bvNone;
  Result.ParentBackground := False;
  Result.Color := BackColor;
  Result.Caption := Letter;
  Result.Font.Name := 'Segoe UI';
  Result.Font.Size := 12;
  Result.Font.Style := [fsBold];
  Result.Font.Color := clWhite;
  Result.SetBounds(X, Y, D, D);
  RoundCtl(Result, D);
end;

procedure Reg(Pn: TPanel; Pg: Integer);
begin
  RevPn[RevCnt] := Pn;
  RevPg[RevCnt] := Pg;
  RevCnt := RevCnt + 1;
  Pn.Visible := False;
end;

{ пузырь с текстом; возвращает нижнюю границу + отступ }
function Bubble(Parent: TWinControl; Pg: Integer; const Txt: String; Top: Integer; Mine: Boolean): Integer;
var
  Pn: TPanel;
  L, T: TNewStaticText;
  W, X, BC, TC: Integer;
begin
  W := ScaleX(430);
  if Mine then begin X := ScaleX(610) - W - ScaleX(22); BC := CME; TC := clWhite; end
  else begin X := ScaleX(22); BC := CTHEM; TC := CTXT; end;
  Pn := TPanel.Create(WizardForm);
  Pn.Parent := Parent;
  Pn.BevelOuter := bvNone;
  Pn.ParentBackground := False;
  Pn.Color := BC;
  L := MakeLabel(Pn, Txt, ScaleX(16), ScaleY(10), W - ScaleX(32), 10, False, TC, BC);
  T := MakeLabel(Pn, GetDateTimeString('hh:nn', ':', ':'), 0, L.Top + L.Height + ScaleY(2), ScaleX(40), 8, False, CMUT, BC);
  if Mine then T.Font.Color := $F0D8F8;
  T.Left := W - T.Width - ScaleX(14);
  Pn.SetBounds(X, Top, W, T.Top + T.Height + ScaleY(8));
  RoundCtl(Pn, ScaleX(20));
  Reg(Pn, Pg);
  Result := Top + Pn.Height + ScaleY(10);
end;

procedure SetActive(Idx: Integer);
var
  i, C: Integer;
begin
  for i := 0 to 4 do
  begin
    if i = Idx then C := CACT else C := CPANEL;
    RowPn[i].Color := C;
    RowNm[i].Color := C;
    RowPv[i].Color := C;
  end;
end;

procedure RevealPage(Pg: Integer);
var
  i: Integer;
begin
  if Shown[Pg] then Exit;
  Shown[Pg] := True;
  for i := 0 to RevCnt - 1 do
    if RevPg[i] = Pg then
    begin
      HdrSub.Caption := 'печатает...';
      HdrSub.Font.Color := CMUT;
      HdrSub.Repaint;
      Sleep(420);
      RevPn[i].Visible := True;
      RevPn[i].Repaint;
      HdrSub.Caption := 'в сети';
      HdrSub.Font.Color := COK;
      HdrSub.Repaint;
      Sleep(140);
    end;
end;

procedure BrowseClick(Sender: TObject);
var
  Dir: String;
begin
  Dir := EdDir.Text;
  if BrowseForFolder('Выберите папку для MinoChat', Dir, True) then
    EdDir.Text := Dir;
end;

procedure ApplySwitch(I: Integer);
begin
  if SwOn[I] then
  begin
    SwTrack[I].Color := CME;
    SwKnob[I].Left := SwTrack[I].Width - SwKnob[I].Width - ScaleX(3);
  end else
  begin
    SwTrack[I].Color := $5A4A44;
    SwKnob[I].Left := ScaleX(3);
  end;
  SwTrack[I].Repaint;
end;

procedure SwitchClick(Sender: TObject);
var
  I: Integer;
begin
  I := TControl(Sender).Tag;
  SwOn[I] := not SwOn[I];
  ApplySwitch(I);
end;

procedure MakeSwitch(Parent: TWinControl; I: Integer; const Cap: String; Y: Integer; Initial: Boolean);
var
  L: TNewStaticText;
begin
  SwOn[I] := Initial;
  SwTrack[I] := TPanel.Create(WizardForm);
  SwTrack[I].Parent := Parent;
  SwTrack[I].BevelOuter := bvNone;
  SwTrack[I].ParentBackground := False;
  SwTrack[I].Cursor := crHand;
  SwTrack[I].Tag := I;
  SwTrack[I].OnClick := @SwitchClick;
  SwTrack[I].SetBounds(ScaleX(18), Y, ScaleX(44), ScaleY(24));
  SwKnob[I] := TPanel.Create(WizardForm);
  SwKnob[I].Parent := SwTrack[I];
  SwKnob[I].BevelOuter := bvNone;
  SwKnob[I].ParentBackground := False;
  SwKnob[I].Color := clWhite;
  SwKnob[I].Cursor := crHand;
  SwKnob[I].Tag := I;
  SwKnob[I].OnClick := @SwitchClick;
  SwKnob[I].SetBounds(ScaleX(3), ScaleY(3), ScaleY(18), ScaleY(18));
  RoundCtl(SwKnob[I], ScaleY(18));
  RoundCtl(SwTrack[I], ScaleY(24));
  L := MakeLabel(Parent, Cap, ScaleX(76), Y + ScaleY(1), ScaleX(340), 10, False, CTXT, CTHEM);
  L.Cursor := crHand;
  L.Tag := I;
  L.OnClick := @SwitchClick;
  ApplySwitch(I);
end;

procedure BuildSidebar;
var
  Names, Prevs, Letters: array[0..4] of String;
  Cols: array[0..4] of Integer;
  i: Integer;
  Lbl: TNewStaticText;
begin
  Names[0] := 'MinoChat';            Prevs[0] := 'Привет! Давайте знакомиться';  Letters[0] := 'M'; Cols[0] := $FF6B2F;
  Names[1] := 'Папка установки';   Prevs[1] := 'Куда поставить?';             Letters[1] := 'П'; Cols[1] := $B6B206;
  Names[2] := 'Параметры';         Prevs[2] := 'Пара быстрых вопросов';       Letters[2] := 'Н'; Cols[2] := $0B9EF5;
  Names[3] := 'Установка';         Prevs[3] := 'Копирую файлы...';            Letters[3] := 'У'; Cols[3] := $9948EC;
  Names[4] := 'Готово';            Prevs[4] := 'Всё работает';                Letters[4] := 'Г'; Cols[4] := $81B910;

  Side := TPanel.Create(WizardForm);
  Side.Parent := WizardForm;
  Side.BevelOuter := bvNone;
  Side.ParentBackground := False;
  Side.Color := CPANEL;
  Side.SetBounds(0, 0, ScaleX(250), WizardForm.ClientHeight);

  PutImg(Side, 'side_top.bmp', 0, 0, ScaleX(250), ScaleY(84));
  PutImg(Side, 'side_bot.bmp', 0, WizardForm.ClientHeight - ScaleY(126), ScaleX(250), ScaleY(126));
  Lbl := MakeLabel(Side, 'ШАГИ УСТАНОВКИ', ScaleX(18), ScaleY(86), ScaleX(200), 8, True, CMUT, CPANEL);

  for i := 0 to 4 do
  begin
    RowPn[i] := TPanel.Create(WizardForm);
    RowPn[i].Parent := Side;
    RowPn[i].BevelOuter := bvNone;
    RowPn[i].ParentBackground := False;
    RowPn[i].Color := CPANEL;
    RowPn[i].SetBounds(ScaleX(8), ScaleY(104) + i * ScaleY(62), ScaleX(234), ScaleY(58));
    RoundCtl(RowPn[i], ScaleX(16));
    PutAvatar(RowPn[i], 'av' + IntToStr(i) + '.bmp', ScaleX(10), ScaleY(9), ScaleX(40));
    RowNm[i] := MakeLabel(RowPn[i], Names[i], ScaleX(60), ScaleY(8), ScaleX(166), 10, True, CTXT, CPANEL);
    RowPv[i] := MakeLabel(RowPn[i], Prevs[i], ScaleX(60), ScaleY(30), ScaleX(166), 9, False, CMUT, CPANEL);
  end;
end;

procedure BuildHeader;
var
  Pn: TPanel;
  Lbl: TNewStaticText;
begin
  Pn := TPanel.Create(WizardForm);
  Pn.Parent := WizardForm;
  Pn.BevelOuter := bvNone;
  Pn.ParentBackground := False;
  Pn.Color := CPANEL;
  Pn.SetBounds(ScaleX(250), 0, ScaleX(610), ScaleY(64));
  PutAvatar(Pn, 'av0.bmp', ScaleX(18), ScaleY(12), ScaleX(40));
  PutImg(Pn, 'accent.bmp', 0, ScaleY(61), ScaleX(610), ScaleY(3));
  Lbl := MakeLabel(Pn, 'MinoChat', ScaleX(70), ScaleY(10), ScaleX(300), 12, True, CTXT, CPANEL);
  HdrSub := MakeLabel(Pn, 'в сети', ScaleX(70), ScaleY(35), ScaleX(300), 9, False, COK, CPANEL);
end;

procedure BuildPages;
var
  Img: TBitmapImage;
  Y: Integer;
  Pn: TPanel;
  Btn: TNewButton;
  Lbl: TNewStaticText;
begin
  { --- 1. приветствие --- }
  PgA := CreateCustomPage(wpWelcome, '', '');
  PgA.Surface.Color := CBG;
  PutImg(PgA.Surface, 'bg_a.bmp', 0, 0, ScaleX(610), ScaleY(416));
  Y := ScaleY(150);
  Y := Bubble(PgA.Surface, 0, 'Привет! Я MinoChat.', Y, False);
  Y := Bubble(PgA.Surface, 0, 'Это быстрый мессенджер: личные чаты и группы, голосовые сообщения, звонки, свои наборы стикеров и несколько аккаунтов сразу.', Y, False);
  Y := Bubble(PgA.Surface, 0, 'Я установлю настоящее приложение для Windows (на Electron, не сайт в браузере) меньше чем за минуту. Нажмите «Далее» - и начнём.', Y, False);

  { --- 2. папка --- }
  PgB := CreateCustomPage(PgA.ID, '', '');
  PgB.Surface.Color := CBG;
  PutImg(PgB.Surface, 'bg_b.bmp', 0, 0, ScaleX(610), ScaleY(416));
  Y := ScaleY(16);
  Y := Bubble(PgB.Surface, 1, 'Куда установить MinoChat? Предлагаю сюда, но можно выбрать другую папку.', Y, False);
  Pn := TPanel.Create(WizardForm);
  Pn.Parent := PgB.Surface;
  Pn.BevelOuter := bvNone;
  Pn.ParentBackground := False;
  Pn.Color := CME;
  Pn.SetBounds(ScaleX(610) - ScaleX(430) - ScaleX(22), Y, ScaleX(430), ScaleY(104));
  EdDir := TNewEdit.Create(WizardForm);
  EdDir.Parent := Pn;
  EdDir.SetBounds(ScaleX(16), ScaleY(16), ScaleX(398), ScaleY(24));
  EdDir.Text := WizardDirValue;
  Btn := TNewButton.Create(WizardForm);
  Btn.Parent := Pn;
  Btn.Caption := 'Выбрать папку...';
  Btn.SetBounds(ScaleX(16), ScaleY(54), ScaleX(150), ScaleY(30));
  Btn.OnClick := @BrowseClick;
  RoundCtl(Pn, ScaleX(20));
  Reg(Pn, 1);
  Y := Y + Pn.Height + ScaleY(10);
  Y := Bubble(PgB.Surface, 1, 'Много места не нужно: MinoChat очень лёгкий.', Y, False);

  { --- 3. параметры --- }
  PgC := CreateCustomPage(PgB.ID, '', '');
  PgC.Surface.Color := CBG;
  PutImg(PgC.Surface, 'bg_b.bmp', 0, 0, ScaleX(610), ScaleY(416));
  Y := ScaleY(16);
  Y := Bubble(PgC.Surface, 2, 'Последние вопросы. Отметьте, что вам удобно:', Y, False);
  Pn := TPanel.Create(WizardForm);
  Pn.Parent := PgC.Surface;
  Pn.BevelOuter := bvNone;
  Pn.ParentBackground := False;
  Pn.Color := CTHEM;
  Pn.SetBounds(ScaleX(22), Y, ScaleX(430), ScaleY(138));
  MakeSwitch(Pn, 0, 'Значок MinoChat на рабочем столе', ScaleY(18), True);
  MakeSwitch(Pn, 1, 'Запускать MinoChat вместе с Windows', ScaleY(56), False);
  MakeSwitch(Pn, 2, 'Открыть MinoChat сразу после установки', ScaleY(94), True);
  RoundCtl(Pn, ScaleX(20));
  Reg(Pn, 2);
  Y := Y + Pn.Height + ScaleY(10);
  Y := Bubble(PgC.Surface, 2, 'Отлично! Нажмите «Установить».', Y, True);

  { --- 4. установка (стандартная страница, оформляем) --- }
  WizardForm.InstallingPage.Color := CBG;
  Img := PutImg(WizardForm.InstallingPage, 'bg_b.bmp', 0, 0, ScaleX(610), ScaleY(416));
  Img.SendToBack;
  Bubble(WizardForm.InstallingPage, 3, 'Устанавливаю MinoChat. Это займёт несколько секунд...', ScaleY(16), False);
  WizardForm.StatusLabel.Font.Color := CTXT;
  WizardForm.FilenameLabel.Font.Color := CMUT;
  WizardForm.StatusLabel.Top := ScaleY(130);
  WizardForm.FilenameLabel.Top := ScaleY(144);
  WizardForm.ProgressGauge.Top := ScaleY(176);
  WizardForm.ProgressGauge.Width := ScaleX(560);

  { --- 5. готово (стандартная страница, оформляем) --- }
  WizardForm.FinishedPage.Color := CBG;
  Img := PutImg(WizardForm.FinishedPage, 'bg_b.bmp', 0, 0, ScaleX(610), ScaleY(416));
  Img.SendToBack;
  PutImg(WizardForm.FinishedPage, 'ok.bmp', ScaleX(22), ScaleY(8), ScaleX(156), ScaleY(136));
  WizardForm.FinishedHeadingLabel.Visible := False;
  WizardForm.FinishedLabel.Visible := False;
  WizardForm.WizardBitmapImage2.Visible := False;
  WizardForm.RunList.Visible := False;
  Y := ScaleY(150);
  Y := Bubble(WizardForm.FinishedPage, 4, 'Готово! MinoChat установлен.', Y, False);
  Y := Bubble(WizardForm.FinishedPage, 4, 'Приложение MinoChat теперь в меню «Пуск». Оно живёт в трее и получает сообщения, даже если окно закрыто. Войдите по почте и паролю - и можно писать друзьям.', Y, False);
  Y := Bubble(WizardForm.FinishedPage, 4, 'Спасибо!', Y, True);
end;

procedure InitializeWizard;
begin
  RevCnt := 0;

  WizardForm.ClientWidth := ScaleX(860);
  WizardForm.ClientHeight := ScaleY(540);
  WizardForm.Left := (GetSystemMetrics(0) - WizardForm.Width) div 2;
  WizardForm.Top := (GetSystemMetrics(1) - WizardForm.Height) div 2;
  WizardForm.Color := CBG;
  WizardForm.Caption := 'MinoChat - установка';

  WizardForm.Bevel.Visible := False;
  WizardForm.Bevel1.Visible := False;
  WizardForm.MainPanel.Visible := False;
  WizardForm.OuterNotebook.SetBounds(ScaleX(250), ScaleY(64), ScaleX(610), ScaleY(416));
  WizardForm.InnerNotebook.SetBounds(0, 0, ScaleX(610), ScaleY(416));
  WizardForm.WelcomePage.Color := CBG;
  WizardForm.InnerPage.Color := CBG;

  BuildSidebar;
  BuildHeader;
  BuildPages;
  SetActive(0);
end;

function PrepareToInstall(var NeedsRestart: Boolean): String;
begin
  KillApp;
  Result := '';
end;

function InitializeUninstall: Boolean;
var
  R: Integer;
begin
  Exec(ExpandConstant('{sys}\taskkill.exe'), '/F /T /IM MinoChat.exe', '', SW_HIDE, ewWaitUntilTerminated, R);
  Result := True;
end;

function ShouldSkipPage(PageID: Integer): Boolean;
begin
  Result := (PageID = wpWelcome) or (PageID = wpSelectDir);
end;

function NextButtonClick(CurPageID: Integer): Boolean;
begin
  Result := True;
  if CurPageID = PgB.ID then
  begin
    if Trim(EdDir.Text) = '' then
    begin
      MsgBox('Укажите папку для установки.', mbError, MB_OK);
      Result := False;
      Exit;
    end;
    WizardForm.DirEdit.Text := Trim(EdDir.Text);
  end;
end;

procedure CurPageChanged(CurPageID: Integer);
var
  Idx: Integer;
begin
  Idx := -1;
  if CurPageID = PgA.ID then Idx := 0
  else if CurPageID = PgB.ID then Idx := 1
  else if CurPageID = PgC.ID then Idx := 2
  else if CurPageID = wpInstalling then Idx := 3
  else if CurPageID = wpFinished then Idx := 4;

  if CurPageID = PgC.ID then WizardForm.NextButton.Caption := 'Установить'
  else if CurPageID = wpFinished then WizardForm.NextButton.Caption := 'Готово'
  else WizardForm.NextButton.Caption := 'Далее';

  if Idx >= 0 then
  begin
    SetActive(Idx);
    RevealPage(Idx);
  end;
end;

procedure CurStepChanged(CurStep: TSetupStep);
var
  Code: Integer;
begin
  if CurStep = ssDone then
    if SwOn[2] then
      ShellExec('open', ExpandConstant('{app}\MinoChat.exe'), '', '', SW_SHOWNORMAL, ewNoWait, Code);
end;
