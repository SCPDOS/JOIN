;BSS data
bssStart:
pSysvars    dq ?
pVar1       dq ?
pVar2       dq ?
;Used for create subst
srcDrv  db ?    ;0 based drive number of the JOIN
destDrv db ?    ;0 based drive number of the drive the path is on
inCDS   db cds_size dup (?)
        db (128 - cds_size) dup (?)   ;Padding for if the string is too long!
bssLen equ $ - bssStart