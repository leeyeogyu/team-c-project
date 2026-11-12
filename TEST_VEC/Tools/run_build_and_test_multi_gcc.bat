@echo off
setlocal EnableExtensions EnableDelayedExpansion
set "SELF=%~nx0"
rem ===========================================================================
rem  GCC (MinGW host) version: VectorCAST build + test + report for SEVERAL
rem  Manage projects (.vcm) found under one folder - WITHOUT PowerShell
rem  (cmd.exe + manage.exe / clicast.exe). Made from run_build_and_test_multi_cmd.bat;
rem  the TASKING / Trace32 handling is replaced by a gcc check. Projects whose
rem  compiler is not gcc / MinGW are skipped (NOT_GCC) - use the _multi_cmd.bat for them.
rem
rem  run_build_and_test_multi_gcc.bat                       (double-click) asks for the folder,
rem                                                         lists its .vcm files, choose + mode
rem  run_build_and_test_multi_gcc.bat /root C:\work\gen3tcu   lists the .vcm under this folder
rem  ... /root C:\work\gen3tcu evComCan_UT_Group1 3          only these projects (name or number)
rem  ... /root C:\work\gen3tcu /all                          all projects, no questions
rem  /skipbuild   no build, run TCs + reports on the existing builds
rem  /noreports   skip Full / Metrics reports
rem  /nopause     do not wait for a key at the end
rem  /tctimeout N stop a test case after N s (default 120, 0 = none)
rem  /legacyqp    build with the legacy QuickParse engine (default: same as the GUI, not set)
rem  /out DIR     result folder (default: local_results\<date_time>\ next to this .bat)
rem
rem  Result mail files (for Jenkins, same layout as nightly_build_and_test.ps1 + Project column):
rem  /mail        also write in the result folder summary.html, summary.csv,
rem               coverage_by_unit.csv, VectorCAST_Full_Report.zip, VectorCAST_Metrics_Report.zip
rem               (cmd only: findstr, tar.exe for the zips, curl.exe for the license check)
rem  /title NAME  name in the first line of summary.html (default multi_gcc)
rem  /nozip       with /mail: no report zips
rem  /summaryonly DIR   run nothing - only (re)write the mail files for the result folder DIR
rem  /exit N      with /summaryonly: exit code to show (default -)
rem
rem  Every project is expected in the standard Manage layout: X.vcm next to its folder X\
rem  with X\environment\ and X\build\. All environments of a chosen project are run.
rem  Results: <out>\summary.txt (all projects), <out>\<project>\ logs + reports\
rem ===========================================================================

rem ---------------------------------------------------------------------------
rem  gcc folder (the one with gcc.exe). Empty = VectorCAST's own MinGW
rem  (%VECTORCAST_DIR%\MinGW\bin, the same one the GUI uses for VectorCAST_MinGW_C);
rem  if that is missing, the gcc found on PATH. Set it only for a project built with
rem  another gcc, e.g.:
rem    set "GCC_DIR=C:\msys64\mingw64\bin"
rem ---------------------------------------------------------------------------
set "GCC_DIR="
rem  Extra tool folders to put in front of PATH, separated by ';'.
rem  The environment variable VCAST_EXTRA_PATH is used as well.
set "EXTRA_PATH="
rem  Name beginning of the process that runs ONE test case (the host test harness).
rem  If the same process runs longer than the TC time limit (/tctimeout, default 120 s)
rem  the bat ends it, and VectorCAST goes on with the next TC.
set "WATCH_EXE=UUT_INST"
rem ---------------------------------------------------------------------------

if defined VECTORCAST_DIR (set "VC=%VECTORCAST_DIR%") else (set "VC=C:\VCAST")
set "MANAGE=%VC%\manage.exe"
set "CLICAST=%VC%\clicast.exe"
if not exist "%MANAGE%" (
    echo ERROR: %MANAGE% not found. Set the VECTORCAST_DIR environment variable.
    set "RC=2"
    goto end
)

rem --- arguments ------------------------------------------------------------------
set "ROOT="
set "OUTROOT="
set "SKIP="
set "NOREP="
set "NOPAUSE="
set "LEGACYQP="
set "ALL="
set "TC_TIMEOUT=120"
set "PICK="
set "ASK=1"
set "MAIL="
set "MTITLE=multi_gcc"
set "MNOZIP="
set "MONLY="
set "RUNEXIT=-"
:parse
if "%~1"=="" goto parsed
if /i "%~1"=="/mail"        (set "MAIL=1" & shift & goto parse)
if /i "%~1"=="/title"       (set "MTITLE=%~2" & shift & shift & goto parse)
if /i "%~1"=="/nozip"       (set "MNOZIP=1" & shift & goto parse)
if /i "%~1"=="/summaryonly" (set "MONLY=1" & set "OUTROOT=%~2" & shift & shift & goto parse)
if /i "%~1"=="/exit"        (set "RUNEXIT=%~2" & shift & shift & goto parse)
if /i "%~1"=="/root"      (set "ROOT=%~2" & shift & shift & goto parse)
if /i "%~1"=="/out"       (set "OUTROOT=%~2" & shift & shift & goto parse)
if /i "%~1"=="/skipbuild" (set "SKIP=1" & set "ASK=" & shift & goto parse)
if /i "%~1"=="/noreports" (set "NOREP=1" & set "ASK=" & shift & goto parse)
if /i "%~1"=="/nopause"   (set "NOPAUSE=1" & shift & goto parse)
if /i "%~1"=="/all"       (set "ALL=1" & set "ASK=" & shift & goto parse)
if /i "%~1"=="/legacyqp"  (set "LEGACYQP=1" & shift & goto parse)
if /i "%~1"=="/tctimeout" (set "TC_TIMEOUT=%~2" & shift & shift & goto parse)
if /i "%~1"=="/?" goto usage
set "PICK=!PICK! "%~1""
set "ASK="
shift
goto parse
:parsed
if defined MONLY (
    call :mail_summary
    set "RC=!MAILRC!"
    goto end
)

rem --- folder to search ------------------------------------------------------------
if not defined ROOT (
    for %%R in ("%~dp0.") do set "DEFROOT=%%~fR"
    echo.
    echo  Folder to search for VectorCAST projects ^(.vcm^), including sub folders.
    set /p "ROOT= Folder (Enter = !DEFROOT!): "
    if not defined ROOT set "ROOT=!DEFROOT!"
)
set "ROOT=%ROOT:"=%"
for %%R in ("%ROOT%\.") do set "ROOT=%%~fR"
if not exist "%ROOT%\" (
    echo ERROR: folder not found: %ROOT%
    set "RC=2"
    goto end
)

rem --- all .vcm files under ROOT ----------------------------------------------------
echo.
echo  Searching %ROOT% ...
set "PN=0"
for /f "delims=" %%F in ('dir /s /b /a-d "%ROOT%\*.vcm" 2^>nul') do (
    rem dir also matches 8.3 short names such as X.vcm_old - keep the real .vcm only
    if /i "%%~xF"==".vcm" (
        set /a PN+=1
        set "VCM_!PN!=%%~fF"
        set "PNAME_!PN!=%%~nF"
    )
)
if "%PN%"=="0" (
    echo ERROR: no .vcm file under %ROOT%
    set "RC=2"
    goto end
)

rem --- choose projects ----------------------------------------------------------------
set "PSEL="
if defined ALL goto pick_all
if defined PICK (
    for %%T in (!PICK!) do (
        call :addproj "%%~T"
        if errorlevel 1 (
            set "RC=2"
            goto end
        )
    )
    goto picked
)
if not defined ASK goto pick_all
echo.
echo  Projects under %ROOT%:
for /l %%I in (1,1,%PN%) do echo    %%I  !PNAME_%%I!
echo  Type numbers or names separated by spaces (e.g. 1 3 5), just Enter = all
:ask_proj
set "ANS="
set /p "ANS= Select: "
set "PSEL="
if not defined ANS goto pick_all
set "BAD="
for %%T in (!ANS!) do (
    call :addproj "%%~T"
    if errorlevel 1 set "BAD=1"
)
if defined BAD (
    echo    Try again.
    goto ask_proj
)
goto picked
:pick_all
for /l %%I in (1,1,%PN%) do set "PSEL=!PSEL! %%I"
:picked

if not defined ASK goto after_ask
echo.
echo  Mode: 1 = build + TCs + reports (default)   2 = TCs + reports without build
set "MODE="
set /p "MODE= Select: "
if "!MODE!"=="2" set "SKIP=1"
rem Confirm before starting - a full rebuild takes hours, so nothing starts without Y.
echo.
echo  Projects:
for %%I in (%PSEL%) do echo    !PNAME_%%I!
if defined SKIP (echo  Mode    : TCs + reports without build) else (echo  Mode    : build + TCs + reports)
set "GO="
set /p "GO= Start? (Y/N): "
if /i not "!GO!"=="Y" (
    echo  Cancelled - nothing was run.
    set "RC=0"
    goto end
)
:after_ask

set "STAMP=%date%_%time%"
for %%C in (":" "." "/" "\" " " ",") do set "STAMP=!STAMP:%%~C=!"
if not defined OUTROOT set "OUTROOT=%~dp0local_results\%STAMP%"
mkdir "%OUTROOT%" 2>nul
if not exist "%OUTROOT%\" (
    echo ERROR: cannot create the result folder %OUTROOT%
    set "RC=2"
    goto end
)
if defined MAIL call :mail_start

echo ============================================================
echo  VectorCAST build + test + report, several projects (cmd only, gcc)
echo  Search  : %ROOT%
set "PCOUNT=0"
for %%I in (%PSEL%) do set /a PCOUNT+=1
echo  Projects: %PCOUNT% of %PN%
if defined SKIP (echo  Build   : skipped ^(existing builds^)) else (echo  Build   : clean rebuild of all environments of each project)
echo  Output  : %OUTROOT%
echo ============================================================
echo  Close the VectorCAST GUI first - it shares the build folders and the license.
echo.

rem --- tool PATH (compiler etc.) -----------------------------------------------------
if defined VCAST_EXTRA_PATH set "PATH=%VCAST_EXTRA_PATH%;%PATH%"
if defined EXTRA_PATH set "PATH=%EXTRA_PATH%;%PATH%"
call :gccsetup
if errorlevel 1 (
    set "RC=2"
    goto end
)
rem Build exactly like the VectorCAST GUI. The legacy QuickParse engine is only
rem switched on with /legacyqp (needed for some VectorCAST 25 projects on 24.sp1).
if defined LEGACYQP (
    set "VCAST_USE_LEGACY_QUICKPARSE=TRUE"
    echo  QuickParse: legacy engine ^(/legacyqp^)
)

> "%OUTROOT%\summary.txt" echo Project / Environment / Result / Manage status line (TESTCASES = passed/run)
set "BUILDFAIL=0"
set "ANYFAIL=0"
for %%I in (%PSEL%) do call :runproject %%I

>> "%OUTROOT%\summary.txt" echo.
>> "%OUTROOT%\summary.txt" echo Per project: %OUTROOT%\^<project^>\summary.txt and reports\
echo.
echo ============================================================
type "%OUTROOT%\summary.txt"
echo.
set "RC=0"
if "%BUILDFAIL%"=="1" set "RC=1"
if "%ANYFAIL%"=="1" set "RC=1"
if "%RC%"=="0" (echo RESULT  : SUCCESS) else (echo RESULT  : FAILURE - see %OUTROOT%\summary.txt)
echo Folder  : %OUTROOT%
if defined MAIL (
    set "RUNEXIT=!RC!"
    call :mail_summary
    if not "!MAILRC!"=="0" set "RC=1"
)
goto end

rem --- one project: number %1 in the VCM_ list ----------------------------------------
:runproject
set "VCM=!VCM_%~1!"
set "PROJ=!PNAME_%~1!"
for %%V in ("%VCM%") do set "WORK=%%~dpnV"
set "OUT=%OUTROOT%\%PROJ%"
echo.
echo ------------------------------------------------------------
echo  PROJECT %PROJ%
echo  %VCM%
echo ------------------------------------------------------------
if not exist "%WORK%\environment\" (
    echo SKIP    no project folder %WORK%\environment - open the project once in the GUI
    >> "%OUTROOT%\summary.txt" echo %PROJ% / - / NO_PROJECT_FOLDER / %WORK%
    set "ANYFAIL=1"
    exit /b 0
)
set "COMP="
set "SUITE="
set "NSUITE=0"
for /f "tokens=3 delims=<>" %%A in ('findstr /r /c:"^ *<name>" "%VCM%"') do if not defined COMP set "COMP=%%A"
for /f tokens^=2^ delims^=^" %%A in ('findstr /c:"<testsuite name=" "%VCM%"') do (
    set /a NSUITE+=1
    if not defined SUITE set "SUITE=%%A"
)
if not defined COMP set "SUITE="
if not defined SUITE (
    echo SKIP    compiler / test suite name not found in the .vcm
    >> "%OUTROOT%\summary.txt" echo %PROJ% / - / VCM_NOT_READ
    set "ANYFAIL=1"
    exit /b 0
)
echo  Level   : %COMP%/%SUITE%
rem gcc projects only: the compiler node is e.g. VectorCAST_MinGW_C, ..._GNU_..., ..._GCC_...
set "ISGCC="
for %%K in (mingw gnu gcc) do echo %COMP% | findstr /i "%%K" >nul && set "ISGCC=1"
if not defined ISGCC (
    echo SKIP    compiler %COMP% is not gcc / MinGW - use run_build_and_test_multi_cmd.bat
    >> "%OUTROOT%\summary.txt" echo %PROJ% / - / NOT_GCC / %COMP%
    exit /b 0
)
if %NSUITE% gtr 1 echo  WARNING : %NSUITE% test suites in the .vcm - only %SUITE% is used
set "SEL="
for /d %%E in ("%WORK%\environment\*") do set "SEL=!SEL! %%~nxE"
if not defined SEL (
    echo SKIP    no environment folders under %WORK%\environment
    >> "%OUTROOT%\summary.txt" echo %PROJ% / - / NO_ENVIRONMENT
    exit /b 0
)
echo  Envs    :%SEL%
mkdir "%OUT%\reports\full" "%OUT%\reports\metrics" 2>nul
> "%OUT%\summary.txt" echo Environment / Result / Manage status line (TESTCASES = passed/run)
if not defined SKIP for %%E in (%SEL%) do call :buildenv %%E
for %%E in (%SEL%) do call :runenv %%E
>> "%OUT%\summary.txt" echo.
>> "%OUT%\summary.txt" echo Manage status for the whole project:
"%MANAGE%" --project="%VCM%" --status > "%OUT%\project_status.txt" 2>&1
findstr /c:"BUILD     BUILD" /c:"TOTALS" "%OUT%\project_status.txt" >> "%OUT%\summary.txt"
exit /b 0

rem --- gcc: the same gcc as the GUI (VectorCAST's MinGW) first on PATH ----------------------
rem The MinGW compiler configuration puts $(VECTORCAST_DIR)/MinGW/bin in front of PATH.
rem A plain command prompt may not have VECTORCAST_DIR, and another gcc on PATH (MSYS2,
rem Cygwin, an older MinGW) would then build with different headers and libraries.
:gccsetup
if not defined VECTORCAST_DIR set "VECTORCAST_DIR=%VC%"
if not defined GCC_DIR if exist "%VC%\MinGW\bin\gcc.exe" set "GCC_DIR=%VC%\MinGW\bin"
if defined GCC_DIR (
    if not exist "!GCC_DIR!\gcc.exe" (
        echo ERROR: no gcc.exe in GCC_DIR=!GCC_DIR!
        exit /b 1
    )
    set "PATH=!GCC_DIR!;!PATH!"
)
set "GCCEXE="
for /f "delims=" %%W in ('where gcc 2^>nul') do if not defined GCCEXE set "GCCEXE=%%W"
if not defined GCCEXE (
    echo ERROR: gcc.exe not found - not in %VC%\MinGW\bin and not on PATH.
    echo        Set GCC_DIR at the top of this .bat.
    exit /b 1
)
set "GCCVER="
for /f "delims=" %%V in ('gcc -dumpversion 2^>nul') do if not defined GCCVER set "GCCVER=%%V"
echo  Compiler: !GCCEXE! ^(gcc !GCCVER!^)
exit /b 0

rem --- builds environment %1, keeping the previous build until the new one succeeds ----
:buildenv
set "E=%~1"
set "OLD="
rem a backup left behind by an interrupted run is put back first
for /d %%D in ("%WORK%\build\*.backup") do if exist "%%D\%E%\" if not exist "%%~dpnD\" ren "%%D" "%%~nD"
for /d %%D in ("%WORK%\build\*") do if exist "%%D\%E%\" if /i not "%%~xD"==".backup" set "OLD=%%D"
if defined OLD (
    if exist "%OLD%.backup" rd /s /q "%OLD%.backup"
    for %%N in ("%OLD%") do ren "%OLD%" "%%~nxN.backup" 2>nul
    if exist "%OLD%.backup\" (
        echo KEEP    previous build moved to %OLD%.backup until the new build succeeds
    ) else (
        rem could not rename - folder in use, e.g. open in the GUI - so fall back to deleting
        echo CLEAN   %OLD%
        rd /s /q "%OLD%"
        set "OLD="
    )
)
echo BUILD   %E%
"%MANAGE%" --project="%VCM%" --level=%COMP%/%SUITE%/%E% --build > "%OUT%\%E%_build.log" 2>&1
rem Success = the test harness exists (UUT_INST.EXE on host, UUT_INST.elf etc. on targets).
set "BUILT="
for /d %%D in ("%WORK%\build\*") do if /i not "%%~xD"==".backup" if exist "%%D\%E%\UUT_INST.*" set "BUILT=1"
if defined BUILT (
    echo         built
    if defined OLD if exist "%OLD%.backup\" rd /s /q "%OLD%.backup"
    exit /b 0
)
echo         BUILD FAILED - see %OUT%\%E%_build.log
for /f "tokens=*" %%L in ('findstr /i /c:"Could not find" /c:"ERROR:" /c:"Licensing" "%OUT%\%E%_build.log"') do echo           %%L
set "BUILDFAIL=1"
if defined OLD if exist "%OLD%.backup\" (
    if exist "%OLD%\" rd /s /q "%OLD%"
    for %%N in ("%OLD%") do ren "%OLD%.backup" "%%~nxN"
    if exist "%OLD%\%E%\" (
        echo         previous build of %E% restored - TCs below run on the previous build
    ) else (
        echo         could not restore the previous build - it is in %OLD%.backup
    )
)
exit /b 0

rem --- runs TCs and reports of environment %1 ------------------------------------------
:runenv
set "E=%~1"
set "PARENT="
for /d %%D in ("%WORK%\build\*") do if /i not "%%~xD"==".backup" if exist "%%D\%E%\UUT_INST.*" set "PARENT=%%D"
if not defined PARENT (
    echo NOBUILD %E%
    >> "%OUT%\summary.txt" echo %E% / BUILD_FAILED
    >> "%OUTROOT%\summary.txt" echo %PROJ% / %E% / BUILD_FAILED
    set "ANYFAIL=1"
    exit /b 0
)
echo EXECUTE %E%
call :execute_watched
pushd "%PARENT%"
"%CLICAST%" -lc -e %E% reports custom management "%OUT%\reports\metrics\%E%_management_report.html" > nul 2>&1
if not defined NOREP (
    echo REPORTS %E%
    "%CLICAST%" -lc -e %E% reports custom full "%OUT%\reports\full\%E%_full_report.html" > nul 2>&1
    "%CLICAST%" -lc -e %E% reports custom metrics "%OUT%\reports\metrics\%E%_metrics_report.html" > nul 2>&1
    "%CLICAST%" -lc -e %E% reports custom csv_metrics "%OUT%\reports\metrics\%E%_metrics.csv" > nul 2>&1
)
popd
"%MANAGE%" --project="%VCM%" --level=%COMP%/%SUITE%/%E% --status > "%OUT%\%E%_status.txt" 2>&1
set "TCLINE="
for /f "tokens=*" %%L in ('findstr /b /c:"  TOTALS" "%OUT%\%E%_status.txt"') do if not defined TCLINE set "TCLINE=%%L"
rem Checked from the weakest to the strongest cause: a later match wins.
set "RES=PASS"
if not exist "%OUT%\reports\metrics\%E%_management_report.html" set "RES=NO_REPORT"
findstr /r /c:"FAIL [0-9]* / [0-9]*" "%OUT%\reports\metrics\%E%_management_report.html" >nul 2>&1 && set "RES=FAIL"
rem e.g. a tool not on PATH - show the line so the folder can go into EXTRA_PATH
findstr /i /c:"Could not find" "%OUT%\%E%_execute.log" >nul && (
    set "RES=TOOL_NOT_FOUND"
    for /f "tokens=*" %%L in ('findstr /i /c:"Could not find" "%OUT%\%E%_execute.log"') do echo           %%L
)
findstr /c:"Licensing Error" "%OUT%\%E%_execute.log" >nul && (
    set "RES=LICENSE_ERROR"
    for /f "tokens=*" %%L in ('findstr /c:"Licensing Error" /c:"FlexNet" "%OUT%\%E%_execute.log"') do echo           %%L
)
if not "%RES%"=="PASS" set "ANYFAIL=1"
echo RESULT  %E%: %RES%
>> "%OUT%\summary.txt" echo %E% / %RES% / %TCLINE%
>> "%OUTROOT%\summary.txt" echo %PROJ% / %E% / %RES% / %TCLINE%
exit /b 0

rem --- manage --execute for %E%, ending any test case that runs longer than TC_TIMEOUT ---
rem Manage rewrites CCAST_.CFG when it executes, so VectorCAST's own TEST_CASE_TIMEOUT option
rem cannot be set from here. Instead Manage runs in the background and this loop watches the
rem process of the current test case (WATCH_EXE): a new process id = a new test case.
:execute_watched
set "DONEFLAG=%OUT%\%E%_execute.done"
set "EXECCMD=%OUT%\%E%_execute.cmd"
if exist "%DONEFLAG%" del "%DONEFLAG%"
> "%EXECCMD%" echo @"%MANAGE%" --project="%VCM%" --level=%COMP%/%SUITE%/%E% --execute ^> "%OUT%\%E%_execute.log" 2^>^&1
>> "%EXECCMD%" echo @echo done^> "%DONEFLAG%"
if not exist "%EXECCMD%" (
    echo         could not write %EXECCMD% - running without the TC time limit
    "%MANAGE%" --project="%VCM%" --level=%COMP%/%SUITE%/%E% --execute > "%OUT%\%E%_execute.log" 2>&1
    exit /b 0
)
if "%TC_TIMEOUT%"=="0" (
    echo         no TC time limit ^(/tctimeout 0^)
    call "%EXECCMD%"
    exit /b 0
)
echo         TC time limit %TC_TIMEOUT% s ^(watching %WATCH_EXE% processes^)
start "" /b cmd /d /c "%EXECCMD%"
set "WPID="
set /a WAITED=0
set /a KILLS=0
:watch_loop
if exist "%DONEFLAG%" goto watch_done
rem 5 s pause; 'timeout' refuses to run when input is redirected, ping does not
ping -n 6 127.0.0.1 > nul 2>&1
set "CPID="
set "CNAME="
for %%X in (%WATCH_EXE%) do for /f "tokens=1,2 delims=," %%A in ('tasklist /fi "imagename eq %%X*" /fo csv /nh 2^>nul') do if not "%%~B"=="" (
    set "CPID=%%~B"
    set "CNAME=%%~A"
)
if not defined CPID (
    set "WPID="
    set /a WAITED=0
    goto watch_loop
)
if not "%CPID%"=="%WPID%" (
    set "WPID=%CPID%"
    set /a WAITED=0
    goto watch_loop
)
set /a WAITED+=5
if %WAITED% lss %TC_TIMEOUT% goto watch_loop
echo         TC TIME LIMIT: %CNAME% ^(pid %CPID%^) ran %WAITED% s - ended, going on with the next TC
taskkill /pid %CPID% /t /f > nul 2>&1
set /a KILLS+=1
set "WPID="
set /a WAITED=0
goto watch_loop
:watch_done
if %KILLS% gtr 0 (
    >> "%OUT%\summary.txt" echo %E% / %KILLS% test case^(s^) stopped after %TC_TIMEOUT% s ^(infinite loop?^)
    >> "%OUTROOT%\summary.txt" echo %PROJ% / %E% / %KILLS% test case^(s^) stopped after %TC_TIMEOUT% s ^(infinite loop?^)
    set "ANYFAIL=1"
)
del "%DONEFLAG%" "%EXECCMD%" > nul 2>&1
exit /b 0

rem --- adds project %1 (number or .vcm name, case-insensitive) to PSEL -----------------
:addproj
set "TOKEN=%~1"
set "HIT="
for /l %%I in (1,1,%PN%) do (
    if "!TOKEN!"=="%%I" set "HIT=%%I"
    if /i "!TOKEN!"=="!PNAME_%%I!" set "HIT=%%I"
)
if not defined HIT (
    echo    '%~1' is not a project under %ROOT%.
    exit /b 1
)
echo %PSEL% | findstr /c:" %HIT% " >nul || set "PSEL=%PSEL% %HIT%"
exit /b 0

rem ================================================================================
rem  Result mail files (/mail, /summaryonly) - cmd only
rem ================================================================================

rem --- remembers the start time in <out>\run_start.txt (for Start / Elapsed in summary.html) ---
:mail_start
call :m_now MSTART_S
set "MT=%time: =0%"
> "%OUTROOT%\run_start.txt" echo START_TXT=%date% %MT:~0,5%
>> "%OUTROOT%\run_start.txt" echo START_S=%MSTART_S%
exit /b 0

rem --- writes summary.html / summary.csv / coverage_by_unit.csv / zips in OUTROOT -------
rem     reads <out>\summary.txt and <out>\<project>\reports\ ; sets MAILRC (0 = SUCCESS)
:mail_summary
setlocal
for %%R in ("%OUTROOT%\.") do set "OUT=%%~fR"
if not exist "%OUT%\summary.txt" (
    echo MAIL    no summary.txt in %OUT% - no mail files written
    endlocal & set "MAILRC=2"
    exit /b 0
)
echo.
echo MAIL    writing summary.html / summary.csv / coverage_by_unit.csv / zips in %OUT%

rem --- start / elapsed ---
set "START_TXT=-"
set "START_S="
if exist "%OUT%\run_start.txt" for /f "usebackq tokens=1* delims==" %%a in ("%OUT%\run_start.txt") do set "%%a=%%b"
set "ELAPSED=-"
if defined START_S (
    call :m_now END_S
    set /a "SEC=END_S-START_S"
    rem past midnight (runs are shorter than a day)
    if !SEC! lss 0 set /a "SEC+=86400"
    set /a "T10=(SEC*10+30)/60, EM=T10/10, ET=T10%%10"
    set "ELAPSED=!EM!.!ET!"
)

rem --- license server (VECTOR_LICENSE_FILE = port@host[;port@host...]) ---
set "LIC=License server: (VECTOR_LICENSE_FILE not set)"
if not defined VECTOR_LICENSE_FILE goto m_lic_done
set "LICOK="
for %%L in ("%VECTOR_LICENSE_FILE:;=" "%") do if not defined LICOK call :m_licone "%%~L"
if defined LICOK (
    set "LIC=License server (%VECTOR_LICENSE_FILE%): OK"
) else (
    set "LIC=License server (%VECTOR_LICENSE_FILE%): <b style='color:#cf222e'>UNREACHABLE</b>"
)
:m_lic_done

rem --- result rows from summary.txt ---
set "ROWS=%OUT%\_rows.tmp"
set "COVS=%OUT%\_cov.tmp"
set "CSV=%OUT%\summary.csv"
set "COVCSV=%OUT%\coverage_by_unit.csv"
type nul > "%ROWS%"
type nul > "%COVS%"
> "%CSV%" echo "Project","Environment","Result","Run","Passed","Failed","FailedTests"
> "%COVCSV%" echo "Project","Environment","Unit","CoveredFunctions","TotalFunctions","CoveredCalls","TotalCalls"
set "NROW=0"
set "NPROJ=0"
set "NCOV=0"
set "TOTRUN=0"
set "TOTPASS=0"
set "MBAD=0"
rem pass 1: the "test case(s) stopped" notes, pass 2: the result rows
for %%S in (1 2) do (
    set "SCAN=%%S"
    for /f "usebackq tokens=1,2,3* delims=/" %%A in ("%OUT%\summary.txt") do (
        set "P=%%A"
        set "E=%%B"
        set "R=%%C"
        set "D=%%D"
        call :m_onerow
    )
)

rem --- zips ---
set "ZIPNOTE=<p>VectorCAST reports: none produced.</p>"
set "ZIPLIST="
if not defined MNOZIP (
    call :m_zipone "reports/full" VectorCAST_Full_Report.zip
    call :m_zipone "reports/metrics" VectorCAST_Metrics_Report.zip
)
if defined ZIPLIST set "ZIPNOTE=<p>Attached VectorCAST reports: !ZIPLIST:~2!</p>"

rem --- overall ---
set "OVERALL=SUCCESS"
if "%NROW%"=="0" set "OVERALL=FAILURE"
if not "%MBAD%"=="0" set "OVERALL=FAILURE"
if not "%RUNEXIT%"=="-" if not "%RUNEXIT%"=="0" set "OVERALL=FAILURE"

rem --- summary.html ---
set "HTML=%OUT%\summary.html"
set "H=<html><body style='font-family:Segoe UI,Malgun Gothic,sans-serif;font-size:13px'>"
> "%HTML%" echo(!H!
set "H=<h3>VectorCAST nightly - !MTITLE! : !OVERALL!</h3>"
>> "%HTML%" echo(!H!
set "H=<p>Start: !START_TXT! / Elapsed: !ELAPSED! min / Exit code: !RUNEXIT! / Projects: !NPROJ! / Tests: !TOTPASS! / !TOTRUN! passed / !LIC!</p>"
>> "%HTML%" echo(!H!
set "H=<table border='1' cellpadding='4' cellspacing='0' style='border-collapse:collapse'>"
>> "%HTML%" echo(!H!
set "H=<tr style='background:#eee'><th>Project</th><th>Environment</th><th>Result</th><th>Run</th><th>Passed</th><th>Failed</th><th>Failed tests</th></tr>"
>> "%HTML%" echo(!H!
type "%ROWS%" >> "%HTML%"
set "H=</table>"
>> "%HTML%" echo(!H!
>> "%HTML%" echo(!ZIPNOTE!
if "%NCOV%"=="0" (
    set "H=<p>Coverage: no metrics report was produced.</p>"
    >> "%HTML%" echo(!H!
) else (
    set "H=<h4>Coverage by unit (Function / Function Call)</h4>"
    >> "%HTML%" echo(!H!
    set "H=<table border='1' cellpadding='4' cellspacing='0' style='border-collapse:collapse'>"
    >> "%HTML%" echo(!H!
    set "H=<tr style='background:#eee'><th>Project</th><th>Environment</th><th>Unit</th><th>Functions</th><th>Function calls</th></tr>"
    >> "%HTML%" echo(!H!
    type "%COVS%" >> "%HTML%"
    set "H=</table>"
    >> "%HTML%" echo(!H!
)
set "H=</body></html>"
>> "%HTML%" echo(!H!
del "%ROWS%" "%COVS%" > nul 2>&1

echo MAIL    %OVERALL% - %HTML%
if "%OVERALL%"=="SUCCESS" (set "MRC=0") else (set "MRC=1")
endlocal & set "MAILRC=%MRC%"
exit /b 0

rem --- one line of summary.txt: P / E / R / D ------------------------------------------
:m_onerow
call :m_trim P
call :m_trim E
call :m_trim R
if not defined E exit /b 0
if not defined R exit /b 0
if "!P!"=="Project" if "!E!"=="Environment" exit /b 0
rem "<n> test case(s) stopped after <s> s (infinite loop?)"
if not "!R:stopped after=!"=="!R!" (
    if "!SCAN!"=="1" set "NOTE[!P!][!E!]=!R!"
    exit /b 0
)
if "!SCAN!"=="1" exit /b 0
set /a NROW+=1
if not defined PSEEN[!P!] (
    set "PSEEN[!P!]=1"
    set /a NPROJ+=1
)
set "MRES=!R!"
set "RUN=0"
set "PASSN=0"
set "FT="
set "SKIPROW="
if "!E!"=="-" (
    call :m_trim D
    if "!MRES!"=="NOT_GCC" set "SKIPROW=1"
    if "!MRES!"=="NO_ENVIRONMENT" set "SKIPROW=1"
    if defined SKIPROW (set "FT=skipped: !D!") else (set "FT=!D!")
    goto m_row_write
)
set "MG=%OUT%\!P!\reports\metrics\!E!_management_report.html"
if exist "!MG!" (
    call :m_mgmt
    rem PASS / FAIL from the test case rows, as nightly_build_and_test.ps1 does
    if "!R!"=="PASS" set "MRES=DECIDE"
    if "!R!"=="FAIL" set "MRES=DECIDE"
    if "!MRES!"=="DECIDE" (
        if !RUN! equ 0 (
            set "MRES=NO_TESTS"
        ) else if !PASSN! equ !RUN! (
            set "MRES=PASS"
        ) else (
            set "MRES=FAIL"
        )
    )
)
if defined NOTE[!P!][!E!] (
    set "NT=(!NOTE[%P%][%E%]!)"
    if defined FT (set "FT=!FT!; !NT!") else (set "FT=!NT!")
    if "!MRES!"=="PASS" set "MRES=TC_TIMEOUT"
)
set "MC=%OUT%\!P!\reports\metrics\!E!_metrics.csv"
if exist "!MC!" call :m_coverage
:m_row_write
set /a "FAILN=RUN-PASSN, TOTRUN+=RUN, TOTPASS+=PASSN"
set "COLOR=#cf222e"
if "!MRES!"=="PASS" set "COLOR=#1a7f37"
if "!MRES!"=="TC_TIMEOUT" set "COLOR=#bc4c00"
if defined SKIPROW set "COLOR=#6e7781"
if not "!MRES!"=="PASS" if not defined SKIPROW set /a MBAD+=1
set "FTH="
if defined FT (
    set "FTH=!FT:&=&amp;!"
    set "FTH=!FTH:<=&lt;!"
    set "FTH=!FTH:>=&gt;!"
)
set "H=<tr><td>!P!</td><td>!E!</td><td style='color:!COLOR!;font-weight:bold'>!MRES!</td><td>!RUN!</td><td>!PASSN!</td><td>!FAILN!</td><td>!FTH!</td></tr>"
>> "%ROWS%" echo(!H!
>> "%CSV%" echo "!P!","!E!","!MRES!","!RUN!","!PASSN!","!FAILN!","!FT!"
exit /b 0

rem --- Management Report test case rows ------------------------------------------------
rem   <td ...>NAME</td><td ...>22 OCT 2026  2:19:32 PM</td><td ...>FAIL 0 / 1</td>
rem (compound rows show just PASS / FAIL without counts)
:m_mgmt
rem %MG% (not !MG!): on a line with ! cmd also strips the ^ inside quotes, breaking [^>]
for /f "usebackq delims=" %%L in (`findstr /r /c:"[AP]M</td><td[^>]*>PASS" /c:"[AP]M</td><td[^>]*>FAIL" "%MG%"`) do (
    set "L=%%L"
    call :m_tcrow
)
exit /b 0

:m_tcrow
set "L=!L:"=!"
set "L=!L:*<td=!"
set "L=!L:*<td=!"
set "L=!L:*<td=!"
set "L=!L:*>=!"
set "N="
for /f "delims=<" %%N in ("!L!") do set "N=%%N"
if not defined N exit /b 0
if defined SEEN[!NROW!][!N!] exit /b 0
set "SEEN[!NROW!][!N!]=1"
set /a RUN+=1
if not "!L:>PASS=!"=="!L!" (
    set /a PASSN+=1
) else (
    if defined FT (set "FT=!FT!; !N!") else (set "FT=!N!")
)
exit /b 0

rem --- metrics CSV: Unit,Subprogram,Complexity,Cover %% Function,Covered Functions,
rem     Total Functions,Cover %% Call,Covered Calls,Total Calls  - summed per unit ---------
:m_coverage
set "NU=0"
for /f "usebackq skip=1 tokens=1,5,6,8,9 delims=," %%a in ("!MC!") do (
    if not defined CU[!NROW!][%%a] (
        set /a NU+=1
        set "CU[!NROW!][%%a]=!NU!"
        set "UN[!NU!]=%%a"
        set /a "CF[!NU!]=0, TF[!NU!]=0, CC[!NU!]=0, TC[!NU!]=0"
    )
    set "IX=!CU[%NROW%][%%a]!"
    set /a "CF[!IX!]+=%%b, TF[!IX!]+=%%c, CC[!IX!]+=%%d, TC[!IX!]+=%%e"
)
for /l %%i in (1,1,!NU!) do (
    call :m_fmtcov !CF[%%i]! !TF[%%i]! F1
    call :m_fmtcov !CC[%%i]! !TC[%%i]! F2
    set "H=<tr><td>!P!</td><td>!E!</td><td>!UN[%%i]!</td><td>!F1!</td><td>!F2!</td></tr>"
    >> "%COVS%" echo(!H!
    >> "%COVCSV%" echo "!P!","!E!","!UN[%%i]!","!CF[%%i]!","!TF[%%i]!","!CC[%%i]!","!TC[%%i]!"
    set /a NCOV+=1
)
exit /b 0

rem --- "covered / total (pct%)" or "-" when total is 0 --------------------------------
:m_fmtcov
if "%~2"=="0" (
    set "%~3=-"
    exit /b 0
)
set /a "PCT=%~1*100/%~2"
set "%~3=%~1 / %~2 (!PCT!%%)"
exit /b 0

rem --- zip <project>/<sub>/* of every project into %OUT%\%2 --------------------------
:m_zipone
set "SUB=%~1"
set "ZIP=%OUT%\%~2"
set "LST=%OUT%\_zip.lst"
if exist "%ZIP%" del "%ZIP%"
type nul > "%LST%"
set "NF=0"
for /d %%P in ("%OUT%\*") do if exist "%%P\%SUB:/=\%\" for %%F in ("%%P\%SUB:/=\%\*") do (
    >> "%LST%" echo(%%~nxP/%SUB%/%%~nxF
    set /a NF+=1
)
if "%NF%"=="0" (
    del "%LST%"
    exit /b 0
)
set "TAR=%SystemRoot%\System32\tar.exe"
if not exist "%TAR%" (
    echo MAIL    %TAR% not found - %~2 not made
    del "%LST%"
    exit /b 0
)
"%TAR%" -a -c -f "%ZIP%" -C "%OUT%" -T "%LST%"
del "%LST%"
if not exist "%ZIP%" (
    echo MAIL    could not make %ZIP%
    exit /b 0
)
for %%Z in ("%ZIP%") do set "SZ=%%~zZ"
set /a "KB=SZ/1024, T10=(KB*10+512)/1024, MB=T10/10, MD=T10%%10"
set "ZIPLIST=!ZIPLIST!, %~2 (!MB!.!MD! MB, !NF! files)"
echo ZIP     %ZIP%
exit /b 0

rem --- license server reachable? %1 = port@host (other entries, e.g. files, are skipped) ---
:m_licone
set "LPORT="
set "LHOST="
for /f "tokens=1,2 delims=@" %%a in ("%~1") do (
    set "LPORT=%%a"
    set "LHOST=%%b"
)
if not defined LHOST exit /b 0
set "LCURL=%SystemRoot%\System32\curl.exe"
if not exist "%LCURL%" exit /b 0
rem curl prints the remote address only when the TCP connection was made
for /f "delims=" %%r in ('%LCURL% -s -o NUL --connect-timeout 5 -m 6 -w "%%{remote_ip}" telnet://%LHOST%:%LPORT% ^<NUL 2^>NUL') do set "LICOK=1"
exit /b 0

rem --- seconds since midnight of %time% into variable %1 -------------------------------
:m_now
set "NT_=%time: =0%"
set /a "%~1=(1%NT_:~0,2%-100)*3600+(1%NT_:~3,2%-100)*60+(1%NT_:~6,2%-100)"
exit /b 0

rem --- remove leading / trailing spaces of variable %1 ------------------------------------
:m_trim
if not defined %~1 exit /b 0
if "!%~1:~0,1!"==" " (
    set "%~1=!%~1:~1!"
    goto m_trim
)
if "!%~1:~-1!"==" " (
    set "%~1=!%~1:~0,-1!"
    goto m_trim
)
exit /b 0

:usage
echo Usage: %SELF% [/root FOLDER] [PROJECT ...] [/all] [/skipbuild] [/noreports] [/nopause]
echo        [/tctimeout SEC] [/legacyqp] [/out FOLDER] [/mail [/title NAME] [/nozip]]
echo        %SELF% /summaryonly FOLDER [/exit N] [/title NAME] [/nozip]
echo PROJECT = .vcm name without extension, or its number in the list.
set "RC=0"

:end
if not defined NOPAUSE pause
exit /b %RC%
