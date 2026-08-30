# F95Checker France

Launcher et patch communautaire francophone pour [F95Checker](https://github.com/WillyJL/F95Checker), l'outil de suivi de mises a jour pour les jeux (NSFW) du forum F95zone.

Ce depot ne fork pas le code de F95Checker : il fournit un **launcher tout-en-un** (`.bat` sous Windows, `.sh` sous Linux) qui installe/maintient a jour une copie de F95Checker depuis les sources officielles, puis lui applique automatiquement un patch "France" a chaque lancement.

## Ce que le patch ajoute

- **Environnement pret a l'emploi** : cree un venv Python dedie, installe les dependances et lance F95Checker en un clic, sans setup manuel.
- **Label "F95France"** : synchronise automatiquement un label sur les jeux ayant une traduction francaise disponible, via une API communautaire (`f95france.site`).
- **Support LC** : permet d'ajouter et de suivre des jeux depuis LC (non supporté nativement par F95Checker), avec suivi de version/statut/tags/image via l'extension navigateur.
- **Personnalisation locale** : icone et libelles adaptes pour la variante France, sans toucher au depot officiel.

## Installation

- **Windows** : lancer `F95Checker-France.bat` (double-clic ou `F95Checker-France.bat reconfigure` pour reconfigurer, `setup-only` pour installer sans lancer l'app).
- **Linux** : lancer `./F95Checker-France.sh` (memes options : `reconfigure`, `setup-only`). Necessite Python 3.11+ ; un venv local est cree automatiquement dans `.venv/`.

Le code source de F95Checker est recupere dans `F95Checker-src/` depuis le depot officiel [WillyJL/F95Checker](https://github.com/WillyJL/F95Checker.git).

## A propos

Ce projet est un outil communautaire non affilie a WillyJL ni a F95zone. Tous les credits pour F95Checker reviennent a son auteur original et ses contributeurs (voir le [README officiel](https://github.com/WillyJL/F95Checker)). Ce depot se limite a la couche d'installation et aux fonctionnalites additionnelles francophones decrites ci-dessus.

## Licence

F95Checker est sous licence GPLv3. Les scripts additionnels de ce depot suivent la meme licence.
