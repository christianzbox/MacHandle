# Focused PR briefs

| Brief | Purpose / eligibility |
| --- | --- |
| [Work package 01](pr-01.md) | Merged foundation; historical acceptance map and evidence. |
| [Work package 02](pr-02.md) | Merged feasibility decisions in GitHub #3; later runtime gates remain open. |
| [Work package 03](pr-03.md) | Core domain merged in GitHub PR #4; historical acceptance/evidence. |
| [Work package 04](pr-04.md) | Permission policy engine merged in GitHub PR #5. |
| [Work package 05](pr-05.md) | Native application foundation merged in GitHub PR #6. |
| [Work package 06](pr-06.md) | Calendar authorization/discovery merged in GitHub PR #7; live TCC gate remains open. |
| [Work package 07](pr-07.md) | Bounded Calendar reads/availability merged in GitHub PR #8; live gate remains open. |
| [Work package 08](pr-08.md) | Merged in GitHub PR #9; live activation blocked pending setup. |
| [Work package 09](pr-09.md) | Active Google destination client; internal only, live/privacy gates blocked. |

| [Work package 10](pr-10.md) | Planned SQLite persistence; requires package 09 merge and new authorization. |

Legacy `pr-NN.md` filenames refer to work packages, not GitHub PR numbers.
See the [mapping](../pr-roadmap.md#work-packages-and-github-prs) for actual review links.

All future work is retained in the [31-PR register](../pr-roadmap.md), governed by
[the master plan](../../../plans/MacHandleMasterImplementationPlan.md). Create the
next useful brief as its prerequisite provides concrete contracts; do not pre-fill
future decisions or load every brief in one session.

Each brief states objective, merged prerequisites, scoped reading links, inclusions,
exclusions, contracts/security, implementation notes, tests, observable acceptance,
documentation updates and handoff. Scope/acceptance is not a completion checkmark:
[progress](../progress.md) holds evidence and [coordination](../pr-coordination.md)
holds active PR state. Do not maintain competing copies of the master requirements.
