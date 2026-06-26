# Script de Validação de Links Locais do Monorepo
$baseDir = Split-Path -Path $MyInvocation.MyCommand.Path -Parent | Split-Path -Parent
$allMdFiles = Get-ChildItem -Path $baseDir -Filter *.md -Recurse

$brokenCount = 0
$totalLinks = 0

foreach ($file in $allMdFiles) {
    # Skip temporary files or system folders if any
    if ($file.FullName -like "*\.git\*" -or $file.FullName -like "*\node_modules\*") {
        continue
    }
    
    $content = Get-Content -Raw -Path $file.FullName
    
    # Match any Markdown link [text](url)
    $matches = [regex]::Matches($content, '\[[^\]]*\]\(([^)]+)\)')
    foreach ($m in $matches) {
        $url = $m.Groups[1].Value
        
        # Skip external links and internal page anchors
        if ($url -like "http:*" -or $url -like "https:*" -or $url -like "mailto:*" -or $url -like "#*") {
            continue
        }
        
        $totalLinks++
        
        # Clean file:/// prefix if present
        $cleanPath = $url -replace '^file:///', ''
        # Remove query parameters or anchors
        $cleanPath = $cleanPath -replace '\?.*$', ''
        $cleanPath = $cleanPath -replace '#.*$', ''
        # Replace forward slashes with backslashes
        $cleanPath = $cleanPath.Replace('/', '\')
        $cleanPath = [System.Uri]::UnescapeDataString($cleanPath)
        
        # If it's a relative path, resolve it against the file's parent folder
        if (-not [System.IO.Path]::IsPathRooted($cleanPath)) {
            $currentDir = Split-Path -Path $file.FullName -Parent
            $cleanPath = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($currentDir, $cleanPath))
        }
        
        if (-not (Test-Path $cleanPath)) {
            Write-Host "LINK QUEBRADO em $($file.FullName):"
            Write-Host "  URL original: $url"
            Write-Host "  Caminho resolvido inexistente: $cleanPath"
            $brokenCount++
        }
    }
}

Write-Host "Validação concluída!"
Write-Host "Total de links locais verificados: $totalLinks"
Write-Host "Links quebrados encontrados: $brokenCount"

if ($brokenCount -gt 0) {
    exit 1
} else {
    exit 0
}
