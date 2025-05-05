# Evaluation automatique Docker
Lycée Branly Lyon\
*Version 2025*\
**SD**
## Configuration des postes avec Docker-compose
1. S’assurer que tous les processus Docker sont arrêtés.
``` PowerShell
Stop-Process -Name "Docker Desktop" -Force
Stop-Process -Name "com.docker.backend" -Force
Stop-Process -Name "com.docker.build" -Force
```
2. Supprimer d’éventuelle redirection par portproxy (évite l’occupation du port au démarrage de Docker Desktop « Only one usage of each socket address ») : 
``` PowerShell
netsh interface portproxy delete v4tov4 listenport=2375 listenaddress=0.0.0.0
```
3.	Redémarrer le service d'assistance IP : 
``` PowerShell
Restart-Service iphlpsvc
```
4.	Autoriser l’accès au deamon Docker sur WSL2 :
Modifier/vérifier  C:\Utilisateurs\tpdocker\.docker\deamon.json . Ajouter/vérifier la 1er ligne :
``` json
{
	"hosts": ["tcp://0.0.0.0:2375"],
	"builder": { "gc": { "defaultKeepStorage": "20GB", "enabled": true } },
	"experimental": false,
	"features": { "buildkit": true }
}
```
5.	Exécuter en administrateur Docker Desktop
6.	Exposer la connexion au deamon Docker sur le localhost de l’hôte Windows 
7.	Redémarrer en cliquant sur « Apply & Restart »
8.	Ajouter une règle de redirection (portproxy) par la commande PowerShell :
``` PowerShell
netsh interface portproxy add v4tov4 listenport=2375 listenaddress=0.0.0.0 connectport=2375 connectaddress=127.0.0.1
```
9.	Ajouter une règle de pare-feu par la commande PowerShell (cocher la case dans paramètre):
``` PowerShell
New-NetFirewallRule -DisplayName "Docker Remote API CIEL" -Direction Inbound -Protocol TCP -LocalPort 2375 -RemoteAddress 172.17.50.137 -Action Allow
```
10.	Vérifier l’accès distant, par la commande qui doit retourner les informations sur Docker, si ce n’est pas le cas appeler l’enseignant :
``` PowerShell
docker -H tcp://<IP-de-votre-PC>:2375 info
```
**Si problème vérifier** :
-	Vérifier le portproxy :
``` PowerShell
netsh interface portproxy show all 
```
-   Vérifier l'occupation du port 2375 : 
``` PowerShell
netstat -ano | findstr :2375
```
-  Vérifier quel processus l'utilise:
``` PowerShell
tasklist /svc /FI "PID eq 4284"
```


## Fichiers utilisés :
- IPEtudiant.csv : liste des IP des VM et des noms des l'étudiants
- controle.csv : liste des controles : nom du controle, nom du container, commande bash et résultat attendu
- resultats.csv : liste des résultats obtenus pour chaque VM/étudiant. Fichier horodaté toutes les heures.

## Arborescence du TP à la fin de l'installation
```
ControleDocker
│   docker-compose.yml
│
└───VolumesMosquitto
    ├───config
    │       mosquitto.conf
    │
    ├───data
    └───log
            messages.log
            mosquitto.log
```
