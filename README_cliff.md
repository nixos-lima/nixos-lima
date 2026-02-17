# Git Cliff WIP

I installed `git-cliff` with:

```
nix shell nixpkgs#git-cliff
```

I created `cliff.toml` with `git-cliff --init`

I then fidled around with edits to `cliff.toml` and ran:

```
git cliff --unreleased  --tag v0.0.4 -o CHANGELOG.adoc
```

Which generated a `CHANGELOG.adoc` with one line per commit.

The main things I changed in `cliff.toml` were to produce ASCIIDOC output and
to get one-line-per-commit entries from my not-coventional commit messages.

I then manually edited the CHANGELOG file for the v0.0.4 release.


