<#
    subir-version.ps1 — deja la versión al día en los CUATRO lugares que tienen
    que coincidir, que es de donde depende la actualización automática:

        1. APP_VER            en index.html
        2. el pie de página   en index.html
        3. version.txt
        4. el nombre de caché en sw.js

    Si APP_VER y version.txt quedan distintos, cada instalación entra en un
    ciclo de recarga. Por eso el script verifica los cuatro al terminar y
    devuelve error si alguno no quedó bien.

    Uso, desde la carpeta del proyecto:

        powershell -ExecutionPolicy Bypass -File herramientas\subir-version.ps1 3.13
        powershell -ExecutionPolicy Bypass -File herramientas\subir-version.ps1 -Verificar
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string] $Version,

    # No cambia nada: solo informa cómo está cada archivo.
    [switch] $Verificar
)

$ErrorActionPreference = 'Stop'

$raiz    = Split-Path -Parent $PSScriptRoot
$indice  = Join-Path $raiz 'index.html'
$vtxt    = Join-Path $raiz 'version.txt'
$sw      = Join-Path $raiz 'sw.js'

foreach ($f in @($indice, $vtxt, $sw)) {
    if (-not (Test-Path -LiteralPath $f)) { throw "No encuentro $f" }
}

# UTF-8 sin BOM: agregarle un BOM a index.html rompería la primera etiqueta.
$utf8 = New-Object System.Text.UTF8Encoding($false)
function Leer  ($p)       { [System.IO.File]::ReadAllText($p, $utf8) }
function Grabar($p, $txt) { [System.IO.File]::WriteAllText($p, $txt, $utf8) }

function Estado {
    $html = Leer $indice
    [pscustomobject]@{
        AppVer     = if ($html -match 'var APP_VER = "([^"]+)"')                     { $Matches[1] } else { $null }
        Pie        = if ($html -match 'Versión ([0-9]+\.[0-9]+) · Última actualiz')  { $Matches[1] } else { $null }
        VersionTxt = (Leer $vtxt).Trim()
        Cache      = if ((Leer $sw) -match 'calc-superficies-v([0-9]+)')             { $Matches[1] } else { $null }
    }
}

function Informar ($e) {
    "  APP_VER (index.html) : $($e.AppVer)"
    "  pie de página        : $($e.Pie)"
    "  version.txt          : $($e.VersionTxt)"
    "  caché del sw.js      : v$($e.Cache)"
}

if ($Verificar -or -not $Version) {
    $e = Estado
    Informar $e
    $coinciden = ($e.AppVer -eq $e.Pie) -and ($e.AppVer -eq $e.VersionTxt)
    if ($coinciden) { ""; "  Los tres números de versión coinciden."; exit 0 }
    ""; "  NO COINCIDEN. Con APP_VER distinto de version.txt la app se recarga sin parar."
    exit 1
}

if ($Version -notmatch '^[0-9]+\.[0-9]+$') { throw "La versión tiene que ser tipo 3.13, no '$Version'" }

$previo = Estado
if ($previo.AppVer -eq $Version) { throw "La versión $Version ya es la que está puesta" }

$html   = Leer $indice
$sello  = (Get-Date).ToString('dd/MM/yyyy HH:mm')
$cache  = [int]$previo.Cache + 1

$html = $html -replace 'var APP_VER = "[^"]+"', ('var APP_VER = "' + $Version + '"')
$html = $html -replace 'Versión [0-9]+\.[0-9]+ · Última actualización: [^<]*', ('Versión ' + $Version + ' · Última actualización: ' + $sello + ' hs')
Grabar $indice $html

Grabar $vtxt $Version
Grabar $sw ((Leer $sw) -replace 'calc-superficies-v[0-9]+', ('calc-superficies-v' + $cache))

$e = Estado
Informar $e

if ($e.AppVer -ne $Version -or $e.Pie -ne $Version -or $e.VersionTxt -ne $Version -or [int]$e.Cache -ne $cache) {
    throw "Algo no quedó en $Version. Revisá los valores de arriba antes de publicar."
}

""
"  Versión $Version lista ($sello hs). Falta commitear y publicar."
