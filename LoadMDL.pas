unit LoadMDL;

{$H+}

interface

uses Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs, dglOpenGL, StdCtrls,
      SDL, SDL_Image, Newtonpas, gl3DSMath, glMatrixHelper;

type
  PVertex = ^TVertex;
  //PNewton = ^TNewton;
  //ZNewtonBody  = ^PNewtonBody;

  TVertex = packed record
    u,v,nx,ny,nz,vx,vy,vz:TGLFloat;
  end; //GL_T2F_N3F_V3F

  TFrames = record
    vertices: array of TVertex;
  end;

  TArrMatrix = array [0..15] of GLdouble;

  Tvector = record
    x,y,z:TGLFloat;
  end;

  Tuv = record
    u,v:TGLFloat;
  end;

  TFace = record
    vind:array[1..4] of integer;
    uv:array[1..4] of Tuv;
  end;

  TWLDObject = class
    VBO:GLuint;
    VBOPointer,VBOPointerX:PVertex;
    rx,ry,rz:extended;
    VertexAnzahl,FaceAnzahl,VertexDatenLaenge,Xrepeat,Yrepeat,FrameCount:integer;
    texid:gluint;
    texname:string;
    Faces: array of TFace;
    static,uvset:boolean;
    Frames: array of TFrames;
    Vertexe:array of TVertex;
    Vertex:array of TVertex;
    procedure Init;
    procedure AddTVertex(Vertex2:TVertex;uv:Tuv;count:integer);
    procedure Render;
    procedure AssignTexture;
    procedure VBORenderFree;
    procedure SetFrameVert(frame1,frame2:integer;frac:extended);
  end;

  TMDL = class

    private
    WLDObjects:array of TWLDObject;
    anzobjects:integer;
    startfr,endfr,frameIndex1,frameIndex2:integer;
    frac,time:extended;

    public
    xcor,ycor,zcor:single;
    xmin,xmax,ymin,ymax,zmin,zmax:TGLFloat;
    function LoadModel(name:string):string;
    procedure Render;
    procedure SetFrame(start,ende:integer);
    function AdvanceAnimation(dt,dtmax:extended):boolean;
  end;

  const
    pi=3.141592653589793238462643383279;

  var
    buffer: array[1..64] of byte;
    //World:TFileStream;
    World_Dat:TFileStream;
    World:TMemoryStream;
    TmpFace : array[0..3] of T3DPoint;
    VertexData:integer;

implementation

function TArrMatrix2TMatrix4f(ArrMatrix:TArrMatrix):TMatrix4f;
var m:TMatrix4f;
    lauf,l2:integer;
begin
  l2:=0;
  for lauf:=0 to 15 do begin
    m[l2,lauf-4*l2]:=ArrMatrix[lauf];
    if ((lauf+1) MOD 4) = 0 then begin
      l2:=l2+1;
    end;
  end;
  TArrMatrix2TMatrix4f:=m;
end;

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

function TMDL.LoadModel(name:string):string;
var aktobject,lauf,lauf2,VertexAnzahl,FaceAnzahl,laufmax:integer;
    test:string;
    texture:bool;
    buffer:array of byte;
    //Face:array of TFace;
    //Vertexe:array of TVertex;
begin
  startfr:=0;
  endfr:=0;
  time:=0;
  xcor:=0;
  ycor:=0;
  zcor:=0;

  //Model Datei wird in einem Rutsch in den RAM geladen und dann erst "ausgelesen.
  //Dadurch muss nicht ständig auf die Festplatte zugegriffen werden
  //-> VIEEL SCHNELLER :)
  World_Dat:=TFileStream.Create(name, fmOpenRead);
  World:=TMemoryStream.Create;
  setlength(buffer,World_Dat.Size);
  World_Dat.Read(buffer[0],World_Dat.Size);
  World.Write(buffer[0],World_Dat.Size);
  World.Seek(0,0);
  World_Dat.Free;

  test:='';
  test:=ReadStr(4);
  if test<>'MDLF' then begin
    showmessage('Not a valid .mdl File -> '+test);
    World.Free;
    LoadModel:='MDLF Not Found.';
    exit;
  end;

  anzobjects:=ReadInt;
  //anzobjects:=1;
  setlength(WLDObjects,anzobjects);

  laufmax:=anzobjects-1;

  xmin:=100000000000000;
  xmax:=-100000000000000;
  ymin:=100000000000000;
  ymax:=-100000000000000;
  zmin:=100000000000000;
  zmax:=-100000000000000;

  for aktobject:=0 to laufmax do begin

    WLDObjects[aktobject]:=TWLDObject.Create;
    WLDObjects[aktobject].uvset:=false;

    test:=ReadStr(4);
    if (test<>'TexT') and (test<>'NoTX') then begin
      showmessage('TexT or NoTX Not Found -> '+test);
      World.Free;
      LoadModel:='TexT or NoTX Not Found.';
      exit;
    end;

    if test='TexT' then texture:=true
      else texture:=false;

    if texture=true then begin
      //Name der Textur ermitteln
      test:=ReadStr(32);
      test:=StringReplace(test, '!', '', [rfReplaceAll, rfIgnoreCase]);
      WLDObjects[aktobject].texname:=test;
      test:='';

      WLDObjects[aktobject].Xrepeat:=ReadInt;
      WLDObjects[aktobject].Yrepeat:=ReadInt;
    end else begin
      //R:
      ReadFloat;
      //G:
      ReadFloat;
      //B:
      ReadFloat;
      WLDObjects[aktobject].texname:='notex.jpg';
    end;

    test:=ReadStr(4);
    if test<>'Vert' then begin
      showmessage('Vert Not Found -> '+test);
      World.Free;
      LoadModel:='Vert Not Found.';
      exit;
    end;

    //Anzahl der Vertices ermitteln
    VertexAnzahl:=ReadInt;

    //setlength(Vertexe,VertexAnzahl);
    setlength(WLDObjects[aktobject].Vertexe,VertexAnzahl);

    //Alle Vertexe für das Object einlesen.
    for lauf:=0 to VertexAnzahl-1 do begin
      WLDObjects[aktobject].Vertexe[lauf].vx:=ReadFloat;
      WLDObjects[aktobject].Vertexe[lauf].vy:=ReadFloat;
      WLDObjects[aktobject].Vertexe[lauf].vz:=ReadFloat;
      if WLDObjects[aktobject].Vertexe[lauf].vx<xmin then xmin:=WLDObjects[aktobject].Vertexe[lauf].vx;
      if WLDObjects[aktobject].Vertexe[lauf].vx>xmax then xmax:=WLDObjects[aktobject].Vertexe[lauf].vx;
      if WLDObjects[aktobject].Vertexe[lauf].vy<ymin then ymin:=WLDObjects[aktobject].Vertexe[lauf].vy;
      if WLDObjects[aktobject].Vertexe[lauf].vy>ymax then ymax:=WLDObjects[aktobject].Vertexe[lauf].vy;
      if WLDObjects[aktobject].Vertexe[lauf].vz<zmin then zmin:=WLDObjects[aktobject].Vertexe[lauf].vz;
      if WLDObjects[aktobject].Vertexe[lauf].vz>zmax then zmax:=WLDObjects[aktobject].Vertexe[lauf].vz;
    end;

    test:=ReadStr(4);
    if test<>'Norm' then begin
      showmessage('Norm Not Found -> '+test);
      World.Free;
      LoadModel:='Norm Not Found.';
      exit;
    end;

    //Unnötiger check ;)
    if ReadInt<>VertexAnzahl then showmessage('Anzahl der Vertex ungleich Anzahl der Normalen (1)');

    //NormalenVektoren einlesen
    for lauf:=0 to VertexAnzahl-1 do begin
      WLDObjects[aktobject].Vertexe[lauf].nx:=ReadFloat;
      WLDObjects[aktobject].Vertexe[lauf].ny:=ReadFloat;
      WLDObjects[aktobject].Vertexe[lauf].nz:=ReadFloat;
    end;

    test:=ReadStr(4);
    if test<>'FVIN' then begin
      showmessage('FVIN Not Found -> '+test);
      World.Free;
      LoadModel:='FVIN Not Found.';
      exit;
    end;

    FaceAnzahl:=Readint;
    WLDObjects[aktobject].FaceAnzahl:=FaceAnzahl;

    WLDObjects[aktobject].VertexAnzahl:=4*FaceAnzahl;

    WLDObjects[aktobject].Init;

    setlength(WLDObjects[aktobject].Faces,FaceAnzahl);

    //Add VertexIndex to Face Variable
    for lauf:=0 to FaceAnzahl-1 do begin
      WLDObjects[aktobject].Faces[lauf].vind[1]:=Readint;
      WLDObjects[aktobject].Faces[lauf].vind[2]:=Readint;
      WLDObjects[aktobject].Faces[lauf].vind[3]:=Readint;
      WLDObjects[aktobject].Faces[lauf].vind[4]:=Readint;
    end;

    test:=ReadStr(4);
    if test='NOFR' then WLDObjects[aktobject].static:=true;
    if test='FRAM' then begin
      WLDObjects[aktobject].FrameCount:=Readint;
      setlength(WLDObjects[aktobject].Frames,WLDObjects[aktobject].FrameCount);
      for lauf:=0 to WLDObjects[aktobject].FrameCount-1 do begin
      setlength(WLDObjects[aktobject].Frames[lauf].vertices,VertexAnzahl);
        for lauf2:=0 to VertexAnzahl-1 do begin
          WLDObjects[aktobject].Frames[lauf].vertices[lauf2].vx:=ReadFloat;
          WLDObjects[aktobject].Frames[lauf].vertices[lauf2].vy:=ReadFloat;
          WLDObjects[aktobject].Frames[lauf].vertices[lauf2].vz:=ReadFloat;
          WLDObjects[aktobject].Frames[lauf].vertices[lauf2].nx:=ReadFloat;
          WLDObjects[aktobject].Frames[lauf].vertices[lauf2].ny:=ReadFloat;
          WLDObjects[aktobject].Frames[lauf].vertices[lauf2].nz:=ReadFloat;
        end;
      end;
    end;
    if (test<>'FRAM') and (test<>'NOFR') then begin
      showmessage('NOFR/FRAM Not Found -> '+test);
      World.Free;
      LoadModel:='NOFR/FRAM Not Found.';
      exit;
    end;

    if texture=true then begin
      test:=ReadStr(4);
    end else begin
      test:='UVCO';
    end;

    if (test<>'UVCO') then begin
      showmessage('UVCO Not Found -> '+test);
      World.Free;
      LoadModel:='UVCO Not Found.';
      exit;
    end;

    //Unnötiger check Nr.2 ;)
    if (texture=true) then begin
      if (ReadInt<>FaceAnzahl) then showmessage('Anzahl der Vertex ungleich Anzahl der Faces');
    end;

    if texture=true then begin
      //Add UVCoordinates to Face Variable
      for lauf:=0 to FaceAnzahl-1 do begin
        WLDObjects[aktobject].Faces[lauf].uv[1].u:=ReadFloat;
        WLDObjects[aktobject].Faces[lauf].uv[1].v:=1-ReadFloat;

        WLDObjects[aktobject].Faces[lauf].uv[2].u:=ReadFloat;
        WLDObjects[aktobject].Faces[lauf].uv[2].v:=1-ReadFloat;

        WLDObjects[aktobject].Faces[lauf].uv[3].u:=ReadFloat;
        WLDObjects[aktobject].Faces[lauf].uv[3].v:=1-ReadFloat;

        WLDObjects[aktobject].Faces[lauf].uv[4].u:=ReadFloat;
        WLDObjects[aktobject].Faces[lauf].uv[4].v:=1-ReadFloat;
      end;
    end else begin
      for lauf:=0 to FaceAnzahl-1 do begin
        WLDObjects[aktobject].Faces[lauf].uv[1].u:=0;
        WLDObjects[aktobject].Faces[lauf].uv[1].v:=0;

        WLDObjects[aktobject].Faces[lauf].uv[2].u:=1;
        WLDObjects[aktobject].Faces[lauf].uv[2].v:=0;

        WLDObjects[aktobject].Faces[lauf].uv[3].u:=1;
        WLDObjects[aktobject].Faces[lauf].uv[3].v:=1;

        WLDObjects[aktobject].Faces[lauf].uv[4].u:=0;
        WLDObjects[aktobject].Faces[lauf].uv[4].v:=1;
      end;
    end;

    for lauf:=0 to FaceAnzahl-1 do begin
      WLDObjects[aktobject].AddTVertex(WLDObjects[aktobject].Vertexe[WLDObjects[aktobject].Faces[lauf].vind[1]],WLDObjects[aktobject].Faces[lauf].uv[1],0);
      WLDObjects[aktobject].AddTVertex(WLDObjects[aktobject].Vertexe[WLDObjects[aktobject].Faces[lauf].vind[2]],WLDObjects[aktobject].Faces[lauf].uv[2],1);
      WLDObjects[aktobject].AddTVertex(WLDObjects[aktobject].Vertexe[WLDObjects[aktobject].Faces[lauf].vind[3]],WLDObjects[aktobject].Faces[lauf].uv[3],2);
      WLDObjects[aktobject].AddTVertex(WLDObjects[aktobject].Vertexe[WLDObjects[aktobject].Faces[lauf].vind[4]],WLDObjects[aktobject].Faces[lauf].uv[4],3);
    end;

    WLDObjects[aktobject].VBORenderFree;

    WLDObjects[aktobject].Render;

    //if texture=true then begin
      //Textur dann laden
    WLDObjects[aktobject].AssignTexture;
    //end;

    setlength(WLDObjects[aktobject].Vertex,WLDObjects[aktobject].VertexDatenLaenge);

    test := WLDObjects[aktobject].texname;
  end;

  World.Free;

end;

procedure TMDL.Render;
var lauf:integer;
begin
  glPushMatrix();
    gltranslatef(xcor,ycor,zcor);
    for lauf:=0 to anzobjects-1 do begin
      WLDObjects[lauf].Render;
    end;
  glPopMatrix();
end;

procedure TWLDObject.Init;
begin
  static:=true;
  VertexDatenLaenge:=0;

  //Zunächst holen wir eine gültige ID (VBO=int) für das VertexBufferObject
  glGenBuffers(1,@VBO);

  //Danach Binden wir das VBO, und aktivieren es
  glBindBufferARB(GL_ARRAY_BUFFER, VBO);
  glEnableClientState(GL_VERTEX_ARRAY);

  //OpenGL mitteilen wieviel Speicherplatz wir im VRAM benötigen, sowie DYNAMIC_DRAW
  glBufferDataARB(GL_ARRAY_BUFFER, VertexAnzahl*SizeOf(TVertex), nil, GL_DYNAMIC_DRAW);

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

procedure TWLDObject.AddTVertex(Vertex2:TVertex;uv:Tuv;count:integer);
begin
  VBOPointerX:=VBOPointer;

  VBOPointerX^.u:=uv.u*Xrepeat;
  VBOPointerX^.v:=uv.v*Yrepeat;

  VBOPointerX^.nx:=Vertex2.nx;
  VBOPointerX^.ny:=Vertex2.ny;
  VBOPointerX^.nz:=Vertex2.nz;
  VBOPointerX^.vx:=Vertex2.vx;
  VBOPointerX^.vy:=Vertex2.vy;
  VBOPointerX^.vz:=Vertex2.vz;

  inc(Integer(VBOPointer), SizeOf(TVertex));

  inc(VertexDatenLaenge);
end;

procedure TWLDObject.AssignTexture;
var tex : PSDL_Surface;
    appdir,test:string;
    maxAni:integer;
begin
  appdir:=ExtractFileDir(paramStr(0));
  test:=appdir+'\Models\Models\Textures\'+texname;
  tex := IMG_Load(PCHAR(test));

  //tex := IMG_Load('test2.jpg');
  if assigned(tex) then
  begin		
    glGenTextures(1, @TexID);
    maxAni:=0;
    glGetFloatv( GL_MAX_TEXTURE_MAX_ANISOTROPY_EXT, @maxAni );
    glBindTexture(GL_TEXTURE_2D, TexID);
    maxAni:=4;

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

procedure TMDL.SetFrame(start,ende:integer);
begin
  startfr:=start;
  endfr:=ende;
end;

function TMDL.AdvanceAnimation(dt,dtmax:extended):boolean;
var lauf:integer;
begin
  if (dt<0) or (dt>dtmax) then exit;

  if (frameIndex1=endfr) then begin
      AdvanceAnimation:=true;
    end else begin
      AdvanceAnimation:=false;
    end;

    if (time<1-(dt/dtmax)) then begin
      time:= time + (dt/dtmax);
    end else begin
      time:=0;
    end;

  frameIndex1 := trunc(time * (endfr - startfr + 1)) + startfr;

  if (frameIndex1 > endfr) then begin
		frameIndex1 := startfr;
	end;

	if (frameIndex1 < endfr) then begin
		frameIndex2 := frameIndex1 + 1;
	end	else begin
		frameIndex2 := startfr;
	end;

  frac :=	(time - (frameIndex1 - startfr) / (endfr - startfr + 1)) * (endfr - startfr + 1);

  //if frac>0.1 then begin
    for lauf:=0 to anzobjects-1 do begin
      WLDObjects[lauf].SetFrameVert(frameIndex1,frameIndex2,frac);
    end;
  //end;

end;

procedure TWLDObject.SetFrameVert(frame1,frame2:integer;frac:extended);
var lauf,lauf2:integer;
begin
  glBindBufferARB(GL_ARRAY_BUFFER, VBO);

  frame1:=frame1-1;
  frame2:=frame2-1;
  VertexData:=0;

  for lauf:=0 to FaceAnzahl-1 do begin
    for lauf2:=1 to 4 do begin
      Vertex[VertexData].vx:=Frames[frame1].vertices[Faces[lauf].vind[lauf2]].vx*(1-frac)+
                    Frames[frame2].vertices[Faces[lauf].vind[lauf2]].vx*frac;

      Vertex[VertexData].vy:=Frames[frame1].vertices[Faces[lauf].vind[lauf2]].vy*(1-frac)+
                    Frames[frame2].vertices[Faces[lauf].vind[lauf2]].vy*frac;

      Vertex[VertexData].vz:=Frames[frame1].vertices[Faces[lauf].vind[lauf2]].vz*(1-frac)+
                    Frames[frame2].vertices[Faces[lauf].vind[lauf2]].vz*frac;

      Vertex[VertexData].nx:=Frames[frame1].vertices[Faces[lauf].vind[lauf2]].nx*(1-frac)+
                    Frames[frame2].vertices[Faces[lauf].vind[lauf2]].nx*frac;

      Vertex[VertexData].ny:=Frames[frame1].vertices[Faces[lauf].vind[lauf2]].ny*(1-frac)+
                    Frames[frame2].vertices[Faces[lauf].vind[lauf2]].ny*frac;

      Vertex[VertexData].nz:=Frames[frame1].vertices[Faces[lauf].vind[lauf2]].nz*(1-frac)+
                    Frames[frame2].vertices[Faces[lauf].vind[lauf2]].nz*frac;
      if uvset=false then begin
        Vertex[VertexData].u:=Faces[lauf].uv[lauf2].u;
        Vertex[VertexData].v:=Faces[lauf].uv[lauf2].v;
      end;

      inc(VertexData);
    end;
  end;

  glBufferData(GL_ARRAY_BUFFER,SizeOf(TVertex)*VertexDatenLaenge,@Vertex[0],GL_DYNAMIC_DRAW);
  uvset:=true;

end;

end.
