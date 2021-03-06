unit CAM_ECB;

(*************************************************************************

 DESCRIPTION     :  Camellia ECB functions

 REQUIREMENTS    :  TP5-7, D1-D7/D9-D10/D12, FPC, VP

 EXTERNAL DATA   :  ---

 MEMORY USAGE    :  ---

 DISPLAY MODE    :  ---

 REFERENCES      :  B.Schneier, Applied Cryptography, 2nd ed., ch. 9.1


 Version  Date      Author      Modification
 -------  --------  -------     ------------------------------------------
 0.10     16.06.08  W.Ehrhardt  Initial version analog TF_ECB
 0.11     23.11.08  we          Uses BTypes
 0.12     29.07.10  we          Longint ILen in CAM_ECB_En/Decrypt
**************************************************************************)


(*-------------------------------------------------------------------------
 (C) Copyright 2008-2010 Wolfgang Ehrhardt

 This software is provided 'as-is', without any express or implied warranty.
 In no event will the authors be held liable for any damages arising from
 the use of this software.

 Permission is granted to anyone to use this software for any purpose,
 including commercial applications, and to alter it and redistribute it
 freely, subject to the following restrictions:

 1. The origin of this software must not be misrepresented; you must not
    claim that you wrote the original software. If you use this software in
    a product, an acknowledgment in the product documentation would be
    appreciated but is not required.

 2. Altered source versions must be plainly marked as such, and must not be
    misrepresented as being the original software.

 3. This notice may not be removed or altered from any source distribution.
----------------------------------------------------------------------------*)

{$i STD.INC}

interface


uses
  BTypes, CAM_Base;


function  CAM_ECB_Init({$ifdef CONST} const {$else} var {$endif} Key; KeyBits: word; var ctx: TCAMContext): integer;
  {-Camellia key expansion, error if invalid key size}
  {$ifdef DLL} stdcall; {$endif}

procedure CAM_ECB_Reset(var ctx: TCAMContext);
  {-Clears ctx fields bLen and Flag}
  {$ifdef DLL} stdcall; {$endif}

function  CAM_ECB_Encrypt(ptp, ctp: Pointer; ILen: longint; var ctx: TCAMContext): integer;
  {-Encrypt ILen bytes from ptp^ to ctp^ in ECB mode}
  {$ifdef DLL} stdcall; {$endif}

function  CAM_ECB_Decrypt(ctp, ptp: Pointer; ILen: longint; var ctx: TCAMContext): integer;
  {-Decrypt ILen bytes from ctp^ to ptp^ in ECB mode}
  {$ifdef DLL} stdcall; {$endif}


implementation


{---------------------------------------------------------------------------}
procedure CAM_ECB_Reset(var ctx: TCAMContext);
  {-Clears ctx fields bLen and Flag}
begin
  CAM_Reset(ctx);
end;


{---------------------------------------------------------------------------}
function CAM_ECB_Init({$ifdef CONST} const {$else} var {$endif} Key; KeyBits: word; var ctx: TCAMContext): integer;
  {-Camellia key expansion, error if invalid key size}
begin
  CAM_ECB_Init := CAM_Init(Key, KeyBits, ctx);
end;


{---------------------------------------------------------------------------}
function CAM_ECB_Encrypt(ptp, ctp: Pointer; ILen: longint; var ctx: TCAMContext): integer;
  {-Encrypt ILen bytes from ptp^ to ctp^ in ECB mode}
var
  i,n: longint;
  m: word;
  tmp: TCAMBlock;
begin

  CAM_ECB_Encrypt := 0;
  if ILen<0 then ILen := 0;

  if (ptp=nil) or (ctp=nil) then begin
    if ILen>0 then begin
      CAM_ECB_Encrypt := CAM_Err_NIL_Pointer;
      exit;
    end;
  end;

  {$ifdef BIT16}
    if (ofs(ptp^)+ILen>$FFFF) or (ofs(ctp^)+ILen>$FFFF) then begin
      CAM_ECB_Encrypt := CAM_Err_Invalid_16Bit_Length;
      exit;
    end;
  {$endif}

  n := ILen div CAMBLKSIZE; {Full blocks}
  m := ILen mod CAMBLKSIZE; {Remaining bytes in short block}
  if m<>0 then begin
    if n=0 then begin
      CAM_ECB_Encrypt := CAM_Err_Invalid_Length;
      exit;
    end;
    dec(n);           {CTS: special treatment of last TWO blocks}
  end;

  {Short block must be last, no more processing allowed}
  if ctx.Flag and 1 <> 0 then begin
    CAM_ECB_Encrypt := CAM_Err_Data_After_Short_Block;
    exit;
  end;

  with ctx do begin
    for i:=1 to n do begin
      CAM_Encrypt(ctx, PCAMBlock(ptp)^, PCAMBlock(ctp)^);
      inc(Ptr2Inc(ptp),CAMBLKSIZE);
      inc(Ptr2Inc(ctp),CAMBLKSIZE);
    end;
    if m<>0 then begin
      {Cipher text stealing}
      CAM_Encrypt(ctx, PCAMBlock(ptp)^, buf);
      inc(Ptr2Inc(ptp),CAMBLKSIZE);
      tmp := buf;
      move(PCAMBlock(ptp)^, tmp, m);
      CAM_Encrypt(ctx, tmp, PCAMBlock(ctp)^);
      inc(Ptr2Inc(ctp),CAMBLKSIZE);
      move(buf,PCAMBlock(ctp)^,m);
      {Set short block flag}
      Flag := Flag or 1;
    end;
  end;
end;


{---------------------------------------------------------------------------}
function CAM_ECB_Decrypt(ctp, ptp: Pointer; ILen: longint; var ctx: TCAMContext): integer;
  {-Decrypt ILen bytes from ctp^ to ptp^ in ECB mode}
var
  i,n: longint;
  m: word;
  tmp: TCAMBlock;
begin

  CAM_ECB_Decrypt := 0;
  if ILen<0 then ILen := 0;

  if (ptp=nil) or (ctp=nil) then begin
    if ILen>0 then begin
      CAM_ECB_Decrypt := CAM_Err_NIL_Pointer;
      exit;
    end;
  end;

  {$ifdef BIT16}
    if (ofs(ptp^)+ILen>$FFFF) or (ofs(ctp^)+ILen>$FFFF) then begin
      CAM_ECB_Decrypt := CAM_Err_Invalid_16Bit_Length;
      exit;
    end;
  {$endif}

  n := ILen div CAMBLKSIZE; {Full blocks}
  m := ILen mod CAMBLKSIZE; {Remaining bytes in short block}
  if m<>0 then begin
    if n=0 then begin
      CAM_ECB_Decrypt := CAM_Err_Invalid_Length;
      exit;
    end;
    dec(n);           {CTS: special treatment of last TWO blocks}
  end;

  {Short block must be last, no more processing allowed}
  if ctx.Flag and 1 <> 0 then begin
    CAM_ECB_Decrypt := CAM_Err_Data_After_Short_Block;
    exit;
  end;

  with ctx do begin
    for i:=1 to n do begin
      CAM_Decrypt(ctx, PCAMBlock(ctp)^, PCAMBlock(ptp)^);
      inc(Ptr2Inc(ptp),CAMBLKSIZE);
      inc(Ptr2Inc(ctp),CAMBLKSIZE);
    end;
    if m<>0 then begin
      {Cipher text stealing}
      CAM_Decrypt(ctx, PCAMBlock(ctp)^, buf);
      inc(Ptr2Inc(ctp),CAMBLKSIZE);
      tmp := buf;
      move(PCAMBlock(ctp)^, tmp, m);
      CAM_Decrypt(ctx, tmp, PCAMBlock(ptp)^);
      inc(Ptr2Inc(ptp),CAMBLKSIZE);
      move(buf,PCAMBlock(ptp)^,m);
      {Set short block flag}
      Flag := Flag or 1;
    end;
  end;
end;


end.
