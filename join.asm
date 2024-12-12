; Join!

[map all ./lst/join.map]
[DEFAULT REL]

;
;Creates, deletes and displays join drives.
;Order of arguments DOES NOT matter.
;Invoked by: 
; JOIN [drive 1: drive2:path] <- Mounts drive1 onto the path at drive2:path
; JOIN drive1: /D       <- Deletes the join drive drive1:
; JOIN                  <- Displays current join drives

BITS 64
%include "./inc/dosMacro.mac"
%include "./inc/dosStruc.inc"
%include "./inc/dosError.inc"
%include "./inc/dosVars.inc"
%include "./src/main.asm"
%include "./dat/strings.asm"
;Use a 45 QWORD stack
Segment transient align=8 follows=.text nobits
%include "./dat/bss.asm"
    dq 45 dup (?)
endOfAlloc: