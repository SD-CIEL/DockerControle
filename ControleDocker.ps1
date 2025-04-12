# Script contrôle sur Docker (Docker Desktop + wsl2)
# Voir config dans README.md
# SD 2025

# -------------------------------------------------------------------------------
# Variables
$fichierListeEtudiants = "IPEtudiants-Test.csv" #<-------------------------------
$fichierListeTests = "controle.csv"             #<-------------------------------

$intervalSeconds = 20  # Intervalle entre chaque itération en secondes
$timeout =40 # Timeout d'ouverture de session ssh en secondes
$tableNotes = @() # Table des tableNotes

# -------------------------------------------------------------------------------
# Lire le fichier CSV des machines et étudiants
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$csvPath = Join-Path $scriptPath $fichierListeEtudiants 
# Vérifier si le fichier existe
if (-Not (Test-Path $csvPath)) {
    Write-Host "❌ Le fichier $csvPath n'existe pas dans le dossier du script !" -ForegroundColor Red
    exit
}
else {
    Write-Host "✅ Fichier $csvPath chargé" -ForegroundColor Green
}
# Lire le fichier CSV
$data = Import-Csv $csvPath


# -------------------------------------------------------------------------------
# Remplir les tableaux
foreach ($row in $data) {
    $tableNotes+= @( New-Object PSObject -Property @{ ip = $row.iP; nom = $row.nomEtudiant } )
}
# Ajouter colonne Note
foreach ($item in $tableNotes) {
   $item | Add-Member -MemberType NoteProperty -Name "NOTE" -Value "0"
}
# Ajouter colonne ping
foreach ($item in $tableNotes) {
   $item | Add-Member -MemberType NoteProperty -Name "ping" -Value ""
}
# Ajouter colonne acces-cont-run
foreach ($item in $tableNotes) {
   $item | Add-Member -MemberType NoteProperty -Name "cont" -Value ""
}
# Ajouter colonne acces-cont-run
foreach ($item in $tableNotes) {
   $item | Add-Member -MemberType NoteProperty -Name "Run" -Value ""
}


# -------------------------------------------------------------------------------
# Test initial de connectivité PING
$jobs = @()
foreach ($item in $tableNotes) {
    $jobs += Start-Job -ScriptBlock {
        param ($ip) Test-Connection -ComputerName $ip -Count 1 -Quiet
    } -ArgumentList $item.iP
}

# Attente des résultats
$jobs | Wait-Job
$results = $jobs | Receive-Job

# Mise à jour du tableau
for ($i = 0; $i -lt $tableNotes.Count; $i++) {
    $tableNotes[$i].ping = $results[$i]
}

# Nettoyage des jobs
$jobs | Remove-Job

Write-Host "✅ Scan de conectivité IP terminé" -ForegroundColor Green


# -------------------------------------------------------------------------------
# Lire le fichier CSV des tests (controles)
# Récupérer le dossier où se trouve le script
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$csvPath = Join-Path $scriptPath $fichierListeTests

# Vérifier si le fichier existe
if (-Not (Test-Path $csvPath)) {
    Write-Host "❌ Le fichier $csvPath n'existe pas dans le dossier du script !" -ForegroundColor Red
    exit
}
else {
    Write-Host "✅ Fichier $csvPath chargé" -ForegroundColor Green
}

# Lire le fichier CSV
$data = Import-Csv $csvPath

# Initialiser les tableaux
$controleNames = @()
$containerNames = @()
$commands = @()
$expectedValues = @()

# Remplir les tableaux
foreach ($row in $data) {
    $controleNames += $row.ControleName
    $commands += $row.Command
    $containerNames += $row.ContainerName
    $expectedValues += $row.Expected
    foreach ($item in $tableNotes) {
        $item | Add-Member -MemberType NoteProperty -Name $row.ControleName -Value ""
    }
}

# -------------------------------------------------------------------------------
# Executer les tests pour un Docker
function Execute-Tests {
    param (
        [object]$ip
    )
        # Vérifier si la session est valide
    if (-not $ip ) {
        Write-Host "   ❌ $ip invalide ou non connectée." -ForegroundColor Red
        return $null
    }

    # Tableau pour stocker les résultats
    $results = @()

    # Exécuter les commandes et stocker les résultats
    for ($i = 0; $i -lt $commands.Length; $i++) {
        $command = $commands[$i]
        $containerName= $containerNames[$i]
        $expectedValue = $expectedValues[$i]
        $result = docker -H tcp://$($ip):2375 exec -it $containerName sh -c $($command)
        $match = [bool]($result -match $expectedValue)
        $results += [PSCustomObject]@{
            Command       = $command
            Output        = $result
            ExpectedValue = $expectedValue
            Match         = $match
        }
        if ($match) {
            Write-Host "  - Executing tests on host: $result" -ForegroundColor Yellow
        }else{
            Write-Host "  - Executing tests on host: $result" -ForegroundColor Red
        }


    }
    return $results
}

        #Write-Host "INFO : $testResults" -ForegroundColor Yellow

# -------------------------------------------------------------------------------
# Boucle de Tests

   for ($i = 0; $i -lt $tableNotes.Count; $i++) 
   {
     if ($tableNotes[$i].ping)
     {
        $note=0;
        Write-Host "Executing tests on host: $($tableNotes[$i].nom) $($tableNotes[$i].ip)" -ForegroundColor Cyan

        $Result;
        try{ 
            $response = Invoke-WebRequest -Uri http://$($tableNotes[$i].ip):2375/info
            if ($response.Headers["Content-Type"] -like "application/json*") {
               # Write-Host "INFO : $response" -ForegroundColor Yellow
               $data= $response.Content | ConvertFrom-Json
               $tableNotes[$i].cont = $data.Containers
               $tableNotes[$i].run= $data.ContainersRunning
                    $result="✅-"+$($data.Containers)+ "-"+$($data.ContainersRunning )
                    Write-Host "Images  : $($result )" -ForegroundColor Green
               $note=1;
             }
            
        }
        catch {
            Write-Host "❌ Pas joignable !" -ForegroundColor Red
        }

        # Réaliser les tests 
        $testResults = Execute-Tests -ip $tableNotes[$i].ip

        
        for ($j = 0; $j -lt $commands.Length; $j++) {
            $command = $commands[$j]
            $controleName = $controleNames[$j]
            $columnName = "$controleName"

            # Récupérer le résultat correspondant
            $matchValue = ($testResults | Where-Object { $_.Command -eq $command } | Select-Object -First 1).Match

            $tableNotes[$i].$columnName=$matchValue
            if ($matchValue) {$note++}
        }  
        $tableNotes[$i].NOTE=$note 



        $response =""
        $response = Invoke-WebRequest -Uri http://$($tableNotes[$i].ip):2375/containers/json
        $data = $response.Content | ConvertFrom-Json
        Write-Host "Names : $($data.Names)" -ForegroundColor Green
        Write-Host "State  : $($data.State )" -ForegroundColor Green

        docker -H tcp://$($tableNotes[$i].ip):2375 exec -it mqtt_broker sh -c "cat /proc/1/comm" 


        # Afficher les résultats
        Show-SplitTable -data $tableNotes -columnsPerTable 12


    }
  }



function Show-SplitTable {
    param (
        [Parameter(Mandatory = $true)] [array]$data,
        [int]$columnsPerTable = 3
    )
   $windowWidth = [System.Console]::WindowWidth
   Write-Host "Largeur de la fenêtre : $windowWidth"
   $colNames = $data[0].PSObject.Properties.Name  # Récupère les noms des colonnes
   $firstCol = $colNames[1]  # Garder la colonne 2
   $otherCols = $colNames[2..($colNames.Count - 1)]  # Toutes les autres colonnes
  
   for ($i = 0; $i -lt $otherCols.Count; $i += $columnsPerTable) {
        $part = $otherCols[$i..([math]::Min($i + $columnsPerTable - 1, $otherCols.Count - 1))]

        # Toujours inclure la colonne 2
        $selectedCols = @($firstCol) + $part  

        $data | Select-Object $selectedCols | Format-Table -Property * -AutoSize #| Format-Table -AutoSize |  Out-String -Width $windowWidth
   }
}