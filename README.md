# Cartes de visites → Pistes (Salesforce + GenAI multimodal)

Démonstrateur Salesforce qui transforme une **photo de carte de visite** en **Lead** Salesforce qualifié, en quelques secondes, grâce à un prompt template Einstein multimodal (GPT-4o).

L'utilisateur dépose une ou plusieurs photos de cartes dans un Lightning Web Component. Chaque image est uploadée comme `ContentVersion`, analysée en parallèle par le modèle, restituée sous forme d'un mini-formulaire éditable, puis créée comme Lead via l'UI Record API. La photo source reste rattachée au Lead via un `ContentDocumentLink`.

> ⚠️ **Cadre du projet**
>
> Ce repo est un **démonstrateur / proof-of-concept**, pas un produit prêt pour la production. L'objectif est de :
>
> - **tester la multimodalité** des prompt templates Einstein (analyse d'image via `ConnectApi.EinsteinLLM`) ;
> - **servir de base de mise à l'échelle** pour des cas d'usage similaires (OCR de documents, factures, fiches contact, formulaires papier scannés…) ;
> - **valider l'UX** d'un workflow batch « scanner → vérifier → créer » pensé pour le terrain (commercial sortant de visite).
>
> Avant tout déploiement productif : revoir la sécurité (FLS, partage), bulkifier les opérations, gérer les quotas Einstein, ajouter des tests Apex de couverture, durcir la gestion d'erreurs, et adapter le prompt à la qualité d'image cible.

---

## Architecture rapide

```
[Photo de carte]
   │
   ▼
LWC cvCapture (drag&drop)
   │  base64
   ▼
Apex CV_CardProcessor.uploadCard      → ContentVersion / ContentDocument
   │
   ▼
Apex CV_CardProcessor.processCard     → ConnectApi.EinsteinLLM
   │                                     prompt template "ImageF" (GPT-4o)
   │  JSON {firstName, lastName, company, email, mobile, phone}
   ▼
CV_PromptJsonParser                   → normalisation (strip ```json, N/A→null)
   │
   ▼
LWC cvLeadCard                        → formulaire éditable par carte
   │
   ▼ (clic « Créer la piste »)
lightning/uiRecordApi createRecord    → Lead
   │
   ▼
Apex CV_CardProcessor.linkCardToLead  → ContentDocumentLink (photo ↔ Lead)
```

**Composants livrés :**

| Type | Nom | Rôle |
|---|---|---|
| LWC | `cvCapture` | Conteneur, état des cartes, batch création |
| LWC | `cvDropZone` | Zone drag & drop initiale |
| LWC | `cvLeadCard` | Mini-formulaire par carte, statuts visuels |
| Apex | `CV_CardProcessor` | Upload, invocation prompt, lien fichier↔lead |
| Apex | `CV_PromptJsonParser` | Parsing du JSON renvoyé par le modèle |
| Apex | `CV_CardProcessorTest` | Tests unitaires |
| Flow | `Charger_une_CV` | Variante 100% Flow (alternative au LWC) |
| Prompt | `ImageF` (GenAiPromptTemplate) | Template multimodal d'analyse de carte |
| Labels | `CustomLabels` + `fr.translation` | Internationalisation EN/FR |

---

## Prérequis

### Org cible

- Salesforce **Enterprise Edition ou supérieure**, API **64.0+**.
- **Einstein Generative AI** activé dans l'org (licence Einstein 1 / Einstein for Sales / équivalent).
- **Prompt Builder** activé.
- Modèle **GPT-4o (`sfdc_ai__DefaultGPT4Omni`)** disponible dans la région de l'org (Einstein Trust Layer).
- Lead, ContentDocument, ContentDocumentLink accessibles à l'utilisateur.

### Outillage local (déploiement)

- `sf` CLI (Salesforce CLI v2) installée et authentifiée sur l'org cible.
- Un alias d'org configuré (`sf org login web --alias <monAlias>`).

> Aucune dépendance npm/Jest/Prettier/ESLint requise pour déployer : ce repo est volontairement minimal.

---

## Déploiement

```bash
# 1. Cloner
git clone https://github.com/yannibus/cartesvisites.git
cd cartesvisites

# 2. Vérifier l'org cible
sf org display --target-org <monAlias>

# 3. Validation à blanc (recommandé)
sf project deploy start --target-org <monAlias> --manifest manifest/package.xml --dry-run

# 4. Déploiement
sf project deploy start --target-org <monAlias> --manifest manifest/package.xml
```

Le `manifest/package.xml` couvre : Apex, LWC, Flow, GenAiPromptTemplate, CustomLabels, Translations.

---

## Étapes post-déploiement

### 1. Activer le prompt template

Setup → **Prompt Builder** → ouvrir `ImageF` → vérifier qu'il est **Activé** et que la version active utilise `sfdc_ai__DefaultGPT4Omni`. Si le template n'est pas activé automatiquement, l'activer manuellement.

### 2. Vérifier les permissions utilisateur

Le profil ou Permission Set doit avoir :

- **Apex Class Access** : `CV_CardProcessor`, `CV_PromptJsonParser`.
- **Object permissions** : Lead (Create, Edit), ContentDocument (Read), ContentVersion (Create), ContentDocumentLink (Create).
- **Einstein GPT** : permission « Use Einstein Generative AI » (ou licence équivalente).

### 3. Exposer le LWC sur une page

Le composant `cvCapture` est exposé pour Home, App et Record Page (`isExposed=true`). L'ajouter via **Lightning App Builder** sur la page de votre choix (par exemple une page dédiée « Scanner cartes de visite »).

### 4. Tester

1. Ouvrir la page contenant le LWC.
2. Glisser une photo de carte de visite (JPG/PNG).
3. Attendre l'analyse (quelques secondes).
4. Vérifier les champs pré-remplis, corriger si besoin.
5. Cliquer **« Créer la piste »** → un toast de succès apparaît, le Lead est créé avec la photo en pièce jointe.

### 5. (Optionnel) Tester la variante Flow

Le flow `Charger_une_CV` (« Carte de visite vers Piste ») fait le même travail sans LWC, à activer via Setup → Flows si vous voulez comparer les deux approches.

---

## Points d'attention pour la mise à l'échelle

- **Sécurité** : `with sharing` activé sur les classes, mais aucune vérification FLS explicite. À durcir avec `Security.stripInaccessible` avant productisation.
- **Bulkification** : `linkCardToLead` traite un seul lien à la fois (suffisant pour 1-5 cartes en démo). Pour du volume, refactorer en bulk.
- **Quotas Einstein** : chaque carte = 1 appel modèle. Surveiller la consommation Flex Credits / Einstein Requests.
- **Qualité OCR** : le prompt actuel est tuné pour des cartes B2B francophones. À adapter selon la cible (langue, format, mise en page).
- **Erreurs modèle** : si le JSON renvoyé est mal formé, la carte passe en statut `error` avec retry possible. Pas de fallback OCR alternatif.
- **Tests** : les tests Apex couvrent le parser et le lien fichier↔lead, mais pas le call ConnectApi (à mocker pour atteindre 75 % de couverture en prod).

---

## Pistes d'extension

- Lier automatiquement le Lead à un Account existant (déduplication par domaine email).
- Détecter la langue de la carte et router vers un prompt template localisé.
- Étendre à d'autres documents : factures, bons de commande, fiches produit, badges salons.
- Ajouter un mode « capture mobile » avec accès direct à l'appareil photo.
- Stocker la `rawResponse` du modèle sur le Lead pour audit / amélioration continue du prompt.

---

## Licence

Démonstrateur interne. Réutilisable librement comme base de POC. Aucune garantie de support.
