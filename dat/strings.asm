
;SUBST data
;Strings
badNetStr   db "Cannot SUBST a network drive",CR,LF,"$"
badVerStr   db "Incorrect DOS Version"    ;Ends on the next line
crlf        db LF,CR,"$"
badPrmsStr  db "Incorrect number of parameters",CR,LF,"$"
badParmStr  db "Invalid parameter",CR,LF,"$"
badPathStr  db "Path not found",CR,LF,"$"
badDirStr   db "Directory not empty",CR,LF,"$"
rocketStr   db "_: => $"