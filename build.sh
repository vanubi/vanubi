#!/bin/sh
ghc --make Build.hs
./Build
if [ "$1" = "run" ]; then
	./vanubi
fi
