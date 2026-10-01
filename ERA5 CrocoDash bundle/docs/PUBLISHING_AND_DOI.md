# Publishing on GitHub and obtaining a DOI

Author: Faezeh Maghsoodifar

## Publish the repository

Create an empty GitHub repository, then run from this package directory:

```bash
git init
git branch -M main
git add .
git commit -m "Release ERA5 atmospheric forcing extension for CrocoDash"
git remote add origin https://github.com/YOUR_ACCOUNT/YOUR_REPOSITORY.git
git push -u origin main
```

Before committing, inspect `git status` and confirm that no NetCDF data,
credentials, CESM cases, or MOM6 outputs are staged.

## Create the first release

```bash
git tag -a v1.0.0 -m "ERA5 CrocoDash extension v1.0.0"
git push origin v1.0.0
```

Create a GitHub release from the tag and attach the release ZIP if desired.

## Obtain a DOI with Zenodo

1. Sign in to Zenodo using the GitHub account that owns the repository.
2. Enable the repository in Zenodo's GitHub integration.
3. Create or refresh the GitHub release.
4. Zenodo archives the release and assigns a version DOI plus a concept DOI.
5. Add the concept DOI to `CITATION.cff`, `CITATION.bib`, and `README.md`.
6. Commit and release the metadata update.

Use the concept DOI when citing the evolving project and the version DOI when
citing an exact release.

The upstream CrocoDash DOI must remain separately cited because this repository
extends rather than replaces CrocoDash.
