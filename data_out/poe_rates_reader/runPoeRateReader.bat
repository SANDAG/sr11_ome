@ECHO off

ECHO #############################################
ECHO POE RATES READER - SANDAG (OTAY MESA)
ECHO.
ECHO Ashish Kulshrestha (kulshresthaa@pbworld.com)
ECHO Parsons Brinckerhoff
ECHO %Date%
ECHO #############################################

SET rPath="C:\Program Files\R\R-3.2.5\bin\x64"

SET codePath="C:\Users\kulshresthaa\Desktop\SANDAG\OtayMesa\poe_rates_reader"

%rPath%\Rscript.exe "%codePath%\run.R" "%codePath%"