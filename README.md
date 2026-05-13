# 1. Rack
## 1.1 Matériel
Pour ce projet, il nous faut deux racks de 3 RPi (3 control plane + 3 workers).
Chaque rack est équipé d'un switch 5 port: 1 -> uplink, 2 à 4 -> RPi, 5 -> votre machine de travail). Le switch est alimenté par PoE, et les RPi par un bloc d'alimentation USB (un par rack).

## 1.2 Stockage
Nous n'avons pas besoin de cartes SD, nous allons démarrer sur un SSD SATA 120GB en USB3. **Vérifiez que le disque est bien connecté dans un port USB3 (port bleu).**

## 1.3 Ventilateur
Le ventilateur du rack doit être raccordé sur les ports GPIO de l'un des RPi.
Le câble rouge sur un pin 5 volts et le câble noir sur un pin ground.
Pour savoir quel pin utiliser, voir cette référence: [https://pinout.xyz/](https://pinout.xyz/).

# 2. Système d'exploitation
## 2.1 Préambule
Nous allons déployer la version Lite (donc sans interface graphique) de Raspberry Pi OS 64-bit. Il s'agit de la distribution officielle de Debian sur RPi qui est très similaire à une installation standard de Debian.

## 2.2 Logiciels
Installez le logiciel [Raspberry Pi Imager](https://www.raspberrypi.com/software/) sur votre station de travail, c'est un outil officiel qui permet de flasher les images pour RPi facilement.\
Assurez-vous d'avoir le logiciel GParted à disposition, soit directement sur votre machine, soit sur une clé live-USB de votre distribution Linux préférée.

## 2.3 Flasher l'image
Pour chaque RPi :
- Débranchez le disque USB du RPi et branchez le sur votre station de travail
- Ouvrez Raspberry Pi Imager
- Sélectionner: RPi 5 -> RPi OS (other) -> RPi OS Lite (64-bit)
- Sélectionner le disque USB comme cible
- Entrer le nom d'hôte selon la convention de nommage (`k8s-cpl-XX` ou `k8s-wrk-XX`)
- Définissez le nom d'utilisateur principal `k8s-admin`
- Définissez un mot de passe très très sécurisé dont vous devrez vous souvenir
- Ne pas configurer la connexion Wi-Fi
- Activer SSH et (**très important**) activez l'authetification par clé SSH en ajoutant au minimum votre clé SSH personnelle (Il sera possible d'en ajouter plus tard)
- Ne pas activer RPi Connect
- Assurez-vous d'avoir sélectionné le bon disque et procédez à l'écriture
- Montez la partition `bootfs`
- Remplacez le fichier `config.txt` par celui [disponible ici](https://raw.githubusercontent.com/bouzourene/projet-rpi-cluster/refs/heads/main/bootfs/network-config) (il contient un paramètre permettant de démarrer le RPi en USB sur une alimentation non officielle)
- Remplacez le ficher `network-config` par le template [disponible ici](https://raw.githubusercontent.com/bouzourene/projet-rpi-cluster/refs/heads/main/bootfs/config.txt) (**Ne pas oublier de changer l'adresse IP pour chaque noeud**)
- Ajoutez les paramètres kernel `cgroup_enable=memory cgroup_memory=1` dans le fichier cmdline.txt
- Démontez proprement la partition `bootfs`

## 2.4 Partitionnement (noeuds worker)
Pour les 3 noeuds workers, qui serviront aussi de stockage distribué, il faut ajouter des étapes supplémentaires pour la partition Ceph :
- Ouvrez GParted et sélectionner le disque fraichement imagé `/dev/sdX`
- Créez une partition non formattée (RAW) de 80GB (81920) **à la fin du disque**
- Elargissez la partition `rootfs` avec tout l'espace restant

## 2.5 Tweaks
### 2.5.1 Sudoers en NOPASSWD
Comme les administrateurs se connectent en SSH, on veut faire en sorte qu'il ne soit pas nécessaire d'entrer le mot de passe du compte partagé pour utiliser une commande sudo. Connectez-vous sur chaque noeud et exécutez la commande suivante :
```bash
sudo sed 's/ALL) ALL/ALL) NOPASSWD: ALL/g' -i /etc/sudoers
```

### 2.5.2 Désactiver le swap
Pour Kubernetes, il est important de désactiver le swap sur tous les noeuds. Il ne faut pas oublier de relancer le système.

```bash
sudo apt-get remove rpi-swap -y
sudo apt-get autoremove -y
sudo reboot
```

# 3. Préparation du système
Exécuter le script suivant sur tous les noeuds :

```bash
curl https://raw.githubusercontent.com/bouzourene/projet-rpi-cluster/refs/heads/main/scripts/prepare-system.sh | sudo bash -
```

Si vous souhaitez lire et comprendre les actions du script, vous pouvez le faire sur le [repo git](https://github.com/bouzourene/projet-rpi-cluster/blob/main/scripts/prepare-system.sh).

# 4. Création du cluster k8s
## 4.1 Préambule
## 4.2 Entrée hosts temporaire
Comme la VIP haute disponibilité n'existe pas encore, nous allons créer une entrée statique dans le fichier hosts de notre premier noeud.

```bash
echo "127.0.0.1 k8s-vip-copl.lab4tech.lan k8s-vip-copl" | sudo tee -a /etc/hosts 
```

## 4.3 Kubeadm init
## 4.4 Upload certificats
## 4.5 Configuration kubectl
## 4.6 Couche réseau
## 4.7 VIP Control Plane
## 4.8 Retirer l'entrée hosts temporaire
Maintenant que nous avons bien vérifié que la VIP a bien été créée, nous allons retirer l'entrée statique dans le fichier hosts.

```bash
sudo sed 's/127.0.0.1 k8s-vip-copl/#127.0.0.1 k8s-vip-copl/g' -i /etc/hosts
```

# 5. Ajout des noeuds
## 5.1 Noeuds control plane
## 5.2 Noeuds workers

# 6. Stockage distribué avec Rook Ceph
## 6.1 Préambule
## 6.2 Préparation du cluster k8s
```bash
kubectl create -f https://raw.githubusercontent.com/bouzourene/projet-rpi-cluster/refs/heads/main/rook-ceph/common.yaml
kubectl create -f https://raw.githubusercontent.com/bouzourene/projet-rpi-cluster/refs/heads/main/rook-ceph/crds.yaml
kubectl create -f https://raw.githubusercontent.com/bouzourene/projet-rpi-cluster/refs/heads/main/rook-ceph/csi-operator.yaml
kubectl create -f https://raw.githubusercontent.com/bouzourene/projet-rpi-cluster/refs/heads/main/rook-ceph/operator.yaml
```

## 6.3 Création du cluster Ceph
```bash
kubectl create -f https://raw.githubusercontent.com/bouzourene/projet-rpi-cluster/refs/heads/main/rook-ceph/cluster.yaml
```

## 6.4 Ajout du mode de stockage bloc
```bash
kubectl create -f https://raw.githubusercontent.com/bouzourene/projet-rpi-cluster/refs/heads/main/rook-ceph/rbd-storageclass.yaml
```

## 6.5 Ajout du mode de stockage Cephfs
```bash
kubectl create -f https://raw.githubusercontent.com/bouzourene/projet-rpi-cluster/refs/heads/main/rook-ceph/filesystem.yaml
kubectl create -f https://raw.githubusercontent.com/bouzourene/projet-rpi-cluster/refs/heads/main/rook-ceph/cephfs-storageclass.yaml
```

# X. Autres
## X.1 Autoriser la clé SSH d'un administrateur supplémentaire
Pour que tous les administrateurs puissent se connecter en SSH sur les noeuds Kubernetes, il faut autoriser leur clé SSH sur l'utilisateur `k8s-admin`. Commencez par récupérer la clé publique que vous souhaitez autoriser, elle doit se présenter sur une seule ligne et ressembler à ceci: `ssh-ed25519 AAAAC3NzaC1... votre-email@example.com`. Puis connectez-vous sur chaque noeud et ajoutez la clé comme ceci: `echo 'ssh-ed25519 AAAAC3NzaC1... votre-email@example.com' >> ~/.ssh/authorized_keys`.
