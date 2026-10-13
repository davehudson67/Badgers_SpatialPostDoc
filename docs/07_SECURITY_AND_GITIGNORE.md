# 07 — Security and Git ignore

A `.Renviron` containing database credentials was previously tracked in this repository.

## Immediate action

Rotate the database password in Supabase. Do this even after `.Renviron` is deleted from the latest Git tree, because historical commits can still contain the old password.

## Repository rule

Database credentials belong only in a local `.Renviron` file, which must be ignored by Git.

A safe example file may be committed as `.Renviron.example`, but it must contain placeholders only — never real credentials.

Large generated data and model objects should also remain local rather than being committed to Git.
