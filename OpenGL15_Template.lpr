program OpenGL15_Template;

{$mode delphi}{$H+}

uses
  Forms, Interfaces,
  OpenGL15_MainForm in 'OpenGL15_MainForm.pas' {GLForm},
  Kamera in 'Kamera.pas';

begin
  Application.Initialize;
  Application.CreateForm(TGLForm, GLForm);
  Application.Run;
end.
