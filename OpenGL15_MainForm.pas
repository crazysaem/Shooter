// =============================================================================
//   OpenGL1.5 - VCL Template (opengl15_vcl_template.zip)
// =============================================================================
//   Copyright © 2003 by DGL - http://www.delphigl.com
// =============================================================================
//   Contents of this file are subject to the GNU Public License (GPL) which can
//   be obtained here : http://opensource.org/licenses/gpl-license.php
// =============================================================================
//   History :
//    Version 1.0 - Initial Release                            (Sascha Willems)
// =============================================================================

unit OpenGL15_MainForm;

{$MODE Delphi}

interface

uses
  LCLIntf,Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs, dglOpenGL,
  StdCtrls, LResources, SDL, SDL_Image, Kamera, Weaponspas, Light, Newtonpas,
  LoadWLD, LoadMDL, Modelpas;

type
  TGLForm = class(TForm)
    Button1: TButton;
    Button3: TButton;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure ApplicationEventsIdle(Sender: TObject; var Done: Boolean);
    procedure FormKeyPress(Sender: TObject; var Key: Char);
    procedure Button1Click(Sender: TObject);
    procedure FormMouseWheelDown(Sender: TObject; Shift: TShiftState;
      MousePos: TPoint; var Handled: Boolean);
    procedure FormMouseWheelUp(Sender: TObject; Shift: TShiftState;
      MousePos: TPoint; var Handled: Boolean);
    procedure Button3Click(Sender: TObject);
    procedure FormMouseMove(Sender: TObject; Shift: TShiftState; X,
      Y: Integer);
    procedure FormMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure FormMouseUp(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
  private
    { Private-Deklarationen }
  public
    RC        : HGLRC;
    DC        : HDC;
    ShowFPS   : Boolean;
    StartTick : Cardinal;
    FPS       : Single;
    procedure GoToFullScreen(pWidth, pHeight, pBPP, pFrequency : Word);
  end;

const
  NearClipping = 0.1;
  FarClipping  = 10000;
  Worldsize = 30;

var
  GLForm: TGLForm;
  texid:gluint;
  zoom,StartTime,DrawTime,TimeCount,TimeCount2,FrameCount,wait,x,y,z:extended;
  Frames,AVGFrames,RAVGFrames,AVGCOUNT,ammo:integer;
  Weapons:array of TWeapons;
  FontBase  : GLUInt;
  mclick,shot,reload:boolean;
  t1, t2,xt1,xt2,time1,time2, Res: int64;
  Newton:TNewton;
  World:TWLD;
  Model:array of TModel;
  // Physics timing
  AccTimeSlice  : Single;
  TimeLastFrame : Cardinal;
  Time          : Single;

implementation


procedure Light;
const
    light0_ambient  : Array[0..3] of GlFloat = (0.4, 0.4, 0.4, 1.0);
    lightcolor1     : Array[0..3] of GlFloat = (1, 1, 1, 1.0);
  var
    LightDirection : Array[0..2] of GlFloat;
    lightpos1       : Array[0..3] of GlFloat;
    lauf:integer;
  begin
  lightpos1[0]:=x;
  lightpos1[1]:=z;
  lightpos1[2]:=y;
  lightpos1[3]:=1;

  gllightmodelfv(GL_LIGHT_MODEL_AMBIENT, @light0_ambient);
  (*
  for lauf:=0 to 20 do begin
    lightpos1[0]:=random(1000);
    lightpos1[1]:=random(1000);
    lightpos1[2]:=random(1000);
    gllightfv(GL_LIGHT0+lauf, GL_DIFFUSE, @lightcolor1);
    gllightfv(GL_LIGHT0+lauf, GL_POSITION, @lightpos1);
  end;*)

  gllightfv(GL_LIGHT0, GL_DIFFUSE, @lightcolor1);
  gllightfv(GL_LIGHT0, GL_POSITION, @lightpos1);

  glPushMatrix();
    glTranslatef(x, z, y);
    //models[0].Draw;
    //models[0].RDraw(1);
  glPopMatrix();
end;

procedure Render;
var Matrix:TArrMatrix;
begin
// Farb- und Tiefenpuffer löschen
glClear(GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT);
// In die Projektionsmatrix wechseln
glMatrixMode(GL_PROJECTION);
// Identitätsmatrix laden
glLoadIdentity;
// Viewport an Clientareal des Fensters anpassen
//glViewPort(0, 0, ClientWidth, ClientHeight);
// Perspective, FOV und Tiefenreichweite setzen
//gluPerspective(60, ClientWidth/ClientHeight, 1, 128);

gluPerspective(45.0, GLForm.ClientWidth/GLForm.ClientHeight, NearClipping, FarClipping);

// In die Modelansichtsmatrix wechseln
glMatrixMode(GL_MODELVIEW);
// Identitätsmatrix laden
glLoadIdentity; 

glPushMatrix();
  glTranslatef(0.90, -5.32, -0.5);
  glrotatef(-90,1,0,0);
  glrotatef(180,0,0,1);
  //glrotatef(180,0,1,0);
  glscalef(7,7,7);
  //Model[0].AdvanceAnimation XX -> SIEHE IDLE EVENT
  //Model[0].Render;
  Weapons[0].Draw;
glPopMatrix();

KameraDraw(@Newton);

Light;

glPushMatrix();
  glscalef(Worldsize,Worldsize,Worldsize);
  glGetDoublev(GL_MODELVIEW_MATRIX,@Matrix);
  World.Render;
glPopMatrix();

glPushMatrix();
  //Model[0].AdvanceAnimation XX -> SIEHE IDLE EVENT
  Model[0].Render;
  Model[1].Render;
  Model[2].Render;
glPopMatrix();

end;

// =============================================================================
//  TForm1.GoToFullScreen
// =============================================================================
//  Wechselt in den mit den Parametern angegebenen Vollbildmodus
// =============================================================================
procedure TGLForm.GoToFullScreen(pWidth, pHeight, pBPP, pFrequency : Word);
var
 dmScreenSettings : DevMode;
begin
// Fenster vor Vollbild vorbereiten
WindowState := wsMaximized;
BorderStyle := bsNone;
ZeroMemory(@dmScreenSettings, SizeOf(dmScreenSettings));
with dmScreenSettings do
 begin
 dmSize              := SizeOf(dmScreenSettings);
 dmPelsWidth         := pWidth;                    // Breite
 dmPelsHeight        := pHeight;                   // Höhe
 dmBitsPerPel        := pBPP;                      // Farbtiefe
 dmDisplayFrequency  := pFrequency;                // Bildwiederholfrequenz
 dmFields            := DM_PELSWIDTH or DM_PELSHEIGHT or DM_BITSPERPEL or DM_DISPLAYFREQUENCY;
 end;
if (ChangeDisplaySettings(dmScreenSettings, CDS_FULLSCREEN) = DISP_CHANGE_FAILED) then
 begin
 MessageBox(0, 'Konnte Vollbildmodus nicht aktivieren!', 'Error', MB_OK or MB_ICONERROR);
 exit
 end;
end;

procedure Init;
var lauf:integer;
begin
  glEnable(GL_DEPTH_TEST);
	glEnable(GL_LIGHTING);
  (*
  for lauf:=0 to 20 do begin
    glEnable(GL_LIGHT0+lauf);
  end;*)
  glEnable(GL_LIGHT0);
	glEnable(GL_NORMALIZE);
	glEnable(GL_COLOR_MATERIAL);
  glEnable(GL_POINT_SMOOTH);
  glEnable(GL_LINE_SMOOTH);
	glShadeModel(GL_SMOOTH);
  glEnable(GL_CULL_FACE);
  //glFrontFace(GL_CW); GL_CCW Standart
  //glShadeModel(GL_Flat);
  //glPolygonMode(GL_FRONT_AND_BACK, GL_LINE);

  StartTime:=0;
  DrawTime:=0;
  TimeCount:=0;
  FrameCount:=0;
  TimeCount2:=0;

  // In die Modelansichtsmatrix wechseln
  glMatrixMode(GL_MODELVIEW);
  // Identitätsmatrix laden
  glLoadIdentity;


  GLFORM.KeyPreview:=true;
  KameraInit(trunc(GLForm.Left+GLForm.Width/2),trunc(GLForm.top+GLForm.height/2),'normal');

  //InitNewton
  Newton:=TNewton.Create;
  Newton.Init;

  Newton.CreateCharacter(NV3(4.5/30*Worldsize, 10/30*Worldsize, 4.5/30*Worldsize));
  PlayerSpeed:=30*Worldsize;
  Newton.SetWorldSize(-1500,1500);

  World:=TWLD.Create;
  //World.LoadWorld('C:\Program Files\Borland\Delphi7\Projects\Shooter\Shooter\Models\Worlds\Test\world003.wld',@Newton);
  World.LoadWorld(ExtractFilePath(ParamStr(0))+'Models\Worlds\Test\wld7.wld',@Newton);
  setlength(Model,3);
  Model[0] := TModel.Create;
  Model[0].LoadModel('Crate','Box',true,20,@Newton);
  Model[1] := TModel.Create;
  Model[1].LoadModel('Crate','Box',true,20,@Newton);
  Model[2] := TModel.Create;
  Model[2].LoadModel('Male','Box',true,0,@Newton);
  //Model[2].SetFrame(2,70);

  setlength(Weapons,1);

  Weapons[0] := TWeapons.Create;
  Weapons[0].LoadWeapon('gun');
  Weapons[0].Initialisieren;
end;

// =============================================================================
//  TForm1.FormCreate
// =============================================================================
//  OpenGL-Initialisierungen kommen hier rein
// =============================================================================
procedure TGLForm.FormCreate(Sender: TObject);
begin
// Wenn gewollt, dann hier in den Vollbildmodus wechseln
// Muss vorm Erstellen des Kontextes geschehen, da durch den Wechsel der
// Gerätekontext ungültig wird!
// GoToFullscreen(1600, 1200, 32, 75);
randomize;
x:=0;y:=0;z:=0;
zoom:=0;
shot:=false;
mclick:=false;
reload:=false;
ammo:=7;

//GoToFullScreen(1680,1050,32,60);
                     
// OpenGL-Funtionen initialisieren
InitOpenGL;
// Gerätekontext holen
DC := GetDC(Handle);
// Renderkontext erstellen (32 Bit Farbtiefe, 24 Bit Tiefenpuffer, Doublebuffering)
RC := CreateRenderingContext(DC, [opDoubleBuffered], 32, 24, 0, 0, 0, 0);
// Erstellten Renderkontext aktivieren
ActivateRenderingContext(DC, RC);
// Tiefenpuffer aktivieren
glEnable(GL_DEPTH_TEST);
// Nur Fragmente mit niedrigerem Z-Wert (näher an Betrachter) "durchlassen"
glDepthFunc(GL_Less);
// Löschfarbe für Farbpuffer setzen
glClearColor(0.3, 0.4, 0.7, 0.0);
// Displayfont erstellen
//BuildFont('MS Sans Serif');

init;

AVGCOUNT:=0;
AVGFrames:=0;
TimeLastFrame := SDL_GetTicks;
Time          := TimeLastFrame;
xt2 := SDL_GetTicks;
time2 := SDL_GetTicks;

// Idleevent für Rendervorgang zuweisen
Application.OnIdle := ApplicationEventsIdle;
// Zeitpunkt des Programmstarts für FPS-Messung speichern
StartTick := GetTickCount;
end;

// =============================================================================
//  TForm1.FormDestroy
// =============================================================================
//  Hier sollte man wieder alles freigeben was man so im Speicher belegt hat
// =============================================================================
procedure TGLForm.FormDestroy(Sender: TObject);
begin
// Renderkontext deaktiveren
DeactivateRenderingContext;
// Renderkontext "befreien"
wglDeleteContext(RC);
// Erhaltenen Gerätekontext auch wieder freigeben
ReleaseDC(Handle, DC);
// Falls wir im Vollbild sind, Bildschirmmodus wieder zurücksetzen
//ChangeDisplaySettings(devmode(nil^), 0);
end;

// =============================================================================
//  TForm1.ApplicationEventsIdle
// =============================================================================
//  Hier wird gerendert. Der Idle-Event wird bei Done=False permanent aufgerufen
// =============================================================================
procedure TGLForm.ApplicationEventsIdle(Sender: TObject; var Done: Boolean);
var fp:single;
begin
  // Accumulative time slicing
  AccTimeSlice  := AccTimeSlice + (SDL_GetTicks-TimeLastFrame);
  TimeLastFrame := SDL_GetTicks;

  //xt1 := (SDL_GetTicks-xt2);
  //xt2 := SDL_GetTicks;

  //time1 := SDL_GetTicks;

  //if RAVGFrames>=60 then sleep(16);
  //QueryPerformanceFrequency(Res);
  //QueryPerformanceCounter(t1);
  Render;

  // Hinteren Puffer nach vorne bringen
  SwapBuffers(DC);
  (*
  Frames:=trunc(1/(AccTimeSlice/1000));//trunc(1000/(xt1));
  AVGCOUNT:=AVGCOUNT+1;
  AVGFrames:=AVGFrames+Frames;
  if ((time1-time2))>=500 then begin
    time2 := SDL_GetTicks;
    RAVGFrames:=trunc(AVGFrames/AVGCOUNT);
    glform.Caption := InttoStr(RAVGFrames) + 'FPS';
    AVGFrames:=0;
    AVGCOUNT:=0;
  end;*)

  // Correct timing is crucial for physics calculations if they should run the same
  // speed, no matter what FPS. So we use a method called "accumulative timeslicing"
  // which will give us the same results across all framerates
  while AccTimeSlice > 12 do
  begin
    Newton.Update((12/1000));
    KameraMoveKey(1/(12/1000),@Newton);
    //Model[0].AdvanceAnimation(12,1000*5);
    Weapons[0].AdvanceAnimation(12,1000*5);
    AccTimeSlice := AccTimeSlice - 12;
  end;
  //if fp<>0 then glform.Caption := floattostr(fp) + 'FPS';

  // Windows denken lassen, das wir noch nicht fertig wären
  Done := False;
end;

// =============================================================================
//  TForm1.FormKeyPress
// =============================================================================
procedure TGLForm.FormKeyPress(Sender: TObject; var Key: Char);
begin
case Key of
 #27 : Close;
 //'w' : showmessage('w');
 'j': x:=x-0.5;
 'i': y:=y-0.5;
 'l': x:=x+0.5;
 'k': y:=y+0.5;
 'o': z:=z-0.5;
 'u': z:=z+0.5;
 'r': begin(*
        if (shot=false) then begin
          models[1].setAnimationF(9,22);
          models[3].setAnimationF(9,22);
          models[5].setAnimationF(9,22);
          reload:=true;
        end;*)
        Weapons[0].reloadp;
      end;
 #32 : Newton.CharJump;
end;

end;

procedure TGLForm.Button1Click(Sender: TObject);
begin
  showmessage(inttostr(GL_MAX_LIGHTS));
end;

procedure TGLForm.FormMouseWheelDown(Sender: TObject; Shift: TShiftState;
  MousePos: TPoint; var Handled: Boolean);
begin
  //if zoom>-0.6 then
  zoom:=zoom-0.05;
end;

procedure TGLForm.FormMouseWheelUp(Sender: TObject; Shift: TShiftState;
  MousePos: TPoint; var Handled: Boolean);
begin
  //if zoom<1 then
  zoom:=zoom+0.05;
end;

procedure TGLForm.Button3Click(Sender: TObject);
begin
  gluLookAt(10,10,10,0,0,0,0,1,0);
  showmessage('');
end;

procedure TGLForm.FormMouseMove(Sender: TObject; Shift: TShiftState; X,
  Y: Integer);
begin
  KameraMoveMouse(x,y);
end;

procedure TGLForm.FormMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin (*
  if (Button=mbleft) and (reload=false) and (ammo>0) then begin
    models[1].setAnimationF(2,8);
    models[3].setAnimationF(2,8);
    models[5].setAnimationF(2,8);
    mclick:=true;
  end; *)
  if (Button=mbleft) then begin
    Weapons[0].mclickp;
    if(Weapons[0].physicshot=false) then begin
      Weapons[0].physicshot:=true;
      Newton.Shoot(GetRViewDir);
    end;
  end;
end;

procedure TGLForm.FormMouseUp(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  if Button=mbleft then mclick:=false;
end;

initialization
  {$i OpenGL15_MainForm.lrs}
  {$i OpenGL15_MainForm.lrs}

end.

initialization
{$I OpenGL15_MainForm.lrs}
