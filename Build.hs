#!/usr/bin/env runhaskell
import Development.Shake
import Development.Shake.FilePath
import Control.Applicative hiding ((*>))

cc = "cc"
valac = "valac"
pkgconfig = "pkg-config"
sources = words "vanubi.vala bar.vala editor.vala matching.vala filecompletion.vala shell.vala"
packages = words "vte-2.90 gtk+-3.0 gtksourceview-3.0 glib-2.0 gobject-2.0"

-- derived
csources = map (flip replaceExtension ".c") sources
cobjects = map (flip replaceExtension ".o") csources

main = shake shakeOptions $ do
  want ["vanubi"]
  "vanubi" *> \out -> do
    need cobjects
    pkgconfigflags <- pkgConfig $ ["--libs"] ++ packages
    system' cc $ ["-fPIC", "-o", out] ++ pkgconfigflags ++ cobjects
  cobjects **> \out -> do
    let cfile = replaceExtension out ".c"
    need [cfile]
    pkgconfigflags <- pkgConfig $ ["--cflags"] ++ packages
    system' cc $ ["-ggdb", "-fPIC", "-c", "-o", out, cfile] ++ pkgconfigflags
  csources *>> \_ -> do
    let valapkgflags = prependEach "--pkg" packages
    need sources
    system' valac $ ["-C", "-g"] ++ valapkgflags ++ sources
    
-- utilities
prependEach x = foldr (\y a -> x:y:a) []
pkgConfig args = (words . fst) <$> (systemOutput "pkg-config" args)