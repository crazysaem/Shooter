unit WLDModel;

interface

uses Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs, dglOpenGL, StdCtrls,
      SDL, SDL_Image, Newtonpas, inifiles;

//procedure InitNewton;

type

  TWLDModel = class(TObject)

  //private

  public
  procedure LoadModel(name:string);

  end;

  //const

  //var

implementation

procedure TModel.LoadModel(name:string);
begin
end;

end.
