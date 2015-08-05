unit Light;

interface

uses Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs, dglOpenGL, StdCtrls,
      SDL, SDL_Image;

type
  lightdata = record
    pos,diffuse,ambient: array[0..3] of extended;
    constantAttenuation,
    linearAttenuation,
    quadraticAttenuation,
    brightness:extended;
  end;

  TLight = class(TObject)

  private
  lend:boolean;

  function lightBrightnessCompare(a,b:lightdata):integer;
  function createlight(x,y,z,Dr,Dg,Db,Ar,Ag,Ab,cA,lA,qA:extended):char;

  public

  procedure Initialisieren;

  end;

  const
  MAX_LIGHTS = 1000;

  var
  lightP: array[0..MAX_LIGHTS-1] of lightdata;
  num_lights:integer;


implementation

procedure TLight.Initialisieren;
begin
  num_lights:=0;
end;

function TLight.lightBrightnessCompare(a,b:lightdata):integer;
var diff:GLfloat;
begin
  diff:= b.brightness - a.brightness;

  if (diff>0) then begin
    lightBrightnessCompare:=1;
    exit;
  end;
  if (diff<0) then begin
    lightBrightnessCompare:=-1;
    exit;
  end;
  lightBrightnessCompare:=0;
end;

function TLight.createlight(x,y,z,Dr,Dg,Db,Ar,Ag,Ab,cA,lA,qA:extended):char;
begin
  lightP[num_lights].pos[0]:=x;
  lightP[num_lights].pos[1]:=y;
  lightP[num_lights].pos[2]:=z;
  lightP[num_lights].pos[3]:=1.0;

  lightP[num_lights].diffuse[0]:=Dr;
  lightP[num_lights].diffuse[1]:=Dg;
  lightP[num_lights].diffuse[2]:=Db;
  lightP[num_lights].diffuse[3]:=1.0;

  lightP[num_lights].ambient[0]:=Ar;
  lightP[num_lights].ambient[1]:=Ag;
  lightP[num_lights].ambient[2]:=Ab;
  lightP[num_lights].ambient[3]:=1.0;

  lightP[num_lights].constantAttenuation:=cA;
 	lightP[num_lights].linearAttenuation:=lA;
 	lightP[num_lights].quadraticAttenuation:=qA;

  num_lights:=num_lights+1;
  createlight:='1';
end;

end.
