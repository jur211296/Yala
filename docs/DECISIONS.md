# Decisions

Source `YalaWiki/planning/DECISIONS.md` @ `1934e8ad` was not readable from this environment.

Measured: `GET /installation/repositories` returns only `jur211296/Yala`. `gh api repos/jur211296/YalaWiki/contents/planning/DECISIONS.md?ref=1934e8ad` → 404. Same 404 for `git ls-remote` and GitHub MCP `get_file_contents`.

This path is the SSOT location. **It is not the decision log.** Do not treat a missing log as “no decisions.” Replace this file with the vault text when YalaWiki is readable. Do not invent entries.
