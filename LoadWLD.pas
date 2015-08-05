unit LoadWLD;

{$H+}

interface

uses Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs, dglOpenGL, StdCtrls,
      SDL, SDL_Image, Newtonpas, gl3DSMath, glMatrixHelper, NewtonImport;

type
  PVertex = ^TVertex;
  PNewton = ^TNewton;
  ZNewtonBody  = ^PNewtonBody;

  TVertex = packed record
    u,v,nx,ny,nz,vx,vy,vz:TGLFloat;
    //S,T,U,V,W,X,Y,Z : TGLFloat;
  end; //GL_T2F_N3F_V3F

  Tvector = record
    x,y,z:TGLFloat;
  end;

  Tuv = record
    u,v:TGLFloat;
  end;

  TFace = record
    vind1,vind2,vind3,vind4:integer;
    uv1,uv2,uv3,uv4:Tuv;
  end;

  TWLDObject = class
    VBO:GLuint;
    VBOPointer,VBOPointerX:PVertex;
    rx,ry,rz:extended;
    VertexAnzahl,FaceAnzahl,VertexDatenLaenge,Xrepeat,Yrepeat:integer;
    texid:gluint;
    texname:string;
    procedure Init;
    procedure AddTVertex(Vertex:TVertex;uv:Tuv;count:integer);
    procedure Render;
    procedure AssignTexture;
    procedure VBORenderFree;
  end;

  TWLD = class

    private
    WLDObjects:array of TWLDObject;
    anzobjects:integer;

    public
    function LoadWorld(name:string;Newton:PNewton):string;
    procedure Render;
  end;

  const
    pi=3.141592653589793238462643383279;
    Worldsize = 30;

  var
    buffer: array[1..64] of byte;
    World:TFileStream;
    TmpFace : array[0..3] of T3DPoint;

implementation

function ByteToStr(buffer:array of byte;count:integer):string;
var buff:string;
    i:integer;
begin
  buff:='';
  for i:=0 to count-1 do begin
    buff:=buff+chr(buffer[i]);
  end;
  ByteToStr:=buff;
end;

function ReadStr(length:integer):string;
begin
  if length>64 then exit;
  World.ReadBuffer(buffer,length);
  ReadStr:=Bytetostr(buffer,length);
end;

function ByteToFloat(buffer:array of byte):TGLFloat;
type
  Tbyte4 = array[1..4] of byte;
var
  b : Tbyte4; 
  x : single absolute b;
begin
  b[1] := buffer[0]; b[2] := buffer[1];
  b[3] := buffer[2]; b[4] := buffer[3];

  ByteToFloat:=x;
end;

function ReadFloat:TGLFloat;
begin
  World.ReadBuffer(buffer,4);
  ReadFloat:=ByteToFloat(buffer);
end;

function ByteToInt(buffer:array of byte):integer;
var a:integer;
begin
  a:=0;
  a:=a+buffer[3] shl 24;
  a:=a+buffer[2] shl 16;
  a:=a+buffer[1] shl 8;
  a:=a+buffer[0];
  ByteToInt:=a;
end;

function ReadInt:integer;
var buffer: array[1..4] of byte;
begin
  World.ReadBuffer(buffer,4);
  ReadInt:=ByteToint(buffer)
end;

function TWLD.LoadWorld(name:string;Newton:PNewton):string;
var aktobject,lauf,VertexAnzahl,FaceAnzahl,laufmax:integer;
    test:string;
    Face:array of TFace;
    Vertexe:array of TVertex;

    matrix4f,mat,rmat,tmat,smat:TMatrix4f;
    Min     : TVector3f;
    Max     : TVector3f;
    m       : Integer;
    f       : Word;
begin

  World:=TFileStream.Create(name, fmOpenRead);
  test:='';
  test:=ReadStr(4);
  if test<>'WLDF' then begin
    showmessage('Not a valid .wld File -> '+test);
    World.Free;
    LoadWorld:='WLDF Not Found.';
    exit;
  end;

  anzobjects:=ReadInt;
  //anzobjects:=1;
  setlength(WLDObjects,anzobjects);
  setlength(Newton^.CollTreeWLD,anzobjects);
  setlength(Newton^.BodyWLD,anzobjects);

  laufmax:=anzobjects-1;

  for aktobject:=0 to laufmax do begin

    WLDObjects[aktobject]:=TWLDObject.Create;

    test:=ReadStr(4);
    if test<>'TexT' then begin
      showmessage('TexT Not Found -> '+test);
      World.Free;
      LoadWorld:='TexT Not Found.';
      exit;
    end;

    //Name der Textur ermitteln
    test:=ReadStr(32);
    test:=StringReplace(test, '!', '', [rfReplaceAll, rfIgnoreCase]);
    WLDObjects[aktobject].texname:=test;
    test:='';

    WLDObjects[aktobject].Xrepeat:=ReadInt;
    WLDObjects[aktobject].Yrepeat:=ReadInt;
    (*
    test:=ReadStr(4);
    if test<>'LRS:' then begin
      showmessage('LRS: Not Found -> '+test);
      World.Free;
      LoadWorld:='LRS: Not Found.';
      exit;
    end;

    WLDObjects[aktobject].Loc.x:=ReadFloat;
    WLDObjects[aktobject].Loc.y:=ReadFloat;
    WLDObjects[aktobject].Loc.z:=ReadFloat;

    WLDObjects[aktobject].Rot.x:=ReadFloat;
    WLDObjects[aktobject].Rot.y:=ReadFloat;
    WLDObjects[aktobject].Rot.z:=ReadFloat;

    WLDObjects[aktobject].Scale.x:=ReadFloat;
    WLDObjects[aktobject].Scale.y:=ReadFloat;
    WLDObjects[aktobject].Scale.z:=ReadFloat;*)

    test:=ReadStr(4);
    if test<>'Vert' then begin
      showmessage('Vert Not Found -> '+test);
      World.Free;
      LoadWorld:='Vert Not Found.';
      exit;
    end;

    //Anzahl der Vertices ermitteln
    VertexAnzahl:=ReadInt;

    setlength(Vertexe,VertexAnzahl);

    //Vertex-Werte Resetten
    for lauf:=0 to VertexAnzahl-1 do begin
      Vertexe[lauf].u:=0;
      Vertexe[lauf].v:=0;
      Vertexe[lauf].vx:=0;
      Vertexe[lauf].vy:=0;
      Vertexe[lauf].vz:=0;
      Vertexe[lauf].nx:=0;
      Vertexe[lauf].ny:=0;
      Vertexe[lauf].nz:=0;
    end;

    //Alle Vertexe für das Object einlesen.
    for lauf:=0 to VertexAnzahl-1 do begin
      Vertexe[lauf].vx:=ReadFloat;
      Vertexe[lauf].vy:=ReadFloat;
      Vertexe[lauf].vz:=ReadFloat;
    end;

    test:=ReadStr(4);
    if test<>'Norm' then begin
      showmessage('Norm Not Found -> '+test);
      World.Free;
      LoadWorld:='Norm Not Found.';
      exit;
    end;

    //Unnötiger check ;)
    if ReadInt<>VertexAnzahl then showmessage('Anzahl der Vertex ungleich Anzahl der Normalen');

    //NormalenVektoren einlesen
    for lauf:=0 to VertexAnzahl-1 do begin
      Vertexe[lauf].nx:=ReadFloat;
      Vertexe[lauf].ny:=ReadFloat;
      Vertexe[lauf].nz:=ReadFloat;
    end;

    test:=ReadStr(4);
    if test<>'FVIN' then begin
      showmessage('FVIN Not Found -> '+test);
      World.Free;
      LoadWorld:='FVIN Not Found.';
      exit;
    end;

    FaceAnzahl:=Readint;
    WLDObjects[aktobject].FaceAnzahl:=FaceAnzahl;

    WLDObjects[aktobject].VertexAnzahl:=4*FaceAnzahl;

    WLDObjects[aktobject].Init;

    setlength(Face,FaceAnzahl);

    //Face werte resetten
    for lauf:=0 to FaceAnzahl-1 do begin
      Face[lauf].vind1:=0;
      Face[lauf].vind2:=0;
      Face[lauf].vind3:=0;
      Face[lauf].vind4:=0;

      Face[lauf].uv1.u:=0;
      Face[lauf].uv1.v:=0;

      Face[lauf].uv2.u:=0;
      Face[lauf].uv2.v:=0;

      Face[lauf].uv3.u:=0;
      Face[lauf].uv3.v:=0;

      Face[lauf].uv4.u:=0;
      Face[lauf].uv4.v:=0;
    end;

    //Add VertexIndex to Face Variable
    for lauf:=0 to FaceAnzahl-1 do begin
      Face[lauf].vind1:=Readint;
      Face[lauf].vind2:=Readint;
      Face[lauf].vind3:=Readint;
      Face[lauf].vind4:=Readint;
    end;

    test:=ReadStr(4);
    if test<>'UVCO' then begin
      showmessage('UVCO Not Found -> '+test);
      World.Free;
      LoadWorld:='UVCO Not Found.';
      exit;
    end;

    //Unnötiger check Nr.2 ;)
    if ReadInt<>FaceAnzahl then showmessage('Anzahl der Vertex ungleich Anzahl der Normalen');

    //Add UVCoordinates to Face Variable
    for lauf:=0 to FaceAnzahl-1 do begin
      Face[lauf].uv1.u:=ReadFloat;
      //showmessage(floattostr(Face[lauf].uv1.u));
      Face[lauf].uv1.v:=1-ReadFloat;

      Face[lauf].uv2.u:=ReadFloat;
      Face[lauf].uv2.v:=1-ReadFloat;

      Face[lauf].uv3.u:=ReadFloat;
      Face[lauf].uv3.v:=1-ReadFloat;

      Face[lauf].uv4.u:=ReadFloat;
      Face[lauf].uv4.v:=1-ReadFloat;
    end;

    Newton^.CollTreeWLD[aktobject] := NewtonCreateTreeCollision(Newton^.NewtonWorld,0);
    NewtonTreeCollisionBeginBuild(Newton^.CollTreeWLD[aktobject]);

    for lauf:=0 to FaceAnzahl-1 do begin
      WLDObjects[aktobject].AddTVertex(Vertexe[Face[lauf].vind1],Face[lauf].uv1,0);
      WLDObjects[aktobject].AddTVertex(Vertexe[Face[lauf].vind2],Face[lauf].uv2,1);
      WLDObjects[aktobject].AddTVertex(Vertexe[Face[lauf].vind3],Face[lauf].uv3,2);
      WLDObjects[aktobject].AddTVertex(Vertexe[Face[lauf].vind4],Face[lauf].uv4,3);
      NewtonTreeCollisionAddFace(Newton^.CollTreeWLD[aktobject], 4, @TmpFace, SizeOf(T3DPoint), 1);
    end;

    WLDObjects[aktobject].VBORenderFree;

    WLDObjects[aktobject].Render;

    //Textur dann laden
    WLDObjects[aktobject].AssignTexture;

    test := WLDObjects[aktobject].texname;

    NewtonTreeCollisionEndBuild(Newton^.CollTreeWLD[aktobject], 1);

    Newton^.BodyWLD[aktobject] := NewtonCreateBody(Newton^.NewtonWorld, Newton^.CollTreeWLD[aktobject]);

    Matrix_SetIdentity(mat);
    NewtonBodySetMatrix(Newton^.BodyWLD[aktobject], @mat[0,0]);

    // Get AABB and set limits of the newton world
    NewtonCollisionCalculateAABB(Newton^.CollTreeWLD[aktobject], @mat[0,0], @Min[0], @Max[0]);
    //NewtonSetWorldSize(NewtonWorld, @Min[0], @Max[0]);
    NewtonReleaseCollision(Newton^.NewtonWorld, Newton^.CollTreeWLD[aktobject]);
  end;

  World.Free;

end;

procedure TWLD.Render;
var lauf:integer;
begin
  for lauf:=0 to anzobjects-1 do begin
    WLDObjects[lauf].Render;
  end;
end;

procedure TWLDObject.Init;
begin
  VertexDatenLaenge:=0;
  //Zunächst holen wir eine gültige ID (VBO=int) für das VertexBufferObject
  glGenBuffers(1,@VBO);

  //Danach Binden wir das VBO, und aktivieren es
  glBindBufferARB(GL_ARRAY_BUFFER, VBO);
  glEnableClientState(GL_VERTEX_ARRAY);

  //OpenGL mitteilen wieviel Speicherplatz wir im VRAM benötigen, sowie GL_STATIC_DRAW (=static, nicht mehr veränderbar)
  glBufferDataARB(GL_ARRAY_BUFFER, VertexAnzahl*SizeOf(TVertex), nil, GL_STATIC_DRAW);

  VBOPointer:=glMapBuffer(GL_ARRAY_BUFFER, GL_WRITE_ONLY);
end;

procedure TWLDObject.Render;
begin
  glEnable(GL_TEXTURE_2D);
	glBindTexture(GL_TEXTURE_2D, texid);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);

  glPushMatrix();

    //WICHTIG! wurde im Tutorial net erwähnt D:, VBO erneut binden um aus dem VRAM das RICHTIGE Obj zu rendern!
    glBindBufferARB(GL_ARRAY_BUFFER, VBO);

    glInterleavedArrays(GL_T2F_N3F_V3F, SizeOf(TVertex), nil);
    glDrawArrays(GL_QUADS, 0, VertexDatenLaenge);
  glPopMatrix();
end;

procedure TWLDObject.AddTVertex(Vertex:TVertex;uv:Tuv;count:integer);
begin
  VBOPointerX:=VBOPointer;

  TmpFace[count].x:=Vertex.vx*Worldsize;
  TmpFace[count].y:=Vertex.vy*Worldsize;
  TmpFace[count].z:=Vertex.vz*Worldsize;

  //VBOPointerX^.u:=uv.u;
  //VBOPointerX^.v:=uv.v;

  VBOPointerX^.u:=uv.u*Xrepeat;
  VBOPointerX^.v:=uv.v*Yrepeat;

  VBOPointerX^.nx:=Vertex.nx;
  VBOPointerX^.ny:=Vertex.ny;
  VBOPointerX^.nz:=Vertex.nz;
  VBOPointerX^.vx:=Vertex.vx;
  VBOPointerX^.vy:=Vertex.vy;
  VBOPointerX^.vz:=Vertex.vz;

  inc(Integer(VBOPointer), SizeOf(TVertex));

  inc(VertexDatenLaenge);
end;

procedure TWLDObject.AssignTexture;
var tex : PSDL_Surface;
    appdir,test:string;
    maxAni:integer;
begin
  appdir:=ExtractFileDir(paramStr(0));
  test:=appdir+'\Models\Worlds\Textures\'+texname;
  tex := IMG_Load(PCHAR(test));

  //tex := IMG_Load('test2.jpg');
  if assigned(tex) then
  begin
    glGenTextures(1, @TexID);
    maxAni:=0;
    glGetFloatv( GL_MAX_TEXTURE_MAX_ANISOTROPY_EXT, @maxAni );
    glBindTexture(GL_TEXTURE_2D, TexID);
    //maxAni:=4;

    //glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    //glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameterf( GL_TEXTURE_2D, GL_TEXTURE_MAX_ANISOTROPY_EXT, maxAni );
 
    // Achtung! Einige Bildformate erwarten statt GL_RGB, GL_BGR. Diese Konstante fehlt in den Standard-Headern
    //  GL_RGB bei JPG
    //  GL_BGR bei BMP
    if copy(texname,length(texname)-2,3)='bmp' then begin
      glTexImage2D(GL_TEXTURE_2D, 0, 3, tex^.w, tex^.h,0, GL_BGR, GL_UNSIGNED_BYTE, tex^.pixels); end else begin
      glTexImage2D(GL_TEXTURE_2D, 0, 3, tex^.w, tex^.h,0, GL_RGB, GL_UNSIGNED_BYTE, tex^.pixels);
    end;

    SDL_FreeSurface(tex);
  end;
end;

procedure TWLDObject.VBORenderFree;
begin
  glUnMapBuffer(GL_ARRAY_BUFFER);
end;

end.
