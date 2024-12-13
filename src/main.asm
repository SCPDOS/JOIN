;Join main routine
startMain:
    jmp short .cVersion
.vNum:  db 1
.cVersion:
    lea rsp, endOfAlloc   ;Move RSP to our internal stack
;Do a version check since this version cannot check the number of rows/cols
    cld
    mov eax, 3000h
    int 21h
    cmp al, byte [.vNum]    ;Version number 1 check
    jbe short okVersion
    lea rdx, badVerStr
badPrintExit:
    mov eax, 0900h
    int 21h
    mov eax, 4CFFh
    int 21h
okVersion:
;Now we init the BSS to 0.
    lea rdi, bssStart
    xor eax, eax
    mov ecx, bssLen
    rep stosb
;Now let us resize ourselves so as to take up as little memory as possible
    lea rbx, endOfAlloc ;Number of bytes of the allocation
    sub rbx, r8
    add ebx, 0Fh        ;Round up
    shr ebx, 4          ;Turn into number of paragraphs
    mov eax, 4A00h
    int 21h ;If this fails, we still proceed as we are just being polite!
;Now get the sysvars pointer and save it in var.
;This cannot change so it is fine to do it out of a critical section.
    mov eax, 5200h
    int 21h
    mov qword [pSysvars], rbx
parseCmdLine:
;Now parse the command line
    lea rsi, qword [r8 + psp.progTail]
    xor ecx, ecx    ;Keep a count of vars on cmd line in ecx
    call skipDelims ;Goto the first non-delimiter char
    cmp al, CR
    je endParse
    mov qword [pVar1], rsi    ;Save the ptr to the first var
    inc ecx
    call findDelimOrCR
    cmp al, CR
    je endParse
    call skipDelims
    mov qword [pVar2], rsi    ;Save the ptr to the second var
    inc ecx
    call findDelimOrCR
    cmp al, CR  ;The second arg shouldve been the last arg
    je endParse
badPrmsExit:
;Too many parameters and/or badly formatted cmdline error
    lea rdx, badPrmsStr
    jmp badPrintExit
badParmExit:
;Bad but valid parameter passed in
    lea rdx, badParmStr
    jmp badPrintExit
endParse:
    test ecx, ecx
    jz printJoin   ;If no arguments found, print the joins!
    cmp ecx, 1      
    je badPrmsExit  ;Cannot have just 1 argument on the cmdline
    mov eax, 3700h  ;Get switchchar in dl
    int 21h
    xor ecx, ecx    ;Use as cntr (1 or 2) to indicate which var has ptr to /D
    mov rsi, qword [pVar1]
    cmp byte [rsi], dl
    jne .g2
    call checkSwitchOk  ;Now check rsi points to a bona fide /D 
    jc badPrmsExit
    inc ecx
.g2:
    mov rsi, qword [pVar2]
    cmp byte [rsi], dl
    jne .switchDone
    test ecx, ecx   ;Var2 can be /D ONLY IF Var1 was not /D
    jnz badPrmsExit
    call checkSwitchOk  ;Now check rsi points to a bona fide /D 
    jc badPrmsExit
    mov ecx, 2      ;Else, indicate var2 has the /D flag!
.switchDone:
    test ecx, ecx   ;If ecx is zero, then we are creating a join.
    jz addJoin
;Else we are deleting a join drive.
delJoin:
    mov rsi, qword [pVar1]
    mov rdi, qword [pVar2]
    cmp ecx, 1          ;If ecx = 1, rsi points to the /D
    cmovne rdi, rsi     ;Make rdi point to the drive letter!
;rdi points to the drive letter in cmdline. Check it is legit.
    mov al, byte [rdi + 2]
    call isALDelimOrCR  ;Ensure the string length is 2!
    jne badPrmsExit
    cmp byte [rdi + 1], ":"
    jne badPrmsExit
;Here the char is legit! Now UC it and use it as offset into CDS
; to deactivate it!
    movzx eax, byte [rdi]
    push rax
    mov eax, 1213h  ;UC char
    int 2Fh
    movzx ecx, al   ;Move the UC char into ecx
    pop rax         ;Rebalance the stack
    sub ecx, "A"    ;Turn into an offset into CDS
;Check if we are deleting the current drive.
    mov eax, 1900h  ;Get current drive
    int 21h
    cmp al, cl  ;If we are deleting the current drive, error exit!
    je badParmExit
;Check if the join drive we want to deactivate is a valid drive
; in our system (i.e. does such a drive entry exist in the CDS array)
    call enterDOSCrit   ;Enter crit, Exit in the exit routine!
    mov rbx, qword [pSysvars]   
;If drive specified to remove is past end of CDS array, error!
    cmp byte [rbx + sysVars.lastdrvNum], cl
    jbe .error
;Point rdi to the cds we are adjusting.
    mov rdi, qword [rbx + sysVars.cdsHeadPtr]   ;Point rdi to cds array
    mov eax, cds_size
    mul ecx
    add ecx, "A"    ;Turn offset back into a UC drive letter!
    add rdi, rax    ;rdi now points to the right CDS
;Check the cds we have chosen is really a join drive
    test word [rdi + cds.wFlags], cdsJoinDrive
    jz .error      ;If this CDS is not a join drive, error!
;Start editing the CDS back to it's default state
    mov byte [rdi], cl  ;Place the drive letter...
    mov word [rdi + 2], "\"   ;... and root backslash with null terminator!
    mov byte [rdi + cds.wBackslashOffset], 2    ;Go to root!
    mov dword [rdi + cds.dStartCluster], 0      ;Set start cluster for root!
;Deactivate the join!
    and word [rdi + cds.wFlags], ~cdsJoinDrive 
    mov rbx, qword [pSysvars]
    cmp byte [rbx + sysVars.numJoinDrv], 0  ;Should never happen!
    je exit
    dec byte [rbx + sysVars.numJoinDrv]
    jmp exit
.error:
;Invalid drive specified!
    call exitDOSCrit    ;Exit the critical section before exiting!!
    jmp badParmExit
    
addJoin:
;Here we add the join path. We gotta check that path provided
; exists! It is not null terminated so we gotta null terminate it.
; We also gotta get rid of any trailing slashes from the path provided!
;
;Drive1 can be valid, be cannot be a subst, join or net drive!
;
    mov rsi, qword [pVar1]
    call findDelimOrCR
    mov byte [rsi], 0   ;Null terminate var1
    mov rsi, qword [pVar2]
    call findDelimOrCR
    mov byte [rsi], 0   ;Null terminate var2

    xor ebp, ebp        ;Use rbp as the ptr to the drive spec string

    mov rsi, qword [pVar1]  ;Check if var1 is drive specification
    cmp word [rsi + 1], ":" ;Is pVar1 a drive specification?
    cmove rbp, rsi  ;Move the ptr to the drive specifier into rbp

    mov rsi, qword [pVar2]  ;Check if var2 is drive specification
    cmp word [rsi + 1], ":" ;Is pVar2 a drive specification?
    jne .gotDrvSpec
    test rbp, rbp   ;rbp must be null, else two drives were specified. Error!
    jnz badParmExit ;Cmdline valid but invalid data passed!
    mov rbp, rsi    ;Set rbp to point to the drive
.gotDrvSpec:
;Come here with rbp pointing to the new join drive spec. 
    movzx eax, byte [rbp]
    push rax
    mov eax, 1213h  ;UC the char in al
    int 2Fh
    sub al, "A"     ;Turn into a 0 based drive number
    mov byte [joinDrv], al
    pop rax
;Make rsi point to the other argument!
    mov rsi, qword [pVar1]
    mov rdi, qword [pVar2]
    cmp rbp, rsi  ;if rbp -> var1...  
    cmove rsi, rdi  ;... make rsi -> var2. Else, rsi -> var1
;rsi -> ASCIIZ path. Must check it is a legit path.
    lea rdi, qword [inCDS + cds.sCurrentPath]
    mov eax, 121Ah
    int 2Fh
    jc badParmExit  ;Bad drive selected if CF=CY
    test al, al
    jnz .notDefault
    mov eax, 1900h
    int 21h
    inc eax
.notDefault:
    mov edx, eax    ;Save 1 based drive number in dl
    dec eax         ;Convert the drive number to 0 based
    cmp al, byte [joinDrv]  ;Check drive numbers are not equal 
    je badParmExit
    mov byte [mntDrv], al   ;Save the drive letter in the var 
    add al, "A"
    mov ah, ":"
    stosw   ;Store drive letter 
    xor eax, eax
    lodsb   ;Get the first char of the path now and adv char ptr
    cmp al, "\"
    je .pathSepFnd
    cmp al, "/"
    mov al, "\"     ;No pathsep (relpath) or unix pathsep given
    je .pathSepFnd
    dec rsi         ;Return the source ptr to the first char again!
    stosb           ;Store the pathsep and adv rdi
    push rsi        ;Save the source pointer
    mov rsi, rdi    ;Store the rest of the path here
    mov eax, 4700h  ;Get the Current Directory for current drive
    int 21h
    pop rsi         ;Get back the pointer to the source in rsi
    xor eax, eax
    mov ecx, -1
    repne scasb     ;Move rdi past the terminating null
    dec rdi         ;And point back to it
    cmp byte [rdi - 1], "\" ;Skip adding extra pathsep if one present (rt only)
    je .cplp
    mov al, "\"
.pathSepFnd:
    stosb           ;Store the normalised pathsep
;Now copy the path specified by rsi to rdi. rsi is null terminated string
.cplp:
    lodsb
    stosb
    test al, al
    jnz .cplp
;Now we normalise the CDS string and check it is of len leq 67
    lea rsi, inCDS
    mov rdi, rsi
    mov eax, 1211h  ;Normalise string (UC and swap slashes.)
    int 2Fh
    mov eax, 1212h  ;Strlen (including terminating null)
    int 2Fh
    cmp ecx, 67
    ja badParmExit
    mov byte [mntLen], cl
;Now the CDS string is setup, check it is one path componant only.
;Also verify that there are no wildcards present in path. If so, 
; bad parameter error!
.pathCheck:
    xor ecx, ecx
.pcLp:
    lodsb
    test al, al
    jz .pcEnd
    cmp al, "*"
    je badParmExit
    cmp al, "?"
    je badParmExit
    cmp al, "\"
    jne .pcLp
    inc ecx     ;Inc pathsep counter
    jmp short .pcLp
.pcEnd:
    cmp ecx, 1  ;One pathsep allowed only!
    jne badParmExit
    lea rdx, qword [inCDS + cds.sCurrentPath]
    mov eax, dword [rdx]
    shr eax, 8  ;Drop the drive letter
    cmp eax, ":\"
    je badParmExit  ;Cannot join to root drive
;We now enter the critical section and 
; find the mount path
    call enterDOSCrit   ;Now enter DOS critical section
    mov eax, 4E00h  ;Find first on path pointed to by rdx
    mov ecx, 10h    ;Find subdirs
    int 21h
    jnc .dirFnd
    mov eax, 3900h  ;MKDIR for the name pointed to by rdx
    int 21h
    jnc .dirMade
.badMntpntExit:
    lea rdx, badParmStr
    call exitDOSCrit
    jmp badPrintExit
.dirFnd:
;Check what we found is a subdir
    cmp byte [r8 + 80h + ffBlock.attribFnd], 10h
    jne .badMntpntExit
.dirMade:
;Now we check the mount point is empty
    lea rdi, srchBuf
    lea rsi, qword [inCDS + cds.sCurrentPath]
    movzx ecx, byte [mntLen]
    rep movsb   ;Copy it over
    dec rdi
    mov al, "\"
    stosb
    mov eax, "*.*"
    stosd
    
    lea rdx, srchBuf
    mov eax, 4E00h
    mov ecx, 16h    ;Inclusive directory search (find ., always exists)
    int 21h
    mov eax, 4F00h  ;Find .., always exists
    int 21h
    mov eax, 4F00h  ;Try find a third file
    int 21h
    jc .emptyDir    ;If no file found, proceed happily
    call exitDOSCrit
    lea rdx, badDirStr  ;Else, directory not empty!
    jmp badPrintExit
.emptyDir:
;Check the join drive is not past lastdrv
    mov rbx, qword [pSysvars]
    movzx ecx, byte [joinDrv]
    cmp byte [rbx + sysVars.lastdrvNum], cl
    ja .destNumOk ;Has to be above zero as cl is 0 based :)
.badNumExit:
    call exitDOSCrit
    jmp badParmExit
.destNumOk:
    movzx ecx, byte [mntDrv]    
    cmp byte [rbx + sysVars.lastdrvNum], cl
    jbe .badNumExit
    ;Check the mount drive is not a redir etc.
    call .getCds    ;Get mount drive cds in rdi
    test word [rdi + cds.wFlags], cdsJoinDrive | cdsSubstDrive | cdsRedirDrive
    jz .mntOk
.inDOSBadNetExit:
    lea rdx, badNetStr
    call exitDOSCrit
    jmp badPrintExit
.mntOk:
    ;Now we check the join drive too.
    movzx ecx, byte [joinDrv]
    call .getCds    ;Get the CDS ptr for the destination in rdi
    test word [rdi + cds.wFlags], cdsJoinDrive | cdsSubstDrive | cdsRedirDrive
    jnz .inDOSBadNetExit   
    ;Now we modify the join drive
    or word [rdi + cds.wFlags], cdsJoinDrive
    lea rsi, qword [inCDS + cds.sCurrentPath]
    movzx ecx, byte [mntLen]
    rep movsb
;This should never happen, should throw error instead
    cmp byte [rbx + sysVars.numJoinDrv], 0FFh   
    je exit
    inc byte [rbx + sysVars.numJoinDrv]
    jmp exit
.getCds:
;Input: ecx = [byte] 0-based drive number
;       rbx -> sysVars
;Output: rdi -> CDS for drive
    mov rdi, qword [rbx + sysVars.cdsHeadPtr]   ;Point rdi to cds array
    mov eax, cds_size
    mul ecx
    add rdi, rax    ;rdi now points to the right CDS
    return


printJoin:
    call enterDOSCrit   ;Ensure the CDS size and ptr doesnt change
    mov rbx, qword [pSysvars]
    mov rdi, qword [rbx + sysVars.cdsHeadPtr]
    movzx ecx, byte [rbx + sysVars.lastdrvNum]  ;Get # of CDS's
    mov ebx, "A"    
.lp:
    test word [rdi + cds.wFlags], cdsJoinDrive
    jz .gotoNextCDS
;Print the CDS drive letter and the rocket
    lea rdx, rocketStr
    mov byte [rdx], bl  ;Overwrite the drive letter in rocketStr
    mov eax, 0900h      ;Print the rocketStr
    int 21h
;Print the current path of the cds upto the backslash offset
    push rbx
    lea rdx, qword [rdi + cds.sCurrentPath]
    mov eax, 1212h  ;Strlen (rdi points to the current path)
    int 2fh
    mov ebx, 1          ;Print to STDOUT
    mov eax, 4000h
    int 21h
    pop rbx
;Print a CRLF
    lea rdx, crlf
    mov eax, 0900h
    int 21h
.gotoNextCDS:
    add rdi, cds_size
    inc ebx ;Goto next drive letter!
    dec ecx
    jnz .lp
exit:
    call exitDOSCrit
    mov eax, 4C00h
    int 21h

;------------------------------------------------------------------------
; Utility functions below!
;------------------------------------------------------------------------
checkSwitchOk:
;Checks if the switch char is D and if the char following is a 
; delimiter or CR. 
;Input: rsi -> Possible /D. Points to the /
;Output: CF=CY: Not ok to proceed.
;        CF=NC: Ok to proceed
    mov al, byte [rsi + 1]
    push rax
    mov eax, 1213h  ;UC char
    int 2Fh
    cmp al, "D"
    pop rax
    jne .bad
    mov al, byte [rsi + 2]
    cmp al, CR  ;If equal, clears CF
    rete
    call isALDelim  ;If return equal, we are ok!
    rete
.bad:
    stc
    return

enterDOSCrit:
    push rax
    mov eax, 8001h
    int 2Ah
    pop rax
    return 

exitDOSCrit:
    push rax
    mov eax, 8101h
    int 2Ah
    pop rax
    return 

skipDelims:
;Points rsi to the first non-delimiter char in a string, loads al with value
    lodsb
    call isALDelim
    jz skipDelims
;Else, point rsi back to that char :)
    dec rsi
    return

findDelimOrCR:
;Point rsi to the first delim or cmdtail terminator, loads al with value
    lodsb
    call isALDelimOrCR
    jnz findDelimOrCR
    dec rsi ;Point back to the delim or CR char
    return

isALDelimOrCR:
    cmp al, CR
    rete
isALDelim:
    cmp al, SPC
    rete
    cmp al, TAB
    rete
    cmp al, "="
    rete
    cmp al, ","
    rete
    cmp al, ";"
    return