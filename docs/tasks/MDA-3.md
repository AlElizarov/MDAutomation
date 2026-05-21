# MDA-3

Configure CI/CD pipeline for the documentation repository.

The pipeline should:

build the MkDocs site on pull requests to main;
validate documentation during PR checks;
deploy the generated static site to GitHub Pages after merge/push to main.

PR workflows should perform validation only and must not publish documentation.
