---
name: deep-research
description: Comprehensive deep research methodology using MCP tools. Load when conducting complex research requiring multiple sources, technical deep-dives, comparative analysis across options, or questions where surface-level search isn't sufficient. Generates 10 search queries, fetches ALL results, and produces detailed synthesis with citations. NOT for simple factual lookups — use web-search skill instead.
---

# Deep Research Skill

Comprehensive, multi-source research methodology for ghost-researcher. Use this skill for complex questions that require thorough investigation, cross-referencing, and detailed synthesis.

## When to Use This Skill

- Complex research questions requiring multiple sources
- Technical deep-dives needing comprehensive coverage
- Comparative analysis across multiple options/approaches
- Questions where surface-level search isn't sufficient
- Research requiring cross-referencing multiple sources
- Evaluating trade-offs between architectural approaches
- Investigating best practices with evidence from multiple teams/companies

**NOT for**: Simple factual lookups, finding a specific URL, or questions answerable with 1-3 queries. Use the **web-search** skill instead.

## Available MCP Tools

| Tool | Reference | Purpose |
|------|-----------|---------|
| Multi Search | `@web-research/multi_search` | Search DuckDuckGo with multiple queries in parallel, returns deduplicated URLs and snippets |
| Fetch Pages | `@web-research/fetch_pages` | Fetch and extract content from multiple URLs in parallel |

## Research Workflow

### Step 1: Generate Search Queries

Generate **EXACTLY 10 search queries** for the research question.

**Query Generation Rules:**
- Output EXACTLY 10 queries — no more, no less
- Each query should target a different aspect of the question
- Use search operators (quotes, `site:`, `filetype:`) where helpful
- Range from broad to specific
- Consider recent/current information
- Include the current year where relevant

**Search Operator Guide:**
- `"exact phrase"` — Find exact matches
- `site:domain.com` — Search specific site
- `-term` — Exclude term
- `filetype:pdf` — Find specific file types
- `intitle:term` — Term must be in title

**Example Query Generation:**

Research question: "What are the best practices for container orchestration in production?"

```json
[
  "container orchestration best practices production 2025",
  "Kubernetes production deployment best practices",
  "container orchestration platform comparison 2025",
  "production container management scaling strategies",
  "Kubernetes vs alternatives container orchestration",
  "site:kubernetes.io production best practices",
  "container orchestration security hardening production",
  "microservices container orchestration patterns",
  "container orchestration monitoring observability best practices",
  "enterprise container platform lessons learned"
]
```

**Query Diversity Checklist:**
- [ ] At least 2 broad/overview queries
- [ ] At least 2 specific/technical queries
- [ ] At least 1 query targeting official documentation (`site:`)
- [ ] At least 1 query about trade-offs or comparisons
- [ ] At least 1 query about real-world experience/lessons learned
- [ ] Current year included where relevant

### Step 2: Execute Search

Call `@web-research/multi_search` with ALL 10 queries:

```json
{
  "queries": ["query 1", "query 2", "...", "query 10"],
  "results_per_query": 5
}
```

**Parameters:**
- `queries` (required): Array of exactly 10 search query strings
- `results_per_query` (optional): Number of results per query (default: 5)

This will return approximately 30-50 unique URLs after deduplication.

### Step 3: Fetch ALL Content

Call `@web-research/fetch_pages` with **ALL URLs returned** from the search:

```json
{
  "urls": ["...all URLs from search results..."],
  "max_chars": 15000,
  "timeout": 30
}
```

**Parameters:**
- `urls` (required): Array of ALL URLs from search results — do NOT filter
- `max_chars` (optional): Maximum characters per page (default: 15000 for deep research)
- `timeout` (optional): Timeout in seconds per fetch (default: 30 for deep research)

**CRITICAL**: Fetch ALL URLs — do not filter or select a subset. More sources = better synthesis. The tool handles parallel fetching efficiently.

### Step 4: Comprehensive Synthesis

This is the **MOST IMPORTANT** step. Take time to produce a thorough, well-reasoned synthesis.

**Before writing your response, mentally process:**
- What are the key themes across ALL sources?
- Where do sources agree? Where do they conflict?
- What's the overall narrative that emerges?
- What gaps remain in the research?

**Synthesis Requirements:**

1. **READ ALL FETCHED CONTENT CAREFULLY** — Don't skim. Extract key facts, opinions, and data points from each source.

2. **CROSS-REFERENCE SOURCES** — When multiple sources mention the same fact, note this. When sources conflict, explain both viewpoints.

3. **BE COMPREHENSIVE** — Your synthesis should be LONGER and MORE DETAILED than any single source. You're combining 30-50 sources into one authoritative answer.

4. **CITE SPECIFIC SOURCES** — Don't make claims without attribution. Use inline citations like "According to [Source Title](URL)..."

5. **QUANTIFY WHEN POSSIBLE** — Include numbers, percentages, benchmarks, dates when available in sources.

6. **ADDRESS THE ORIGINAL QUESTION DIRECTLY** — After all analysis, clearly answer what was asked.

## Output Format

Structure your research findings comprehensively. This integrates with ghost-researcher's Research Report format but is expanded for deep research:

```markdown
## Research Report: {Topic}

### Question
{What was researched — restate the original question}

### Executive Summary
{3-5 sentences providing a complete overview of findings. This should stand alone as a useful answer even if the reader goes no further. Include the most important conclusion and any critical caveats.}

### Key Findings

#### 1. {Finding Title}
{Detailed explanation — 2-4 paragraphs minimum. Include specific data points, quotes, and evidence.}

**Evidence:**
- According to [Source 1](URL): "{relevant quote or data point}"
- [Source 2](URL) confirms this, noting that...
- However, [Source 3](URL) presents a different view: ...

#### 2. {Finding Title}
{Same detailed structure}

#### 3. {Finding Title}
{Continue for 5-7 findings minimum}

### Detailed Analysis

#### {Subtopic A}
{Deep dive into a specific aspect. 3-5 paragraphs with citations.}

#### {Subtopic B}
{Another detailed section}

### Comparison/Trade-offs
{If applicable — detailed comparative analysis}

| Aspect | Option A | Option B | Notes |
|--------|----------|----------|-------|
| {Criterion 1} | {Detail} | {Detail} | {Source} |
| {Criterion 2} | {Detail} | {Detail} | {Source} |

### Recommendation
{Which approach and why, with supporting evidence. Present as options for the delegating agent to decide — ghost-researcher does NOT make final decisions.}

### Confidence Level
{HIGH / MEDIUM / LOW} — {reason for confidence level}

**Per-finding confidence:**

| Finding | Confidence | Reasoning |
|---------|------------|-----------|
| {Finding 1} | High | Confirmed by 5+ sources including official documentation |
| {Finding 2} | Medium | Single authoritative source, no contradictions |
| {Finding 3} | Low | Limited sources, some conflicting information |

### Conflicting Information
{Explicitly address where sources disagreed}

- **Topic X**: Source A claims {X}, while Source B claims {Y}. The discrepancy may be due to {analysis}.

### Research Gaps & Limitations
- {Topics that couldn't be fully researched}
- {Questions that remain unanswered}
- {Areas where more recent data is needed}
- {Potential biases in available sources}

### References
{List ALL sources that contributed to the synthesis — aim for 10+ sources}

1. **[Title](URL)** — {What this source contributed to the research}
2. **[Title](URL)** — {What this source contributed}
3. ...

### Suggested Follow-up
- {Specific follow-up research that would strengthen findings}
- {Related topics worth exploring}
```

## Quality Checklist

Before finalizing your response, verify:

- [ ] Did I use information from at least 10+ different sources?
- [ ] Did I cite sources for all major claims?
- [ ] Is my synthesis longer than 500 words?
- [ ] Did I address conflicting information between sources?
- [ ] Did I directly answer the original research question?
- [ ] Did I note confidence levels for key findings?
- [ ] Did I include quantitative data where available?
- [ ] Did I identify gaps and limitations in the research?
- [ ] Did I present recommendations as options (not decisions)?

**If any checkbox is unchecked, go back and improve that aspect before submitting.**

### Signs of a Good Synthesis
- Reader learns more from your synthesis than from any single source
- Claims are attributed to specific sources with links
- Conflicting viewpoints are acknowledged and analyzed
- Numbers and data points are included where available
- Confidence levels help reader know what to trust
- Gaps are honestly acknowledged

### Signs of a Poor Synthesis
- Generic summary that could have been written without research
- Claims without source attribution
- Ignoring sources that conflict with the main narrative
- Missing quantitative data that was available in sources
- No acknowledgment of uncertainty or gaps
- Shorter than the original sources

## Research Patterns by Domain

### Architecture/Design Decisions
```json
[
  "{topic} architecture best practices {year}",
  "{option A} vs {option B} comparison",
  "{topic} production experience lessons learned",
  "site:{official-docs} {topic} guide",
  "{topic} scalability performance benchmarks",
  "{topic} security considerations",
  "{topic} migration strategy",
  "{topic} real-world case study",
  "{topic} common pitfalls anti-patterns",
  "{topic} future roadmap direction {year}"
]
```

### Library/Framework Evaluation
```json
[
  "{library} review {year}",
  "{library} vs alternatives comparison {year}",
  "{library} production experience",
  "site:github.com {library} issues stars",
  "{library} performance benchmarks",
  "{library} documentation quality",
  "{library} community support ecosystem",
  "{library} breaking changes migration",
  "{library} use cases when to use",
  "{library} limitations known issues"
]
```

### Best Practices Research
```json
[
  "{topic} best practices {year}",
  "{topic} industry standards",
  "{topic} common mistakes to avoid",
  "site:{authority-site} {topic} guide",
  "{topic} expert recommendations",
  "{topic} case study implementation",
  "{topic} metrics measurement",
  "{topic} tools and automation",
  "{topic} team workflow process",
  "{topic} emerging trends {year}"
]
```

## Error Handling

If `@web-research/multi_search` or `@web-research/fetch_pages` fails:

1. **Partial failure** (some URLs fail to fetch): Continue with successfully fetched content. Note in Research Gaps that some sources were unavailable.

2. **Complete MCP failure**: Fall back to `curl` via `shell` tool:
   ```bash
   # Search via DuckDuckGo HTML (degraded mode)
   curl -sL "https://html.duckduckgo.com/html/?q=your+search+query" | sed 's/<[^>]*>//g' | head -200
   
   # Fetch specific pages
   curl -sL --max-time 15 "https://example.com/docs" | head -300
   ```
   Note in your response that MCP tools were unavailable and results may be less comprehensive.

3. **All web access fails**: Report that web research was unavailable. Provide what you can from local sources (`read` tool for local documentation, codebase analysis).

## Guidelines

### DO:
- Generate diverse queries covering multiple angles
- Prioritize authoritative sources (official docs, reputable publications)
- Cross-reference findings across multiple sources
- Note conflicts or disagreements between sources
- Cite sources for all key claims
- Flag uncertainty and gaps in research
- Include quantitative data where available
- Present recommendations as options with trade-offs

### DON'T:
- Rely on a single source for important claims
- Include outdated information without noting the date
- Present speculation as fact
- Skip the synthesis step — raw content isn't useful
- Ignore conflicting information
- Filter URLs before fetching — fetch ALL of them
- Make final decisions — present options for the delegating agent
- Generate fewer than 10 queries
