setlocal

call "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars32.bat"

set config=Release
set target=targets\win32\x86
set include=targets\include
set build=build-win32

if /I [%1] == [rebuild] (
	set option="-t:Rebuild"
	rd /q /s flac\%build%
	rd /q /s ogg\%build%
	rd /q /s soxr\%build%
	rd /q /s vorbis\%build%
	rd /q /s opus\%build%
)

if not exist ogg\%build% (
	mkdir ogg\%build%
	cd ogg\%build%
	cmake .. -A Win32
	cd ..\..
)	

if not exist flac\%build% (
	mkdir flac\%build%
	cd flac\%build%
	cmake .. -A Win32 -DOGG_LIBRARY=..\..\ogg -DOGG_INCLUDE_DIR=..\..\ogg\include -DINSTALL_MANPAGES=OFF
	cd ..\..
)	

if not exist soxr\%build% (
	mkdir soxr\%build%
	cd soxr\%build%
	cmake .. -A Win32 -Wno-dev -DCMAKE_BUILD_TYPE="%config%" -DBUILD_SHARED_LIBS=OFF
	cd ..\..
)	

if not exist vorbis\%build% (
	mkdir vorbis\%build%
	cd vorbis\%build%
	cmake .. -A Win32 -DOGG_LIBRARY=..\..\ogg -DOGG_INCLUDE_DIR=..\..\ogg\include -DINSTALL_MANPAGES=OFF
	cd ..\..
)	

if not exist opus\%build% (
	mkdir opus\%build%
	cd opus\%build%
	cmake .. -A Win32 -DOP_DISABLE_EXAMPLES=ON -DOP_DISABLE_DOCS=ON -DOP_DISABLE_HTTP=ON
	cd ..\..
)	

REM opusfile should be build using cmake asw ell but it's package dependencies prevent it

msbuild libcodecs.sln /property:Configuration=%config% %option%

if exist %target% (
	del %target%\*.lib
)

REM this takes care of alac, mad, shine and opusfile
robocopy lib\x86 %target% *.lib *.pdb /NDL /NJH /NJS /nc /ns /np
robocopy .libs %target% *.lib *.pdb /NDL /NJH /NJS /nc /ns /np

REM this takes care of flac, ogg, soxr and vorbis
robocopy flac\%build%\src\libFLAC\%config% %target% *.lib *.pdb /NDL /NJH /NJS /nc /ns /np
robocopy flac\%build%\src\share\utf8\%config% %target% *.lib *.pdb /NDL /NJH /NJS /nc /ns /np
robocopy ogg\%build%\%config% %target% *.lib *.pdb /NDL /NJH /NJS /nc /ns /np
robocopy vorbis\%build%\lib\%config% %target% *.lib *.pdb /NDL /NJH /NJS /nc /ns /np
robocopy opus\%build%\%config% %target% *.lib *.pdb /NDL /NJH /NJS /nc /ns /np
robocopy faad2\libfaad\%config% %target% *.lib *.pdb /NDL /NJH /NJS /nc /ns /np
robocopy soxr\%build%\src\%config% %target% *.lib *.pdb /NDL /NJH /NJS /nc /ns /np
robocopy addons\build %target% *.lib *.pdb /NDL /NJH /NJS /nc /ns /np

rem flac & ogg don't seem to really have per-platform different config files (thanks stdint)
robocopy flac\include %include%\flac *.h /S /NDL /NJH /NJS /nc /ns /np /XD test*
robocopy ogg\include %include%\ogg *.h /S /NDL /NJH /NJS /nc /ns /np
robocopy vorbis\include %include%\vorbis *.h /S /NDL /NJH /NJS /nc /ns /np
robocopy opus\include %include%\opus *.h /NDL /NJH /NJS /nc /ns /np
robocopy opusfile\include %include%\opusfile *.h /NDL /NJH /NJS /nc /ns /np
robocopy faad2\include %include%\faad2 *.h /NDL /NJH /NJS /nc /ns /np
robocopy soxr\src %include%\soxr soxr.h /NDL /NJH /NJS /nc /ns /np
robocopy mad %include%\mad mad.h /NDL /NJH /NJS /nc /ns /np
robocopy alac\codec %include%\alac ALAC*.h /NDL /NJH /NJS /nc /ns /np
robocopy shine\src\lib %include%\shine layer3.h /NDL /NJH /NJS /nc /ns /np
robocopy addons %include%\addons alac_wrapper.h /NDL /NJH /NJS /nc /ns /np

lib.exe /OUT:%target%/libcodecs.lib %target%/*.lib

endlocal

