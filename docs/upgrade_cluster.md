# 1. Préambule

## 1.1 Politique d'écart de version
Lors des mises à jour de cluster Kubernetes, il faut toujours
s'assurer que tous les composants sont comptibles avec la
nouvelle version. \
En cas d'incompatibilité, il faudra effectuer des mises à jour
incrémentielles (ex: 1.32 -> 1.33 -> 1.34). \
\
La politique d'écart de version est définie dans la
[documentation officielle](https://kubernetes.io/releases/version-skew-policy/).

## 1.2 Considérations particulières
Il y a parfois des considérations particulières à prendre en
compte lors de mises à jour vers une version spécifique. \
Il est toujours préférable de consulter la
[documentation officielle](https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/kubeadm-upgrade/).

## 1.3 Ordre de mise à jour
Lors d'une mise à niveau de cluster Kubernetes, nous allons
toujours commencer par mettre à niveau les noeuds control plane.
Une fois que le control plane est mis à jour et testé, nous
pouvons procéder à la mise à niveau des noeuds worker. \
Lors de la mise à niveau du control plane, nous faisons attention
à conserver le quorum (dans un cluster 3 noeuds, toujours 2 noeuds up
and running). La mise à niveau du control plane se fait donc toujours
un noeuds à la fois. \
Lors de la mise à niveau des noeuds workers, nous devons faire attention
à conserver assez de noeuds pour nos charges de travail. Il faut aussi
garder une attention particulières aux services déployés sur ces noeuds.
Par example, une couche de stockage distribué Rook Ceph, il faudra
toujours conserver un quorum. De manière générale, il est recommandé
de mettre à niveau un noeud à la fois.

# 2. Mise à niveau du control plane

## 2.1 Repository APT
Modifier les source APT avec la commande suivante, puis mettre à jour la
liste de paquets (ici de 1.34 à 1.35).
```bash
sudo sed 's/v1.34/v1.35/g' -i /etc/apt/sources.list.d/kubernetes.list
sudo apt update
```

## 2.2 kubeadm
Mettre à jour le paquet kubeadm:
```bash
sudo apt-mark unhold kubeadm
sudo apt install -y kubeadm
sudo apt-mark hold kubeadm
```

## 2.3 Plan de mise à niveau
Planifier la mise à niveau en indiquant la version cible:
```bash
sudo kubeadm upgrade plan v1.35.4
```
Cette commande nous indiquera si notre cluster est prêt à
être mis à niveau vers la nouvelle version.

## 2.4 Mise à niveau
Une fois les vérifications effectuées, procéder à la mise à
niveau du cluster.
```bash
sudo kubeadm upgrade apply v1.35.4
```

## 2.5 Drain
Nous devons maintenant drainer le noeud, ce qui va retirer les
éventuelles charges et ajouter un "cordon" au niveau du cluster.
```bash
kubectl drain k8s-cpl-XX --ignore-daemonsets
```

## 2.6 kubelet
Appliquer les mises à jour en attente du système. \
Ceci mettra à niveau les paquets kubelet et kubectl.
```bash
sudo apt-mark unhold kubelet kubectl
sudo apt upgrade -y
sudo apt-mark hold kubelet kubectl
```

Puis relancer le se service kubelet avec la nouvelle version.
```bash
sudo systemctl daemon-reload
sudo systemctl restart kubelet
sudo systemctl status kubelet
```

## 2.7 Uncordon
Nous pouvons maintenant retirer le "cordon" du noeud. \
Le noeud recevra à nouveau des charges de travail de la
part du cluster.
```bash
kubectl uncordon k8s-cpl-XX
```

## 2.8 Recommencer
La procédure est à refaire en entier sur tous les noeuds
control plane.

# 3. Mise à niveau des noeuds worker

## 3.1 Repository APT
Modifier les source APT avec la commande suivante, puis mettre à jour la
liste de paquets (ici de 1.34 à 1.35).
```bash
sudo sed 's/v1.34/v1.35/g' -i /etc/apt/sources.list.d/kubernetes.list
sudo apt update
```

## 3.2 kubeadm
Mettre à jour le paquet kubeadm:
```bash
sudo apt-mark unhold kubeadm
sudo apt install -y kubeadm
sudo apt-mark hold kubeadm
```

## 3.4 Mise à niveau
Procéder à la mise à niveau du noeud.
```bash
sudo kubeadm upgrade node
```

## 3.5 Drain
Nous devons maintenant drainer le noeud, ce qui va retirer les
éventuelles charges et ajouter un "cordon" au niveau du cluster.
```bash
kubectl drain k8s-wrk-XX --ignore-daemonsets --delete-emptydir-data
```

## 3.6 kubelet
Appliquer les mises à jour en attente du système. \
Ceci mettra à niveau les paquets kubelet et kubectl.
```bash
sudo apt-mark unhold kubelet kubectl
sudo apt upgrade -y
sudo apt-mark hold kubelet kubectl
```

Puis relancer le se service kubelet avec la nouvelle version.
```bash
sudo systemctl daemon-reload
sudo systemctl restart kubelet
sudo systemctl status kubelet
```

## 3.7 Uncordon
Nous pouvons maintenant retirer le "cordon" du noeud. \
Le noeud recevra à nouveau des charges de travail de la
part du cluster.
```bash
kubectl uncordon k8s-wrk-XX
```

## 3.8 Recommencer
La procédure est à refaire en entier sur tous les noeuds
worker.

# 4. Vérification
```bash
kubectl get nodes
```
