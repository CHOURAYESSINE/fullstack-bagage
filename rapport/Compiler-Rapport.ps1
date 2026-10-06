$ErrorActionPreference = 'Stop'
Push-Location $PSScriptRoot
try {
    for ($pass = 1; $pass -le 3; $pass++) {
        & pdflatex -interaction=nonstopmode -halt-on-error -file-line-error rapport-bagages.tex
        if ($LASTEXITCODE -ne 0) { throw 'Compilation échouée : consulter rapport-bagages.log.' }
    }
    Write-Host 'PDF prêt : rapport-bagages.pdf'
} finally { Pop-Location }
