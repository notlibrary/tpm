:: driver version 1.1.12
:: https://github.com/tcltk/tdbcpostgres
nmake /f makefile.vc TCLINSTALL=0 TCL_VERSION=87 TCLDIR=C:\Tcl TCL_INCLUDES=-I"C:\Tcl\include" TCLSTUBLIB="C:\Tcl\lib\libtclstub87.a" COFFBASE=makefile
nmake /f makefile.vc TCLINSTALL=0 TCL_VERSION=87 TCLDIR=C:\Tcl TCL_INCLUDES=-I"C:\Tcl\include" TCLSTUBLIB="C:\Tcl\lib\libtclstub87.a" COFFBASE=makefile INSTALLDIR="C:\Tcl" install

:: driver version 1.1.14
:: fossil clone https://core.tcl-lang.org/tdbcpostgres 
nmake /f makefile.vc TCLINSTALL=0 TCL_VERSION=87 TCLDIR=C:\Tcl TCL_INCLUDES="-I\"C:\Tcl\include\" -I\"C:\Tcl\lib\tdbc1.1.2\"" TCLSTUBLIB="C:\Tcl\lib\libtclstub87.a" COFFBASE=makefile OPTS=none COMPILERFLAGS="/DTCL_SIZE_MODIFIER=\"\""
nmake /f makefile.vc TCLINSTALL=0 TCL_VERSION=87 TCLDIR=C:\Tcl TCL_INCLUDES="-I\"C:\Tcl\include\" -I\"C:\Tcl\lib\tdbc1.1.2\"" TCLSTUBLIB="C:\Tcl\lib\libtclstub87.a" COFFBASE=makefile OPTS=none COMPILERFLAGS="/DTCL_SIZE_MODIFIER=\"\"" install
