---
name: research
description: Investigate a question against high-trust primary sources and capture the findings as a Markdown file in the repo. Use when the user wants a topic researched, docs or API facts gathered, or reading legwork delegated to a background agent.
---

Adapted from mattpocock/skills (MIT), https://github.com/mattpocock/skills

Spin up a **background agent** to do the research, so you keep working while it reads.

Its job:

1. Investigate the question against **primary sources** (official docs, source code, specs, first-party APIs), not a secondary write-up of them. Follow every claim back to the source that owns it.
2. Write the findings to a single Markdown file, citing each claim's source.
3. Save it where the repo already keeps such notes; match the existing convention, and if there is none, put it somewhere sensible and say where.

Rules for the agent:

- If you are already the research agent, do not invoke this skill again. You may hand narrow, independent, read-only sub-questions to helpers one level deep; only you write the file.
- When you report that something was not found, say where you searched, and name anything you were told not to read.
- After writing, have the claims that a decision rests on (the summary and its key numbers) checked against their cited sources in a separate context, preferably by a different model.
