# Security policy

## Reporting a problem

Please do not open a public issue for a security problem.

Use **Report a vulnerability** on the repository's Security tab (GitHub private vulnerability reporting). Include
what you found, how to reproduce it, and what an attacker could do with it. You should get a reply within a week.

## What counts

Duet is self-hosted: every pair runs their own Firebase project. Things worth reporting:

- A way for someone outside the two allowed accounts to read or write a pair's data when the rules in
  `database.rules.json` are published as documented
- A way for the app to leak data to a third party
- Problems in the build or CI setup that could let someone ship altered code

## Known and accepted

- "Hidden until you answer" and hidden game information are enforced by the app, not by database rules. The two
  people in a pair can read each other's data from the Firebase console. Duet assumes they trust each other.
- `google-services.json` identifies a Firebase project but is not a secret. The database rules are what protect
  the data. Keep the file out of public forks anyway.
