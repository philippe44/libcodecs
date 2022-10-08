setlocal

call "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars32.bat"

REM cd flac && mkdir build && cd build
REM cmake .. -A Win32 -DOGG_LIBRARY=..\..\ogg -DOGG_INCLUDE_DIR=..\..\ogg\include -DINSTALL_MANPAGES=OFF
REM cd ..

REM cd ogg && mkdir build && cd build
REM cmake .. -A Win32 
REM cd ..

set config=Release
msbuild libcodecs.sln /property:Configuration=%config% %1

set target=targets\win32\x86
set include=targets\include

if exist %target% (
	del %target%\*.lib
)

robocopy lib\x86 %target% *.lib *.pdb /NDL /NJH /NJS /nc /ns /np
robocopy .libs %target% *.lib *.pdb /NDL /NJH /NJS /nc /ns /np
robocopy flac\build\src\libFLAC\%config% %target% *.lib *.pdb /NDL /NJH /NJS /nc /ns /np
robocopy flac\build\src\share\utf8\%config% %target% *.lib *.pdb /NDL /NJH /NJS /nc /ns /np

robocopy ogg\include %include%\ogg *.h /NDL /NJH /NJS /nc /ns /np
robocopy alac\codec %include%\alac ALAC*.h /NDL /NJH /NJS /nc /ns /np
robocopy flac\include %include%\flac *.h /S /NDL /NJH /NJS /nc /ns /np /XD test*
robocopy shine\src\lib %include%\shine layer3.h /NDL /NJH /NJS /nc /ns /np

lib.exe /OUT:%target%/libcodecs.lib %target%/*.lib

endlocal

