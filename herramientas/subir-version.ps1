<#
    subir-version.ps1 — deja la versión al día en los TRES lugares que tienen
    que coincidir, que es de donde depende la actualización automática:

        1. APP_VER            en index.html
        2. version.txt
        3. el nombre de caché en sw.js

    Si APP_VER y version.txt quedan distintos, cada instalación entra en un
    ciclo de recarga. Por eso el script verifica los tres al terminar y
    devuelve error si alguno no quedó bien.

    ERAN CUATRO hasta la v15.0. El cuarto era el número escrito a mano en el pie
    de página, que se quedó clavado en "14.1" mientras el programa llegaba a la
    14.9: ocho versiones mintiendo, justo donde uno mira para saber qué versión
    tiene cargada. Desde la v15.0 el pie lo lee de APP_VER y ya no hay que
    tocarlo. Este script siguió buscándolo igual, así que desde entonces daba
    falsa alarma —"NO COINCIDEN … la app se recarga sin parar"— con los tres
    números correctos. Corregido en la v15.7.

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
        AppVer     = if ($html -match 'var APP_VER = "([^"]+)"')          { $Matches[1] } else { $null }
        VersionTxt = (Leer $vtxt).Trim()
        Cache      = if ((Leer $sw) -match 'calc-superficies-v([0-9]+)')  { $Matches[1] } else { $null }
        # El pie ya no se lee: desde la v15.0 lo arma el propio programa con APP_VER.
        PieAuto    = $html -match 'id="pie-version"'
    }
}

function Informar ($e) {
    "  APP_VER (index.html) : $($e.AppVer)"
    "  version.txt          : $($e.VersionTxt)"
    "  caché del sw.js      : v$($e.Cache)"
    "  pie de página        : " + $(if ($e.PieAuto) { "lo lee de APP_VER (no hay que tocarlo)" }
                                    else { "OJO: falta el id pie-version, el pie no se va a actualizar" })
}

if ($Verificar -or -not $Version) {
    $e = Estado
    Informar $e
    $coinciden = ($e.AppVer -eq $e.VersionTxt) -and $e.PieAuto
    if ($coinciden) { ""; "  APP_VER y version.txt coinciden, y el pie se arma solo."; exit 0 }
    ""
    if ($e.AppVer -ne $e.VersionTxt) {
        "  NO COINCIDEN. Con APP_VER distinto de version.txt la app se recarga sin parar."
    } else {
        "  Falta el id pie-version en index.html: el pie no va a mostrar la versión."
    }
    exit 1
}

if ($Version -notmatch '^[0-9]+\.[0-9]+$') { throw "La versión tiene que ser tipo 3.13, no '$Version'" }

$previo = Estado
if ($previo.AppVer -eq $Version) { throw "La versión $Version ya es la que está puesta" }

$html   = Leer $indice
$cache  = [int]$previo.Cache + 1

# Solo APP_VER: el pie lo deriva el propio programa desde la v15.0.
$html = $html -replace 'var APP_VER = "[^"]+"', ('var APP_VER = "' + $Version + '"')
Grabar $indice $html

Grabar $vtxt $Version
Grabar $sw ((Leer $sw) -replace 'calc-superficies-v[0-9]+', ('calc-superficies-v' + $cache))

$e = Estado
Informar $e

if ($e.AppVer -ne $Version -or $e.VersionTxt -ne $Version -or [int]$e.Cache -ne $cache) {
    throw "Algo no quedó en $Version. Revisá los valores de arriba antes de publicar."
}

""
"  Versión $Version lista. Falta correr las pruebas (?pruebas=1), commitear y publicar."
