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
