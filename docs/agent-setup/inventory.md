# Agent capability inventory

Generated: 2026-07-12. Paths are user-relative unless absolute. A content hash
identifies bytes; it is not a trust verdict. Plugin cache presence does not by
itself prove that a plugin is enabled. `latest` cache aliases are excluded.

Expected live discovery excludes the six GWS skills below: they are installed
for other agents but explicitly set to `enabled = false` in Codex. The other
ten personal entries are expected in a Codex live probe.

The current HM profile installs Codex, Hermes, and Antigravity. Reviews must
include the applicable native roots below; future profiles should add or remove
targets based on the executables and modules they actually install.

## Mutable personal discovery root

| Name | Path/type | Provenance or version | Runtime | SHA-256 of `SKILL.md` |
| --- | --- | --- | --- | --- |
| 1password-secure | `~/.agents/skills/1password-secure`, external symlink | bookkeeping repository `.hermes/skills/security/1password-secure` | `safe-op`, `op` | `11e28b5aea8d171732b99180ba85293462f0feaa337727b4247bf56bd075c904` |
| agent-browser | mutable directory | `https://github.com/vercel-labs/agent-browser.git`; installed folder hash `121eecacd86c0aab06aef5cd4663e80c5397cd41`, then locally adapted | Nix-managed `agent-browser`, Chrome | `b1b965f37dbe9de1128f0131f029fe52bd80aea0fbaf8207431a1c7751506f87` |
| context-efficient-execution | mutable directory with `agents/` metadata | locally maintained consolidation of the former `context-budgeting` and `targeted-code-navigation` workflows | `rg`, optional `rtk` | `8d1f0ad4354ccf8d3d5e830c0c0c497ef65c9d5adfdcd133c8412b22e68c8859` |
| debugging-and-error-recovery | mutable directory with `agents/` metadata | locally maintained compact rewrite of `https://github.com/addyosmani/agent-skills.git@54c5adfc6b3b494b834d7c61a8feb41c9b5db083`, path `skills/debugging-and-error-recovery` | none | `778ab93539cad0da58bdd6a37561fb6d3da51fdb33740daee92ab7a5160be442` |
| find-skills | mutable directory | `https://github.com/vercel-labs/skills.git`, path `skills/find-skills`, installed folder hash `3013fdeb8a11b10b1eb795ec3ae8bfca38f7c26d` | `npx`/Node.js | `1e85f6f9686e145aca4a124e3b704b9bbea9aa87e08515c1e352eee70f6e6e7a` |
| gws-docs | mutable directory | GWS 0.22.5 | `gws` | `676eb7a1d9e4a7bde0d19669299858daea3220650657199f21dcebb7fa6bf9d6` |
| gws-docs-write | mutable directory | GWS 0.22.5 | `gws` | `219028230078e0d14df314f2ae18b5918721fb5e298bba7d0a010937b2965045` |
| gws-drive | mutable directory | GWS 0.22.5 | `gws` | `d37fad56bb9547d2e169bfd04fbf1f4a377281456765c6243f092f32c973cdac` |
| gws-gmail | mutable directory | GWS 0.22.5 | `gws` | `d17b0064e1c5eb290737edd8c4d42631462b2ff415457af6da03436db3ae0317` |
| gws-gmail-watch | mutable directory | GWS 0.22.5 | `gws` | `c59aa44f22784debf51437d4a1617348e039bfc1ac4bf7b62d602ca13ffac5e1` |
| gws-keep | mutable directory | GWS 0.22.5 | `gws` | `95a99760e826ef94de781de696922c696a8c0bddf054941151d3116fc3448c8b` |
| incremental-editing | mutable directory | locally maintained compact rewrite; prior baseline was the addyosmani revision above, path `skills/incremental-implementation` | none | `daeca7f466d499fff41e34984bf0200cfc1c82a6dc90791dc66f37367e725f13` |
| para-second-brain | mutable directory with references/scripts/tests; migrated from HM | `https://github.com/robdefeo/agent-skills.git@0b9da00edd625e9978e5f25813f95704e57600c7`, path `skills/para-second-brain` | connector-specific | `ccfe5c64be57f0b66cd047fbd27403d70944b6c0df07af352212a3f4413c255c` |
| rtk-cli-output | mutable directory; migrated from HM | local body in baseline Git history, based on `https://github.com/rtk-ai/rtk.git@d3553fb7ee45b901c46f6c063d8ea68ed0e96dfe` | `rtk` | `3916c9aedacf5c9eb90632832e250223a51ce0400d4f46db4aa043796fd35c5f` |
| safe-op | mutable directory with `agents/` | skill text locally maintained; runtime from external `github:crossing/safe-cli` flake input | `safe-op`, `op` | `d458d38e4b2b1b6b4fb2f4cf6cfb9b235fcfc870a741fd24b4891b65b68cecad` |
| state-and-handoff | mutable directory | locally maintained compact state-transfer workflow; prior baseline was the addyosmani revision above, path `skills/planning-and-task-breakdown` | none | `2f4ce86be9674d01203f10cc76a63b5914f6b4de0ed0326e178edb60526a3479` |

The non-skill `index.json` and `index.txt` files in this directory are excluded.
`~/.agents/.skill-lock.json` is the installer provenance record for GWS,
`find-skills`, and `agent-browser`; its per-folder hashes are not Git commits.
The GWS entries come from `https://github.com/googleworkspace/cli.git`, paths
`skills/<name>/SKILL.md`, version 0.22.5.

`agent-browser`, `safe-op`, and the current `1password-secure` target contain
unpublished local adaptations. Their metadata is recorded, but their adapted
bytes are not deterministically recoverable from a fresh machine under the
accepted metadata-only policy. `agent-browser` can only be restored to its
upstream baseline without a separate patch.

The locally maintained workflow bodies for `context-efficient-execution`,
`debugging-and-error-recovery`, `incremental-editing`, `state-and-handoff`,
`parallel-agent-routing`, and `structured-build-cycle` are likewise represented
by metadata and hashes rather than mirrored content. Reconstruct their intent
from this ledger if their exact bytes are unavailable; exact reproduction is
not a bootstrap requirement.

## Codex-owned skills

| Root | Skills |
| --- | --- |
| `~/.codex/skills` | `parallel-agent-routing`, `structured-build-cycle` |
| `~/.codex/skills/.system` | `imagegen`, `openai-docs`, `plugin-creator`, `skill-creator`, `skill-installer` |

These are owned by Codex or their installer, not Home Manager. Their current
baseline contains 7 `SKILL.md` files.

The two personal Codex-owned workflow hashes are:

- `parallel-agent-routing`: `a23f11f4e5aa0a50c70b8785b21063efca648a932dfd77f84373925a7d78c8f0`
- `structured-build-cycle`: `8e9111e49150fd1620d526910bffbb20c219796dd842388794759f2034481c2c`

## Hermes skills

`hermes skills list` currently reports four enabled local skills under
`~/.hermes/skills`: `ee-bill-download-workflow`, `index-agents-skills`,
`install-mcp-on-nixos`, and `use-1password-cli`. Curator state, `.hub`, and
`.curator_backups` are agent state rather than independent skills and must not
be treated as mutable review targets or copied into the ledger.

## Antigravity/Gemini skills

The current native tree contains the bundled `antigravity_guide` under
`~/.gemini/antigravity-cli/builtin/skills` and five Chrome DevTools plugin
skills under `~/.gemini/config/plugins/chrome-devtools-plugin/skills`:
`a11y-debugging`, `chrome-devtools`, `debug-optimize-lcp`,
`memory-leak-debugging`, and `troubleshooting`. These are owned by Antigravity
or its plugin installer; review enabled state and compatibility, but do not
rewrite bundled/plugin content as if it were a personal mutable skill.

## Desired Codex plugins

The explicitly enabled plugin set in `~/.codex/config.toml` is:

- `documents@openai-primary-runtime`
- `pdf@openai-primary-runtime`
- `spreadsheets@openai-primary-runtime`
- `presentations@openai-primary-runtime`
- `template-creator@openai-primary-runtime`
- `chrome@openai-bundled`

This list, not cache presence, is the reconstruction target. Additional curated
connector plugins visible in a workspace are managed by Codex/plugin state and
may be reinstalled separately when their connected capabilities are wanted.

## Concrete plugin cache versions

| Plugin/version | Cached skills |
| --- | --- |
| `openai-bundled/browser/26.623.42026` | `control-in-app-browser` |
| `openai-bundled/browser/26.707.31428` | `control-in-app-browser` |
| `openai-bundled/chrome/26.623.42026` | `control-chrome` |
| `openai-bundled/chrome/26.707.31428` | `control-chrome` |
| `openai-bundled/computer-use/0.1.2-linux-alpha2` | no skill |
| `openai-bundled/deep-research/0.1.1` | `deep-research` |
| `openai-bundled/sites/0.1.27` | `sites-building`, `sites-hosting` |
| `openai-bundled/visualize/1.0.11` | `visualize` |
| `openai-curated-remote/app-68de829bf7648191acd70a907364c67c/4.0.0` | no skill |
| `openai-curated-remote/app-69bc11db874881918718abaca20b68ce/4.0.0` | no skill |
| `openai-curated-remote/codex-security/0.1.11` | `attack-path-analysis`, `deep-security-scan`, `finding-discovery`, `fix-finding`, `propose-security-hardening`, `security-diff-scan`, `security-scan`, `threat-model`, `track-findings`, `triage-finding`, `validation`, `vulnerability-writeup` |
| `openai-curated-remote/github/0.1.8-2841cf9749ae` | `gh-address-comments`, `gh-fix-ci`, `github`, `yeet` |
| `openai-curated-remote/gmail/0.1.5` | `gmail`, `gmail-inbox-triage` |
| `openai-curated-remote/google-drive/0.1.8` | `google-docs`, `google-drive`, `google-drive-comments`, `google-sheets`, `google-slides` |
| `openai-curated-remote/openai-developers/1.2.3` | `agents-sdk`, `build-chatgpt-app`, `chatgpt-app-submission`, `openai-api-troubleshooting`, `openai-platform-api-key` |
| `openai-curated-remote/openai-templates/0.1.0` | `artifact-template-analytics-dashboard`, `artifact-template-business-review`, `artifact-template-design-report`, `artifact-template-experiment-analysis`, `artifact-template-financial-budget`, `artifact-template-investment-committee-memo`, `artifact-template-legal-memorandum`, `artifact-template-market-trends-report`, `artifact-template-minimal-letterhead`, `artifact-template-operating-calendar`, `artifact-template-operating-review`, `artifact-template-project-kickoff`, `artifact-template-project-tracker`, `artifact-template-sales-pipeline`, `artifact-template-simple-dark-mode`, `artifact-template-simple-light-mode`, `artifact-template-strategy-memorandum`, `artifact-template-system-design`, `artifact-template-team-alignment`, `artifact-template-three-statement-forecast` |
| `openai-curated-remote/public-equity-investing/0.1.31` | `catalyst-calendar`, `company-tearsheet`, `comps-valuation`, `dcf-model-builder`, `deck-report-qc`, `earnings-deep-dive`, `earnings-preview`, `economic-impact-report`, `equity-model-update`, `event-driven-analyzer`, `financials-normalizer`, `idea-generation`, `initiating-coverage`, `long-short-pitch`, `meeting-prep`, `memo-builder`, `model-audit-tieout`, `portfolio-risk-management`, `public-equity-investing`, `scenario-sensitivity-generator`, `thesis-tracker`, `three-statement-model-builder`, `user-context` |
| `openai-curated-remote/slack/0.1.4` | `slack`, `slack-channel-summarization`, `slack-daily-digest`, `slack-notification-triage`, `slack-outgoing-message`, `slack-reply-drafting` |
| `openai-primary-runtime/documents/26.709.11516` | `documents` |
| `openai-primary-runtime/pdf/26.709.11516` | `pdf` |
| `openai-primary-runtime/presentations/26.709.11516` | `presentations` |
| `openai-primary-runtime/spreadsheets/26.709.11516` | `excel-live-control`, `spreadsheets` |
| `openai-primary-runtime/template-creator/26.709.11516` | `template-creator` |

Baseline: 23 concrete plugin versions and 91 cached `SKILL.md` files. The
browser and Chrome caches each retain an older and a current concrete version.

## Reproducible checks

```bash
find -L ~/.agents/skills -mindepth 2 -maxdepth 2 -type f -name SKILL.md | wc -l
find ~/.codex/skills -type f -name SKILL.md | wc -l
find ~/.codex/plugins/cache -type f -name SKILL.md | wc -l
find ~/.agents/skills -mindepth 1 -maxdepth 1 -type l \
  -lname '/nix/store/*home-manager-files/.agents/skills/*' -print
```
