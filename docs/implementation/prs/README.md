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
| [Work package 09](pr-09.md) | Merged in GitHub PR #10; internal only, live/privacy gates blocked. |
| [Work package 10](pr-10.md) | Merged SQLite persistence in GitHub PR #11; live recovery remains gated. |
| [Work package 11](pr-11.md) | Merged pure planner in GitHub PR #12; no live activation. |
| [Work package 12](pr-12.md) | Durable executor merged in GitHub PR #13; default-deny live activation. |
| [Work package 13](pr-13.md) | Recurrence/time correctness merged in GitHub PR #14; live gates open. |
| [Work package 14](pr-14.md) | Deletion safety/recovery merged in GitHub PR #15; live gates open. |
| [Work package 15](pr-15.md) | Merged in GitHub PR #16; synthetic acceptance, live gates open. |
| [Work package 16](pr-16.md) | Merged in GitHub PR #17; account/signed/live follow-up remains open. |
| [Work package 17](pr-17.md) | Merged in GitHub PR #18; signed broker acceptance remains open. |
| [Work package 18](pr-18.md) | Merged in GitHub PR #19; synthetic MCP reads; live identity/signed gates remain open. |
| [Work package 19](pr-19.md) | Synthetic connection identity/revocation implemented for review; signed/native gates remain open. |
| [Work package 20](pr-20.md) | Planned proposal/approval engine; requires package 19 merge and authorization. |

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
