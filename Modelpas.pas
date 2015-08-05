unit Modelpas;

interface

uses Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs, dglOpenGL, StdCtrls,
      SDL, SDL_Image, Newtonpas, LoadMDL, LoadWLD, glMatrixHelper;

//procedure InitNewton;

type

  TModel = class(TObject)

  private
  Model:TMDL;
  ModelID:integer;
  Newton:PNewton;

  public
  procedure LoadModel(name,boundingtype:string;physik:boolean;mass:single;Newton_:PNewton);
  procedure Render;
  end;

  //const

  //var

implementation

procedure TModel.LoadModel(name,boundingtype:string;physik:boolean;mass:single;Newton_:PNewton);
var test:string;
    size,position:TVector3f;
begin
  Newton:=Newton_;

  test:=ExtractFilePath(ParamStr(0))+'Models\Models\'+name;

  Model:=TMDL.Create;
  Model.LoadModel(test+'\model.mdl');

  size[0]:=Model.xmax-Model.xmin;
  size[1]:=Model.ymax-Model.ymin;
  size[2]:=Model.zmax-Model.zmin;

  Model.xcor:=(Model.xmin+size[0]/2)*(-1);
  Model.ycor:=(Model.ymin+size[1]/2)*(-1);
  Model.zcor:=(Model.zmin+size[2]/2)*(-1);

  position[0]:=0;
  position[1]:=+10;
  position[2]:=-100;

  if (physik=true) then begin
    ModelID:=Newton^.AddObject(boundingtype,size,position,mass);
  end;
end;

procedure TModel.Render;
var Matrix:TMatrix4f;
begin
  Matrix:=Newton^.GetObjMatrix(ModelID);

  glPushMatrix;
    glMultMatrixf(@Matrix[0,0]);
    Model.Render;
  glPopMatrix;
end;

end.
