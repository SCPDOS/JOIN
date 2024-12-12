#!/bin/sh

buffer:
	nasm join.asm -o ./bin/JOIN.COM -f bin -l ./lst/join.lst -O0v
