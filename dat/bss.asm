;BSS data
bssStart:
pSysvars    dq ?
pVar1       dq ?
pVar2       dq ?
;Used for create subst
mntDrv  db ?    ;0 based drive number of the JOIN host (mount drive)
joinDrv db ?    ;0 based drive number of the joined drive
inCDS   db cds_size dup (?)
        db (128 - cds_size) dup (?)   ;Padding for if the string is too long!
srchBuf db 40 dup (?)   ;Allocate double the space  
mntLen  db ?

bssLen equ $ - bssStart