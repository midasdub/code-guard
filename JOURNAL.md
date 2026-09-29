# Journal de décisions — code-guard

Une entrée par choix structurant. Gabarit :

```
AAAA-MM-JJ · Sujet
Question : …
Options considérées : A (…), B (…), C (…)
Choix : …
Parce que : …
Rejeté : A car … ; C car …
Reste à vérifier : …
```

---

## 2026-09-28 · Image de base du conteneur

- **Question :** sur quelle image de base construire code-guard ?
- **Options considérées :** A (`node:22-alpine`), B (`node:22-slim`, Debian), C (`node:22`, image complète)
- **Choix :** A
- **Parce que :** image petite (téléchargement rapide dans le pipeline à chaque PR), Node déjà présent pour ESLint.
- **Rejeté :** B car plus lourde sans besoin identifié ; C car beaucoup plus lourde et plus de paquets = plus de surface d'attaque.
- **Reste à vérifier :** Alpine utilise musl au lieu de glibc — un outil d'analyse compilé pour glibc pourrait ne pas fonctionner.

## 2026-09-28 · Détection des secrets

- **Question :** avec quel outil détecter les secrets dans le code d'une PR ?
- **Options considérées :** A (TruffleHog), B (Gitleaks), C (règles écrites à la main, expressions régulières)
- **Choix :** A
- **Parce que :** outil maintenu, plusieurs centaines de détecteurs, mode `filesystem` adapté à un dossier monté.
- **Rejeté :** B car _(à compléter : comparaison faite ?)_ ; C car coûteux à maintenir et beaucoup de faux négatifs.
- **Reste à vérifier :** comparer A et B sur le même catalogue de cas (défi 3).

## 2026-09-28 · Détection de code suspect

- **Question :** comment détecter du code dangereux ou obscurci écrit par l'agent ?
- **Options considérées :** A (ESLint avec règles de sécurité : `no-eval`, `no-new-func`, `no-implied-eval`), B (outil spécialisé d'analyse de sécurité), C (règles maison)
- **Choix :** A pour commencer
- **Parce que :** analyse statique (lit le code, ne l'exécute pas), déjà standard dans l'écosystème Node.
- **Rejeté :** B et C pour l'instant — à réévaluer au défi 3.
- **Reste à vérifier :** ESLint ne détecte pas vraiment l'obscurcissement (chaînes encodées, noms illisibles). Les règles de qualité (`no-unused-vars`) bloquent aussi : risque de faux positifs.

## 2026-09-29 · Répartition des rôles entre agents

- **Question :** quel agent écrit le code ?
- **Options considérées :** A (MiMo Pro 2.6 via opencode, comme prévu dans le document), B (Claude Code / Opus écrit aussi le code)
- **Choix :** B, validé avec Anna
- **Parce que :** _(à compléter)_
- **Rejeté :** A car _(à compléter)_
- **Reste à vérifier :** je dois toujours relire chaque changement et savoir expliquer chaque ligne (règle 1).

## 2026-09-29 · Construction reproductible de l'image

- **Question :** comment garantir que deux constructions du même commit donnent les mêmes outils ?
- **Options considérées :** A (versions flottantes : `node:22-alpine`, script d'installation TruffleHog depuis `main`, `eslint ^10`), B (tout épingler : tag exact de l'image, version + somme SHA-256 de TruffleHog, `package-lock.json` + `npm ci`)
- **Choix :** B
- **Parce que :** critère du défi 1 (construction reproductible) ; un script téléchargé depuis `main` peut changer ou être compromis sans que je le voie.
- **Rejeté :** A car une mise à jour silencieuse d'un outil peut changer le verdict sans modification de code-guard.
- **Reste à vérifier :** qui met à jour les versions épinglées, et à quelle fréquence (sinon on garde des outils vulnérables).

## 2026-09-29 · Code de sortie de TruffleHog

- **Question :** comment faire en sorte qu'un secret trouvé bloque la PR ?
- **Options considérées :** A (sortie par défaut de TruffleHog), B (option `--fail`), C (analyser la sortie JSON)
- **Choix :** B
- **Parce que :** par défaut TruffleHog renvoie 0 même quand il trouve des secrets — le contrôle « passait » toujours. Avec `--fail`, il renvoie 183 en cas de résultat (documentation officielle).
- **Rejeté :** A car c'est le piège ; C car plus complexe, utile plus tard pour le rapport lisible.
- **Reste à vérifier :** démontrer avec un faux secret dans le catalogue de cas (défi 5).

## 2026-09-29 · Vérification des secrets en ligne

- **Question :** faut-il laisser TruffleHog vérifier les secrets trouvés auprès des services (appel réseau) ?
- **Options considérées :** A (vérification active, par défaut), B (`--no-verification`)
- **Choix :** B
- **Parce que :** le conteneur n'envoie aucun secret sur le réseau ; résultat identique en local et dans le pipeline (défi 7) ; un faux secret de test bloque aussi.
- **Rejeté :** A car dépend du réseau, résultats variables, et envoie le secret à un tiers.
- **Reste à vérifier :** plus de faux positifs possibles — mesurer sur le catalogue.

## 2026-09-29 · Contournement d'ESLint par l'agent

- **Question :** l'agent peut-il désactiver les règles ESLint depuis son propre code ?
- **Options considérées :** A (laisser le comportement par défaut), B (`--no-inline-config` + vérifier `.js`, `.cjs`, `.mjs`)
- **Choix :** B
- **Parce que :** testé : un fichier commençant par `/* eslint-disable */` avec `eval()` passait (sortie 0), et un `eval()` dans un fichier `.cjs` n'était pas analysé. Après correction, les deux sont bloqués.
- **Rejeté :** A car l'agent qui écrit le code contrôlerait le contrôle.
- **Reste à vérifier :** ajouter ces deux cas au catalogue d'attaques (défi 2 / défi 5).

## 2026-09-29 · Montage en lecture seule

- **Question :** comment garantir que code-guard ne modifie pas le code analysé, et que se passe-t-il si on oublie `:ro` ?
- **Options considérées :** A (faire confiance à la commande `docker run`), B (le conteneur teste lui-même l'écriture dans `/workspace` et bloque si elle réussit)
- **Choix :** B
- **Parce que :** échec sûr (« fail closed ») : un montage mal configuré bloque au lieu de passer en silence.
- **Rejeté :** A car une erreur de configuration passerait inaperçue.
- **Reste à vérifier :** la lecture seule ne protège pas contre le réseau ni contre la lecture des fichiers — voir ce qu'elle ne protège pas (défi 1).

## 2026-09-29 · Projet sans fichier JavaScript

- **Question :** que faire quand la PR ne contient aucun fichier JavaScript (ex. : seul le README change) ?
- **Options considérées :** A (bloquer : ESLint échoue avec « all files ignored »), B (`--no-error-on-unmatched-pattern` : rien à analyser = pas d'erreur ESLint), C (tester soi-même la présence de fichiers avant ESLint)
- **Choix :** B
- **Parce que :** découvert en lançant l'image sur `t-project` (aucun `.js`) : la PR était bloquée sans raison. Toute autre erreur d'ESLint (code 2, plantage) bloque toujours.
- **Rejeté :** A car faux positif sur toute PR sans code ; C car plus de code à maintenir pour le même résultat.
- **Reste à vérifier :** ESLint ignore par défaut `node_modules/` — un agent pourrait y cacher du code (cas d'attaque à tester, défi 2).

## 2026-09-29 · Versionnement de l'image

- **Question :** comment le dépôt cible sait-il quelle version de code-guard a rendu le verdict ?
- **Options considérées :** A (tag `latest` seulement), B (tags `X.Y.Z` sur tag git, `main` et `sha-<commit>` + version écrite dans l'image et affichée dans le rapport)
- **Choix :** B
- **Parce que :** critère du défi 1 ; la première ligne du rapport et les labels OCI (`docker inspect`) donnent la version et le commit.
- **Rejeté :** A car `latest` change sans prévenir : deux PR identiques pourraient avoir deux verdicts différents.
- **Reste à vérifier :** le dépôt cible doit utiliser une version fixe (`X.Y.Z` ou digest), pas `main` — à décider au défi 2.

## 2026-09-29 · Registre et publication

- **Question :** où publier l'image, et comment éviter de publier une image cassée ?
- **Options considérées :** A (Docker Hub, compte + secret à gérer), B (GitHub Container Registry, jeton `GITHUB_TOKEN` intégré)
- **Choix :** B, publication seulement si `tests/smoke.sh` passe
- **Parce que :** même plateforme que les dépôts, pas de secret supplémentaire ; un test échoué arrête le job avant la publication.
- **Rejeté :** A car un secret de plus à protéger, pour aucun avantage ici.
- **Reste à vérifier :** l'image doit être publique (ou accessible à `t-project`) pour que le pipeline cible puisse la télécharger.

## 2026-09-29 · Faux secrets dans les tests

- **Question :** comment tester la détection de secrets sans mettre de secret dans le dépôt ?
- **Options considérées :** A (fichier de test avec un faux jeton committé), B (jeton aléatoire généré au moment du test)
- **Choix :** B
- **Parce que :** un faux jeton committé serait lui-même détecté comme fuite (scanner de GitHub, et code-guard sur son propre dépôt).
- **Rejeté :** A pour cette raison.
- **Reste à vérifier :** —

## 2026-09-29 · Actions tierces dans les workflows

- **Question :** comment référencer une action GitHub (ex. `actions/checkout`) ?
- **Options considérées :** A (tag : `@v7`), B (SHA de commit : `@3d3c42e…  # v7.0.1`), C (éviter les actions, écrire des commandes `docker`)
- **Choix :** B pour `checkout`, C pour tout le reste (build, login, push avec la CLI `docker`)
- **Parce que :** un tag peut être déplacé vers un autre code, un SHA non ; moins d'actions tierces = moins de code que je dois comprendre et auquel je dois faire confiance (règle 1).
- **Rejeté :** A car une action compromise changerait le pipeline sans que je le voie.
- **Reste à vérifier :** —

## 2026-09-29 · Quand et depuis quelle version la configuration du pipeline est lue

- **Question :** l'agent peut-il désactiver le contrôle en modifiant le fichier de workflow dans sa branche A ?
- **Options considérées :** A (`pull_request` : GitHub lit le workflow **dans la branche de la PR**), B (`pull_request_target` : GitHub lit le workflow **dans `main`**), C (règle d'organisation « workflow obligatoire » stocké dans `code-guard`), D (service externe / GitHub App)
- **Choix :** B + CODEOWNERS sur `.github/`
- **Parce que :** avec A, l'agent modifie ou supprime le fichier et le contrôle devient ce qu'il veut. Avec B, une modification du workflow dans la PR n'a aucun effet sur le contrôle de cette PR. CODEOWNERS ajoute une revue humaine obligatoire pour toute modification de `.github/`.
- **Rejeté :** A car l'agent contrôlerait son propre contrôle ; C car les règles d'organisation demandent un plan payant (Team/Enterprise) ; D car il faut héberger un serveur — trop long pour le projet.
- **Reste à vérifier :** le piège de `pull_request_target` : le job a les droits du dépôt de base. Règle absolue : le code de la PR est une **donnée** (monté en lecture seule, analysé statiquement), jamais installé ni exécuté. Protections en plus : jeton en lecture seule, `persist-credentials: false`, `--network none`.

## 2026-09-29 · Compte utilisé par l'agent

- **Question :** sous quel compte GitHub l'agent pousse-t-il son code ?
- **Options considérées :** A (compte séparé pour l'agent, rôle Write sur le dépôt cible), B (mon propre compte, administrateur)
- **Choix :** A (premier choix : B, changé après analyse)
- **Parce que :** GitHub interdit à l'auteur d'une PR de l'approuver. Avec B, soit la revue obligatoire bloque toutes les PR (personne ne peut approuver), soit il n'y a pas de revue et CODEOWNERS ne protège rien ; en plus l'agent aurait les droits d'administrateur et pourrait modifier les protections elles-mêmes. Le document parle d'un agent qui a le droit d'**écrire sur la branche A**, pas d'un administrateur.
- **Rejeté :** B pour ces raisons.
- **Reste à vérifier :** l'agent (rôle Write) ne peut ni modifier les protections de `main`, ni fusionner sans mon approbation, ni pousser sur `main` — à démontrer par des PR réelles.

## 2026-09-29 · Stratégie de fusion

- **Question :** comment une branche arrive-t-elle dans `main` (préférence d'Anna : historique propre et linéaire) ?
- **Options considérées :** A (squash : toute la PR devient un seul commit), B (rebase : les commits de la PR sont recopiés un par un), C (commit de fusion)
- **Choix :** A, seule méthode autorisée dans les deux dépôts (réglage du dépôt), branches supprimées après fusion
- **Parce que :** historique linéaire ; un commit = une PR, avec le numéro de la PR dans le titre : on retrouve facilement les PR d'attaque et les cas de test ; les commits intermédiaires d'un agent (essais, corrections) ne polluent pas `main`.
- **Rejeté :** B car les commits intermédiaires de l'agent arrivent dans `main` et GitHub recrée les commits (nouveaux SHA) ; C car historique non linéaire.
- **Reste à vérifier :** le détail des commits reste visible dans la PR, pas dans `main`.
