
;SUBST data
;Strings
badNetStr   db "Cannot JOIN a network drive",CR,LF,"$"
badVerStr   db "Incorrect DOS Version"    ;Ends on the next line
crlf        db LF,CR,"$"
badPrmsStr  db "Incorrect number of parameters",CR,LF,"$"
badParmStr  db "Invalid parameter",CR,LF,"$"
badPathStr  db "Path not found",CR,LF,"$"
badDirStr   db "Directory not empty",CR,LF,"$"
rocketStr   db "_: => $"
badMultStr  db "Cannot run JOIN in a multitasking environment",CR,LF,"$"