unit Kamera;

{$MODE Delphi}

interface

uses LCLIntf,Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs, dglOpenGL, StdCtrls,
      Newtonpas, glMatrixHelper;

type
  ZNewton = ^TNewton;

  TRPOS=record
    x,y,z:extended;
  end;

  SF3dVector=record  //Float 3d-vect, normally used
	  x,y,z:GLfloat;
  end;

  SF2dVector=record
	  x,y:GLfloat;
  end;

procedure KameraMoveKey(Frames:extended;Newton:ZNewton);
procedure KameraDraw(Newton:ZNewton);
procedure KameraInit(x,y:integer;ctype:string);
procedure KameraMoveMouse(x,y:integer);
function  GetRViewDir():TVector3f;

implementation

var
  eyex,eyey,eyez,centerx,centery,centerz,upx,upy,upz,xangle,rotatey,rotatex,xpos,zpos,ypos,mspeed,fixspeed:extended;
  x1,x2,y1,y2,mfestx,mfesty:integer;
  switch,duck,run,ViewDirChanged:boolean;
  Position,ViewDir,RViewDir:SF3dVector;
  camtype:string;
  var MoveVector:SF3dVector;

const
  pi=3.141592653589793238462643383279;

function F3dVector (x,y,z:GLfloat):SF3dVector;
var tmp:SF3dVector;
begin
	tmp.x := x;
	tmp.y := y;
	tmp.z := z;
	F3dVector := tmp;
end;

function AddF3dVectors (u,v:SF3dVector):SF3dVector;
var res:SF3dVector;
begin
	res.x := u.x + v.x;
	if camtype='spectator' then begin res.y := u.y + v.y end else begin res.y := u.y end;
	res.z := u.z + v.z;
  //if camtype<>'spectator' then res.y:=0;
	AddF3dVectors:=res;
end;

procedure AddF3dVectorToVector (Dst,V2:SF3dVector);
begin
	Dst.x := Dst.x + V2.x;
	Dst.y := Dst.y + V2.y;
	Dst.z := Dst.z + V2.z;
end;

procedure KameraInit(x,y:integer;ctype:string);
var  p: TPoint;
begin
  camtype:=ctype;

  p := Mouse.CursorPos;
  p.X := x;  //X-Wert und
  p.Y := y;  //Y-Wert verändern
  Mouse.CursorPos := p;  //Neue Koordinaten übergeben

  mfestx:=x;
  mfesty:=y;

  eyex:=0;
  eyey:=0;
  eyez:=10;
  centerx:=0;
  centery:=0;
  centerz:=0;
  upx:=0;
  upy:=1;
  upz:=0;
  switch:=false;
  xangle:=0;
  rotatey:=0;
  xpos:=0;
  zpos:=0;
  ypos:=0;
  duck:=false;
  mspeed:=15;
  fixspeed:=35;
  run:=false;

	Position := F3dVector(0.0,0.0,0.0);
	ViewDir := F3dVector(0.0,0.0,-1.0);
	ViewDirChanged := false;
end;

function GetRViewDir():TVector3f;
var Step1,Step3:SF3dVector;
    cosX,normv:extended;
    res:TVector3f;
begin
	//Rotate around Y-axis:
	Step1.x := cos( (RotateY + 90.0) * PI/180);
	Step1.z := -sin( (RotateY + 90.0) * PI/180);

  //Rotate around X-axis:
	cosX := cos (RotateX * PI/180);
	Step3.x := Step1.x * cosX;
	Step3.z := Step1.z * cosX;
	Step3.y := sin(RotateX * PI/180);
  //**
  normv:=1/(sqrt(sqr(Step3.x)+sqr(Step3.y)+sqr(Step3.z)));
  Step3.x:=Step3.x*normv;
  Step3.y:=Step3.y*normv;
  Step3.z:=Step3.z*normv;
  //**
  RViewDir := Step3;
  res[0]:=RViewDir.x;
  res[1]:=RViewDir.y;
  res[2]:=RViewDir.z;
  result:=res;
end;

procedure GetViewDir();
var Step1,Step2:SF3dVector;
    cosX,normv:extended;
begin
	//Rotate around Y-axis:
	Step1.x := cos( (RotateY + 90.0) * PI/180);
	Step1.z := -sin( (RotateY + 90.0) * PI/180);
	//Rotate around X-axis:
	cosX := cos (RotateX * PI/180);
	Step2.x := Step1.x ;//* cosX;
	Step2.z := Step1.z ;//* cosX;
	Step2.y := sin(RotateX * PI/180);
  //**
  normv:=1/(sqrt(sqr(Step2.x)+sqr(Step2.y)+sqr(Step2.z)));
  Step2.x:=Step2.x*normv;
  Step2.y:=Step2.y*normv;
  Step2.z:=Step2.z*normv;
  //**
	//Rotation around Z-axis not yet implemented, so:
	ViewDir := Step2;
end;

function SF3toNV3(Vec:SF3dVector):NVec3f;
var v:NVec3f;
begin
  v[0]:=Vec.x;
  v[1]:=Vec.y;
  v[2]:=Vec.z;
  SF3toNV3:=v;
end;

procedure MoveForwards(Distance:GLfloat;Newton:ZNewton);
begin
	if ViewDirChanged=true then GetViewDir();
	MoveVector.x := ViewDir.x * -Distance;
	//MoveVector.y := ViewDir.y * -Distance;
  MoveVector.y := 0.0;
	MoveVector.z := ViewDir.z * -Distance;
	//AddF3dVectorToVector(@Position, @MoveVector );
  //Newton^.SetMovement(SF3toNV3(MoveVector));
  Position := AddF3dVectors(Position,MoveVector);
end;

procedure StrafeRight(Distance:GLfloat;Newton:ZNewton);
begin
	if ViewDirChanged=true then GetViewDir();
	MoveVector.z := MoveVector.z -ViewDir.x * -Distance;
	MoveVector.y := 0.0;
	MoveVector.x := MoveVector.x + ViewDir.z * -Distance;
	//AddF3dVectorToVector(&Position, &MoveVector );
  //Newton^.SetMovement(SF3toNV3(MoveVector));
  Position := AddF3dVectors(Position,MoveVector);
end;

procedure KameraMoveKey(Frames:extended;Newton:ZNewton);
begin
{
case Key of
 'w':zpos:=zpos-1;
 's':zpos:=zpos+1;
 'a':xpos:=xpos-1;
 'd':xpos:=xpos+1;
end;}

if Frames<=1 then exit;

if getasynckeystate(ord(VK_LCONTROL)) <> 0 then begin duck:=true;position.y:=-6.4 end else begin duck:=false;position.y:=0; end;
if getasynckeystate(ord(VK_SHIFT)) <> 0 then begin run:=true; end else begin run:=false; end;

if duck=true then begin
  mspeed:=fixspeed*0.6;
end else begin
  mspeed:=fixspeed;
end;

if (run=true) and (duck=false) then begin
  mspeed:=fixspeed*2.5;
end;

{
if getasynckeystate(ord('W')) <> 0 then zpos:=zpos-mspeed/Frames;
if getasynckeystate(ord('S')) <> 0 then zpos:=zpos+mspeed/Frames;
if getasynckeystate(ord('A')) <> 0 then xpos:=xpos-mspeed/Frames;
if getasynckeystate(ord('D')) <> 0 then xpos:=xpos+mspeed/Frames;}

Newton^.SetMovement(V3(0,0,0));

MoveVector.x:=0;MoveVector.y:=0;MoveVector.z:=0;

if getasynckeystate(ord('W')) <> 0 then MoveForwards(-mspeed/Frames,Newton);
if getasynckeystate(ord('S')) <> 0 then MoveForwards(mspeed/Frames,Newton);
if getasynckeystate(ord('A')) <> 0 then StrafeRight(-mspeed/Frames,Newton);
if getasynckeystate(ord('D')) <> 0 then StrafeRight(mspeed/Frames,Newton);

Newton^.SetMovement(SF3toNV3(MoveVector));

end;

procedure Move(Direction:SF3dVector);
begin
	//AddF3dVectorToVector(&Position, &Direction );
  Position := AddF3dVectors(Position,Direction);
end;

procedure KameraMoveMouse(x,y:integer);
var dx,dy:integer;
    r:TRPos;
    p: TPoint;
begin
  p := Mouse.CursorPos;

  if switch=false then begin
    x1:=x;
    y1:=y;
    switch:=true;
  end;

  x2:=x;
  y2:=y;

  if (switch=true) and ((x1<>x2) or (y1<>y2)) then begin
    dx:=x2-x1;
    dy:=y2-y1;

    rotatey:=rotatey-dx/25;
    if (rotatex>=-90) and (rotatex<=90) then rotatex:=rotatex-dy/25 else begin
      if rotatex>90 then rotatex:=90;
      if rotatex<-90 then rotatex:=-90;
    end;

    //Move(F3dVector(dx/5,dy/5,0.0));

    p.X := mfestx;  //X-Wert und
    p.Y := mfesty;  //Y-Wert verändern
    Mouse.CursorPos := p;  //Neue Koordinaten übergeben

    switch:=false;
  end;

  ViewDirChanged:=true;

end;

procedure KameraDraw(Newton:ZNewton);
var m:TMatrix4f;
    test:string;
begin
  //gluLookAt(eyex,eyey,eyez,centerx,centery,centerz,upx,upy,upz);
  //gluLookAt(eyex,eyey,eyez,centerx,centery,centerz,0.9,0.8,0);
  //glRotatef(-rotatex , 0.0, 1.0, 0.0);
  //glRotatef(-rotatey , 1.0, 0.0, 0.0);
  //glTranslatef( -xpos, ypos, -zpos );
  glRotatef(-RotateX , 1.0, 0.0, 0.0);
	glRotatef(-RotateY , 0.0, 1.0, 0.0);
	//glRotatef(-0.0 , 0.0, 0.0, 1.0);
  m:=Newton^.GetCharMatrix;
  if (m[3,0]<>0) or (m[3,1]<>100) or (m[3,2]<>0) then begin
    test:='test';
  end;
  //glTranslatef( -Position.x, -Position.y, -Position.z );
  glTranslatef(-m[3,0], -m[3,1]-0.5, -m[3,2]);
  //glTranslatef(-m[3,0], 0, -m[3,2]);
end;

end.
