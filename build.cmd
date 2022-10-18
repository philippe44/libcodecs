setlocal

call "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars32.bat"

if /I [%1] == [rebuild] (
	rd /q /s flac\build
	rd /q /s ogg\build
)

if not exist ogg\build (
	mkdir ogg\build
	cd ogg\build
	cmake .. -A Win32
	cd ..\..
)	

if not exist flac\build (
	mkdir flac\build
	cd flac\build
	cmake .. -A Win32 -DOGG_LIBRARY=..\..\ogg -DOGG_INCLUDE_DIR=..\..\ogg\include -DINSTALL_MANPAGES=OFF
	cd ..\..
)	

if /I [%1] == [rebuild] (
	set option="-t:Rebuild"
)

set config=Release
set target=targets\win32\x86
set include=targets\include

msbuild libcodecs.sln /property:Configuration=%config% %option%

if exist %target% (
	del %target%\*.lib
)

robocopy lib\x86 %target% *.lib *.pdb /NDL /NJH /NJS /nc /ns /np
robocopy .libs %target% *.lib *.pdb /NDL /NJH /NJS /nc /ns /np

robocopy flac\build\src\libFLAC\%config% %target% *.lib *.pdb /NDL /NJH /NJS /nc /ns /np
robocopy flac\build\src\share\utf8\%config% %target% *.lib *.pdb /NDL /NJH /NJS /nc /ns /np
robocopy ogg\build\%config% %target% *.lib /NDL /NJH /NJS /nc /ns /np
robocopy addons\build %target% *.lib /NDL /NJH /NJS /nc /ns /np

rem flac & ogg don't seem to really have per-platform different config files (thanks stdint)
robocopy flac\include %include%\flac *.h /S /NDL /NJH /NJS /nc /ns /np /XD test*
robocopy ogg\include %include%\ogg *.h /S /NDL /NJH /NJS /nc /ns /np
robocopy mad %include%\mad mad.h /NDL /NJH /NJS /nc /ns /np
robocopy alac\codec %include%\alac ALAC*.h /NDL /NJH /NJS /nc /ns /np
robocopy shine\src\lib %include%\shine layer3.h /NDL /NJH /NJS /nc /ns /np
robocopy addons %include%\addons alac_wrapper.h /NDL /NJH /NJS /nc /ns /np

lib.exe /OUT:%target%/libcodecs.lib %target%/*.lib

endlocal

