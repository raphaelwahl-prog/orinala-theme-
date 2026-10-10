# DEAD TIRED — versions navigateur

Deux prototypes jouables tout de suite, sans Roblox Studio ni compte. Ils
reprennent **exactement** les chiffres du vrai jeu (`src/shared/GameConfig.luau`,
`src/shared/EntityCatalog.luau`) : gains à la seconde, probabilités de
réveil, tirage toutes les 6 s, nuit de 180 s, vitesses et portées de vue des
quatre créatures, seuils d'éveil de la maison.

| Fichier | Ce que c'est |
| --- | --- |
| `dead-tired-3d.html` | 3D, personnage blocky à la Roblox, caméra 3e personne. C'est la version de référence. |
| `dead-tired-2d.html` | Vue de dessus, plus lisible pour vérifier les trajets des créatures. |

Les deux sont des fichiers uniques : double-clic, ça tourne. Seule dépendance
externe de la 3D : Three.js 0.136.0, chargé depuis jsDelivr.

## Vérifier le jeu avant de le diffuser

Les tests lancent le jeu dans un vrai Chromium (WebGL logiciel) et jouent
dedans : démarrer, marcher, pousser dans les murs, dormir, encaisser au
coffre, acheter, faire apparaître les quatre créatures, vérifier qu'elles se
rapprochent, qu'on ne les voit pas à travers les murs, que le brouillard se
resserre avec l'éveil, que la sauvegarde revient après rechargement, et que
le HUD tient sur un écran de 390 px.

```sh
cd roblox-dead-tired/tools
npm install three@0.136.0 playwright@1.49.1
node test_web3d_prep.js    # fabrique page.html avec Three.js en local
node test_web3d.js         # 66 vérifications + captures d'écran
```

Le script cherche Chromium dans `/opt/pw-browsers/chromium-1194/chrome-linux/chrome` ;
changez `CHROME` en haut de `test_web3d.js` si le vôtre est ailleurs.
