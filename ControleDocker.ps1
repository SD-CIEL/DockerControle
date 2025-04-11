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
# Ajouter colonne connect
foreach ($item in $tableNotes) {
   $item | Add-Member -MemberType NoteProperty -Name "connect" -Value ""
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
$commands = @()
$expectedValues = @()

# Remplir les tableaux
foreach ($row in $data) {
    $controleNames += $row.ControleName
    $commands += $row.Command
    $expectedValues += $row.Expected
    foreach ($item in $tableNotes) {
        $item | Add-Member -MemberType NoteProperty -Name $row.ControleName -Value ""
    }
}


# -------------------------------------------------------------------------------
#Tests

   for ($i = 0; $i -lt $tableNotes.Count; $i++) 
   {
     if ($tableNotes[$i].ping)
     {

        Write-Host "INFO : "$tableNotes[$i].ip -ForegroundColor Cyan
        $Result;
        try{ 
            $response = Invoke-WebRequest -Uri http://$($tableNotes[$i].ip):2375/info
            $data = $response.Content | ConvertFrom-Json
            $result="✅-"+$($data.Containers)+ "-"+$($data.ContainersRunning )
        #Write-Host "Containers : $($data.Containers)" -ForegroundColor Green
        #Write-Host "ContainersRunning  : $($data.ContainersRunning )" -ForegroundColor Green
        #Write-Host "Images  : $($data.Images )" -ForegroundColor Green
        }
        catch {
            Write-Host "❌ Pas joignable !" -ForegroundColor Red
        }



        Write-Host "Images  : $($result )" -ForegroundColor Green
        $response =""
        $response = Invoke-WebRequest -Uri http://172.17.50.134:2375/containers/json
        $data = $response.Content | ConvertFrom-Json
        Write-Host "Names : $($data.Names)" -ForegroundColor Green
        Write-Host "State  : $($data.State )" -ForegroundColor Green

        docker -H tcp://172.17.50.134:2375 exec -it mqtt_broker sh -c "cat /proc/1/comm" 


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