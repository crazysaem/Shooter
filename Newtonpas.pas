unit Newtonpas;

interface

uses Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs, dglOpenGL, StdCtrls,
      SDL, SDL_Image, inifiles, NewtonImport, glMatrixHelper, Maths3d;

function NV3(p1,p2,p3:extended):TVector3f;
function CharacterRayCastFilter(const body : PNewtonBody; const hitNormal: PFloat; collisionID : Int; userData: Pointer; intersetParam: Float ) : Float; cdecl;

type
  NVec3f=TVector3f;
  ZNewtonWorld = ^PNewtonWorld;
  ZNewtonBody  = ^PNewtonBody;
  ZCharacterController = ^TCharacterController;

  TMaterial = record
    LevelID,PlayerID:Integer;
  end;

  TNewtonObject = class
   obj        : string;
   NewtonBody : PNewtonBody;
   Matrix     : TMatrix4f;
   Size       : NVec3f;
   procedure  Init(obj1:string;pSize, Position : NVec3f; Mass : Single; NewtonWorld:ZNewtonWorld);
   //procedure Render;
  end;

  TCharacterController = class
   Body          : PNewtonBody;
   Matrix        : TMatrix4f;
   Run           : Boolean;      // If true, velocity in the callback is scaled
   Rotation      : NVec3f;
   Movement      : NVec3f;
   Size          : NVec3f;
   NewtonObject  : TNewtonObject;
   procedure     Init(pSize:NVec3f; NewtonWorld:ZNewtonWorld);
   procedure     Jump(NewtonWorld:ZNewtonWorld);
   procedure     Shoot(NewtonWorld:ZNewtonWorld;P2:TVector3f);
   function      CharachterDistance(NewtonWorld:ZNewtonWorld):extended;
  end;

  TNewton = class(TObject)

  private
  anzobjects:int64;
  NewtonObject:array of TNewtonObject;
  CharacterController:TCharacterController;

  public
  NewtonWorld:PNewtonWorld;
  CollTreeWLD:array of PNewtonCollision;
  BodyWLD:array of PNewtonBody;

  procedure Init;
  function AddObject(obj:string;size,position:NVec3f;mass:extended):integer;
  procedure CreateCharacter(size:NVec3f);
  procedure CharJump;
  procedure Shoot(P2:TVector3f);
  procedure SetMovement(Movem:NVec3f);
  procedure SetWorldSize(min,max:extended);
  procedure Update(time:extended);
  function  GetCharMatrix:TMatrix4f;
  function  GetObjMatrix(ObjNumber:integer):TMatrix4f;
  end;

  var
    Time:extended;
    PlayerSpeed:extended;
    Distance:extended;
    ZCharacter:ZCharacterController;
    Bjump:boolean;
    ExternalForce : NVec3f;    // Is used to apply external forces, e.g. upon key press
    shotbody:PNewtonBody;
    shootforce:TVector3f;

  const
    PlayerMass      = 75;
    PlayerJumpForce = 12000;
    Infinite        = 1000000;

implementation

function NV3(p1,p2,p3:extended):NVec3f;
var v:NVec3f;
begin
  v[0]:=p1;
  v[1]:=p2;
  v[2]:=p3;
  NV3:=v;
end;

procedure CharacterApplyForceCallback(const Body : PNewtonBody; timestep : Float; threadIndex : int ); cdecl; //; timestep : Float; threadIndex : int  ???
var
 Mass         : Single;
 Ixx          : Single;
 Iyy          : Single;
 Izz          : Single;
 Force        : TVector3f;
 Velocity     : TVector3f;
 Length       : Single;
 GoalVelocity : NVec3f;
 Accel        : NVec3f;
 UserData     : Pointer;
 m            : NVec3f;
begin
Accel := V3(0,0,0);
Time  := SDL_GetTicks - Time;
// User data was set to the class of the character controll, so we do a typecast
UserData := NewtonBodyGetUserData(Body);
if UserData = nil then
 exit;
with TCharacterController(UserData) do
 begin
 m:=Movement;

 // First we add the gravity
 NewtonBodyGetMassMatrix(Body, @Mass, @Ixx, @Iyy, @Izz);
 Force := V3(0, -9.8 * Mass * 15, 0);
 NewtonBodyAddForce(Body, @Force) ;

 // Get matrix from newton
 NewtonBodyGetMatrix(Body, @Matrix[0,0]);

 // Now normalize movement vector
 Length   := Sqrt(Sqr(Movement[0]) + Sqr(Movement[2]));
 if Length = 0 then
  Length := 1;
 Movement := V3(Movement[X]/Length, Movement[Y], Movement[Z]/Length);

 // Get the current velocity
 NewtonBodyGetVelocity(Body, @Velocity);

 // Get velocity we want to apply on our player
 GoalVelocity := V3(Movement[X] * PlayerSpeed, 0, Movement[Z] * PlayerSpeed);

 // Scale it by 3 if the player wants to run
 if Run then
  GoalVelocity := V3(GoalVelocity[x] * 3, GoalVelocity[y] * 3, GoalVelocity[z] * 3);

 // Calculate acceleration needed to get to our goal velocity
 if Time = 0 then
  Time := 1;
 //Accel[X] := 0.3 * ((GoalVelocity[X] - Velocity[X]) / (Time/10)) * 100;
 //Accel[Z] := 0.3 * ((GoalVelocity[Z] - Velocity[Z]) / (Time/10)) * 100;

 Accel[X] := 0.3 * ((GoalVelocity[X]) - Velocity[X] / (1/10)) * 100;
 Accel[Z] := 0.3 * ((GoalVelocity[Z]) - Velocity[Z] / (1/10)) * 100;
 Accel[Y] := 0;

 // Limit acceleration
 //if Accel[X] > 200 then Accel[X] := 200;
 //if Accel[X] < -200 then Accel[X] := -200;
 //if Accel[Z] > 200 then Accel[Z] := 200;
 //if Accel[Z] < -200 then Accel[Z] := -200;

 //Set Force to 0
 (*
 NewtonBodyGetForce(Body,@Anti);
 Anti[0]:=Anti[0]*-1;
 Anti[1]:=Anti[1]*-1;
 Anti[2]:=Anti[2]*-1;
 NewtonBodyAddForce(Body,@Anti);
 NewtonBodyGetForce(Body,@Anti);*)

 // Now finally add the force to the player's body
 NewtonBodyAddForce(Body,@Accel);

 NewtonBodyAddForce(Body, @ExternalForce[0]);

 // If there is any external force (e.g. due to jumping) add it too
 //if (ExternalForce[x] <> 0) or (ExternalForce[y] <> 0) or (ExternalForce[z] <> 0) then
 // ExternalForce := V3(0,0,0);
 if (ExternalForce[y]>0) then ExternalForce[y]:=ExternalForce[y]-100*(Time/10);
 if (ExternalForce[y]<0) then ExternalForce[y]:=0;
 end;


Time := SDL_GetTicks;
end;

// =============================================================================
//  CharacterRayCastFilter
// =============================================================================
//  This is just used to pass the distance to any ray-casted objects, so
//  we can see if the player is standing on top of something. Used for jumping
// =============================================================================

//function CharacterRayCastFilter(const body : PNewtonBody; const hitNormal: PFloat; collisionID : Int; userData: Pointer; intersectParam: Float ) : Float; cdecl;
function CharacterRayCastFilter(const body : PNewtonBody; const hitNormal: PFloat; collisionID : Int; userData: Pointer; intersetParam: Float ) : Float; cdecl;
begin
Result := intersetParam;
if Body = ZCharacter^.Body then exit;
Distance := intersetParam;
end;

procedure TNewton.Init;
begin
  anzobjects:=0;
  NewtonWorld := NewtonCreate(nil, nil);
  PlayerSpeed:=0.1;
  shotbody:=nil;
end;

procedure ForceAndTorqueCallback(const body : PNewtonBody; timestep : Float; threadIndex : int ); cdecl; // ; timestep : Float; threadIndex : int  ?? was ist das
var
 Mass    : Single;
 Inertia : TVector3f;
 Force   : TVector3f;
 SForce   : TVector3f;
begin
  NewtonBodyGetMassMatrix(Body, @Mass, @Inertia[0], @Inertia[1], @Inertia[2]);
  Force := V3(0, -9.8 * Mass, 0);
  NewtonBodyAddForce(Body, @Force[0]);
  if (body=shotbody) then begin
    shotbody:=nil;
    SForce[0]:=(shootforce[0]*0.2);
    SForce[1]:=(shootforce[1]*0.2);
    SForce[2]:=(shootforce[2]*0.2);
    //NewtonBodySetAutoSleep(Body, 0);
    NewtonBodyAddForce(Body, @SForce[0]);
    //NewtonBodySetAutoSleep(Body, 1);
  end;
end;

function TNewton.AddObject(obj:string;size,position:NVec3f;mass:extended):integer;
begin
  anzobjects:=anzobjects+1;
  setlength(NewtonObject,anzobjects);
  NewtonObject[anzobjects-1]:=TNewtonObject.Create;
  NewtonObject[anzobjects-1].Init(obj,size,position,mass,@NewtonWorld);
  AddObject:=anzobjects;
end;

procedure TNewtonObject.Init(obj1:string;pSize, Position : NVec3f; Mass : Single; NewtonWorld:ZNewtonWorld);
var Collision : PNewtonCollision;
    Inertia   : NVec3f;
begin
Size:=pSize;

obj:=obj1;

if obj='Box' then begin
  // Create a box collision
  Collision  := NewtonCreateBox(NewtonWorld^, Size[0], Size[1], Size[2],0, nil);
end;

if obj='Sphere' then begin
  // Create a Sphere collision
  Collision  := NewtonCreateSphere(NewtonWorld^, Size[0], Size[1], Size[2],0, nil);
end;

// Create the rigid body
NewtonBody:=NewtonCreateBody(NewtonWorld^, Collision);

//NewtonBodySetAutoSleep(NewtonBody, 0);

// Remove the collider, we don't need it anymore
NewtonReleaseCollision(NewtonWorld^, Collision);

// Now we calculate the moment of intertia for this box. Note that a correct
// moment of inertia is CRUCIAL for the CORRECT PHYSICAL BEHAVIOUR of a body,
// so we use an special equation for calculating it
if mass<>0 then begin
  Inertia[0] := Mass * (Size[1] * Size[1] + Size[2] * Size[2]) / 12;
  Inertia[1] := Mass * (Size[0] * Size[0] + Size[2] * Size[2]) / 12;
  Inertia[2] := Mass * (Size[0] * Size[0] + Size[1] * Size[1]) / 12;

  // Set the bodies mass and moment of inertia
  NewtonBodySetMassMatrix(NewtonBody, Mass, Inertia[0], Inertia[1], Inertia[2]);
end else begin
  NewtonBodySetMassMatrix(NewtonBody, 0.0, 0, 0, 0);
end;
// Now set the position of the body's matrix
NewtonBodyGetMatrix(NewtonBody, @Matrix);
Matrix[3,0] := Position[0];
Matrix[3,1] := Position[1];
Matrix[3,2] := Position[2];
NewtonBodySetMatrix(NewtonBody, @Matrix);
// Finally set the callback in which the forces on this body will be applied
NewtonBodySetForceAndTorqueCallBack(NewtonBody, @ForceAndTorqueCallBack);
end;

procedure TNewton.CreateCharacter(size:NVec3f);
var Material:TMaterial;
begin
  Material.LevelID  := NewtonMaterialGetDefaultGroupID(NewtonWorld);
  Material.PlayerID := NewtonMaterialCreateGroupID(NewtonWorld);
  NewtonMaterialSetDefaultFriction(NewtonWorld, Material.LevelID, Material.PlayerID, 0, 0);
  NewtonMaterialSetDefaultElasticity(NewtonWorld, Material.LevelID, Material.PlayerID, 0);

  CharacterController:=TCharacterController.Create;
  CharacterController.Init(size,@NewtonWorld);

  NewtonBodySetMaterialGroupID(CharacterController.Body, Material.PlayerID);

  ZCharacter:=@CharacterController;
end;

procedure TCharacterController.Init(pSize:NVec3f; NewtonWorld:ZNewtonWorld);
const
 UpDir : array[0..2] of Single = (0, 1, 0);
var
 Collider    : PNewtonCollision;
 StartMatrix : TMatrix4f;
 Velocity : TVector3f;
begin
Bjump:=false;
Size := pSize;
//Movement:=NV3(0,0,0);
//ExternalForce:=NV3(0,0,0);

// Create an ellipsoid as base for the collider
Collider := NewtonCreateSphere(NewtonWorld^, Size[x], Size[y], Size[z],0, nil);
// Create rigid body
Body := NewtonCreateBody(NewtonWorld^, Collider);
// We don't need the collider anymore
NewtonReleaseCollision(NewtonWorld^, Collider);

// Disable auto freezing
//NewtonBodySetAutoFreeze(Body, 0);
NewtonBodySetAutoSleep(Body, 0);
// Activate him
//NewtonWorldUnfreezeBody(NewtonWorld^, Body);
// Set callback
NewtonBodySetForceAndTorqueCallBack(Body, @CharacterApplyForceCallback);
// Give it a realistic mass
NewtonBodySetMassMatrix(Body, 36, 1/5 * PlayerMass * (Sqr(Size[y])+Sqr(Size[x])), 1/5 * PlayerMass * (Sqr(Size[z])+Sqr(Size[x])), 1/5 * PlayerMass * (Sqr(Size[z])+Sqr(Size[y])));
// Set it's position
Matrix_SetIdentity(StartMatrix);
Matrix_SetTransform(StartMatrix, V3(0, 100, -100));
NewtonBodySetMatrix(Body, @StartMatrix);
// The player should not fall over, so we attach an up-vector joint to it.
// This type of joint will make the player always stay up in the direction
// that the joint was set to (in this case up on y)
NewtonConstraintCreateUpVector(NewtonWorld^, @UpDir, Body);
// Finally set the user data to point to this class, so we can easily access
// it later on in any of the callbacks
NewtonBodySetUserData(Body, self);
end;

function TCharacterController.CharachterDistance(NewtonWorld:ZNewtonWorld):extended;
var
 P1,P2    : TVector3f;
begin
// Shoot a ray down from players position to see if the is touching ground
P1 := V3(Matrix[3,0], Matrix[3,1], Matrix[3,2]);
P2 := V3(Matrix[3,0], Matrix[3,1]-Size[y]*1.1, Matrix[3,2]);
Distance := 1.1;
NewtonWorldRayCast(NewtonWorld^, @P1, @P2, @CharacterRayCastFilter, nil, nil);
CharachterDistance:=Distance;
end;

procedure TCharacterController.Jump(NewtonWorld:ZNewtonWorld);
var
 P1,P2    : TVector3f;
begin
// Shoot a ray down from players position to see if the is touching ground
P1 := V3(Matrix[3,0], Matrix[3,1], Matrix[3,2]);
P2 := V3(Matrix[3,0], Matrix[3,1]-Size[y]*1.1, Matrix[3,2]);
Distance := 1.1;
NewtonWorldRayCast(NewtonWorld^, @P1, @P2, @CharacterRayCastFilter, nil, nil);
// When the ray hit something, the distance returned by the filter is a value
// smaller than one
if (Distance <= 0.91) and (Bjump=false) then
 begin
  Bjump:=true;
  // Store the jumping force, cause forces can only be applied within a callback
  ExternalForce := V3(0, PlayerJumpForce, 0);
 end;
end;

procedure TNewton.Shoot(P2:TVector3f);
begin
  CharacterController.Shoot(@Newtonworld,P2);
end;

function CharacterRayCastShoot(const body : PNewtonBody; const hitNormal: PFloat; collisionID : Int; userData: Pointer; intersectParam: Float ) : Float; cdecl;
begin
Result := IntersectParam;
if Body = ZCharacter^.Body then exit else begin
shotbody := Body;
//Distance := IntersectParam;
end;
end;

procedure TCharacterController.Shoot(NewtonWorld:ZNewtonWorld;P2:TVector3f);
var P1: TVector3f;
begin
  P1 := V3(Matrix[3,0], Matrix[3,1], Matrix[3,2]);

  P2 := V3(P2[0]*Infinite,P2[1]*Infinite,P2[2]*Infinite);
  P2 := V3(P1[0]+P2[0],P1[1]+P2[1],P1[2]+P2[2]);

  shootforce:=P2;
  //P2 := V3(P1[0],P1[1]-100,P1[2]);
  NewtonWorldRayCast(NewtonWorld^, @P1, @P2, @CharacterRayCastShoot, nil, nil);
end;

procedure TNewton.SetMovement(Movem:NVec3f);
begin
  CharacterController.Movement:=V3(0,0,0);
  CharacterController.Movement:=movem;
  //showmessage(floattostr(CharacterController.Movement[0])+' '+floattostr(CharacterController.Movement[1])+' '+floattostr(CharacterController.Movement[2]));
end;

function TNewton.GetCharMatrix:TMatrix4f;
begin
  NewtonBodyGetMatrix(CharacterController.Body, @CharacterController.Matrix);
  GetCharMatrix:=CharacterController.Matrix;
end;

procedure TNewton.Update(time:extended);
begin
  if (CharacterController.CharachterDistance(@NewtonWorld)<= 0.91) and (Bjump=true) then Bjump:=false;
  NewtonUpdate(NewtonWorld, time);
end;

procedure TNewton.SetWorldSize(min,max:extended);
var mi,ma:array[0..2] of Float;
    lauf:integer;
begin
  for lauf:=0 to 2 do begin
    mi[lauf]:=min;
    ma[lauf]:=max;
  end;
  NewtonSetWorldSize(NewtonWorld,@mi,@ma)
end;

function TNewton.GetObjMatrix(ObjNumber:integer):TMatrix4f;
var Matrix:TMatrix4f;
begin
  NewtonBodyGetMatrix(NewtonObject[ObjNumber-1].NewtonBody, @Matrix);
  GetObjMatrix:=Matrix;
end;

procedure TNewton.CharJump;
begin
  CharacterController.Jump(@Newtonworld);
end;

end.
