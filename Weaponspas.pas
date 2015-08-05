unit Weaponspas;

interface

uses Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs, dglOpenGL, StdCtrls,
      SDL, SDL_Image, inifiles, LoadMDL;

type

  TWeapons = class(TObject)

  private
  WModel:TMDL;
  Animationlength: array of integer;
  names: array of string;
  ammo,nameanzahl:integer;
  shot:boolean;

  public
  shottime,reloadtime:extended;
  ammomax:integer;
  mclick,reload,physicshot:boolean;
  procedure Initialisieren;
  procedure LoadWeapon(name:string);
  procedure Draw;
  procedure mclickp;
  procedure reloadp;
  procedure AdvanceAnimation(dt,dtmax:extended);
  end;

  var
  lend:boolean;

implementation

procedure TWeapons.Initialisieren;
begin  
  ammo:=ammomax;
  mclick:=false;
  shot:=false;
  physicshot:=false;
end;

procedure TWeapons.LoadWeapon(name:string);
var ini:TIniFile;
    lauf:integer;
    filee,test:string;
begin
  test:=ExtractFilePath(ParamStr(0))+'Models\Weapons\'+name+'\variables.ini';
  ini:=TIniFile.create(ExtractFilePath(ParamStr(0))+'Models\Weapons\'+name+'\variables.ini');
  try
    ammomax:=ini.readinteger('Variables','ammomax',0);
    shottime:=ini.ReadFloat('Variables','shottime',0.0);
    reloadtime:=ini.ReadFloat('Variables','reloadtime',0.0);
  finally
    ini.free;
  end;

  WModel:=TMDL.Create;
  WModel.LoadModel(ExtractFilePath(ParamStr(0))+'Models\Weapons\'+name+'\weapon.mdl');
  WModel.SetFrame(1,1);
  WModel.AdvanceAnimation(1,1.00001);

  setlength(Animationlength,4);

  ini:=TIniFile.create(ExtractFilePath(ParamStr(0))+'Models\Weapons\'+name+'\animation.ini');
  try
    Animationlength[0]:=ini.readinteger('Animation','still',0);
    Animationlength[1]:=ini.readinteger('Animation','shoot',0);
    Animationlength[2]:=ini.readinteger('Animation','empty',0);
    Animationlength[3]:=ini.readinteger('Animation','reload',0);
  finally
    ini.free;
  end;
end;

procedure TWeapons.reloadp;
begin
  if (shot=false) and (mclick=false) and (reload=false) then begin
    WModel.SetFrame(Animationlength[0]+Animationlength[1]+Animationlength[2]+1,Animationlength[0]+Animationlength[1]+Animationlength[2]+Animationlength[3]);
    reload:=true;
  end;
end;

procedure TWeapons.mclickp;
begin
  if (reload=false) and (ammo>0) and (mclick=false) then begin
    WModel.SetFrame(Animationlength[0]+1,Animationlength[0]+Animationlength[1]);
    mclick:=true;
  end;
end;

procedure TWeapons.Draw;
begin
  WModel.Render;
end;

procedure TWeapons.AdvanceAnimation(dt,dtmax:extended);
begin

  if (mclick=true) and (ammo>0) and (reload=false) then begin
    if WModel.AdvanceAnimation(dt,dtmax*shottime) = true then begin
      mclick:=false;//shot:=false;
      WModel.SetFrame(1,Animationlength[0]);
      WModel.AdvanceAnimation(1,1.00001);
      ammo:=ammo-1;
      physicshot:=false;
      if ammo<=0 then begin
        WModel.SetFrame(Animationlength[0]+Animationlength[1]+1,Animationlength[0]+Animationlength[1]+Animationlength[2]);
        WModel.AdvanceAnimation(1,1.00001);
      end;
    end; //else shot:=true;
  end;

  if (reload=true) and (mclick=false) then begin

      if WModel.AdvanceAnimation(dt,dtmax*reloadtime) = true then begin
        reload:=false;
        WModel.SetFrame(1,Animationlength[0]);
        WModel.AdvanceAnimation(1,1);
        ammo:=ammomax;
        physicshot:=false;
      end;
  end;

end;

end.
