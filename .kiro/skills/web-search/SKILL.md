---
name: web-search
description: Quick web search methodology using MCP tools. Load when performing simple factual lookups, finding specific URLs or documentation, getting current information, or answering questions that need 1-3 search queries. NOT for complex multi-source research — use deep-research skill instead.
---

# Web Search Skill

Quick, targeted web search methodology for ghost-researcher. Use this skill for simple questions that can be answered with 1-3 search queries.

## When to Use This Skill

- Quick factual lookups and fact-checking
- Finding specific URLs, documentation, or resources
- Getting current information (news, releases, announcements)
- Simple questions that need 1-3 search queries
- Finding official sources for a topic
- Checking package versions, API endpoints, or configuration syntax

**NOT for**: Complex research requiring multiple sources, comparative analysis, or deep technical dives. Use the **deep-research** skill instead.

## Available MCP Tools

| Tool | Reference | Purpose |
|------|-----------|---------|
| Multi Search | `@web-research/multi_search` | Search DuckDuckGo with one or more queries in parallel, returns deduplicated URLs and snippets |
| Fetch Pages | `@web-research/fetch_pages` | Fetch and extract content from multiple URLs in parallel |

## Workflow

### Step 1: Generate Search Queries

Analyze the research question and generate **1-3 targeted search queries**.

**Query Guidelines:**
- Be specific and direct — target exactly what's needed
- Use search operators where helpful (`"exact phrase"`, `site:`, `-exclude`)
- Include the current year for time-sensitive topics
- One query is often enough for simple factual lookups

**Examples of good queries:**
```
"Next.js 15 app router middleware configuration"
"site:docs.aws.amazon.com S3 presigned URL expiration"
"TypeScript 5.4 new features 2025"
"express.js rate limiting middleware comparison"
```

### Step 2: Execute Search

Call `@web-research/multi_search` with your queries:

```json
{
  "queries": ["query 1", "query 2"],
  "results_per_query": 5
}
```

**Parameters:**
- `queries` (required): Array of 1-3 search query strings
- `results_per_query` (optional): Number of results per query (default: 5, max: 10)

This returns deduplicated URLs with titles and snippets from DuckDuckGo.

### Step 3: Evaluate Results

Review the returned URLs and snippets:

- **If snippets answer the question**: Summarize directly from snippets with source links. Done.
- **If more detail is needed**: Proceed to Step 4 to fetch full page content.
- **If results are poor**: Refine queries and search again (once only — don't loop).

**Decision criteria for "snippets are enough":**
- The answer is a specific fact, number, or URL
- Multiple snippets confirm the same answer
- The question doesn't require nuanced explanation

### Step 4: Fetch Content (If Needed)

Call `@web-research/fetch_pages` with the **most relevant URLs** (typically 2-5):

```json
{
  "urls": ["url1", "url2", "url3"],
  "max_chars": 10000,
  "timeout": 15
}
```

**Parameters:**
- `urls` (required): Array of URLs to fetch
- `max_chars` (optional): Maximum characters to extract per page (default: 10000)
- `timeout` (optional): Timeout in seconds per fetch (default: 15)

Unlike deep research, you do NOT need to fetch all URLs. Select only the most relevant 2-5 results.

### Step 5: Summarize

Provide a concise answer with source links. Use the standard Research Report format from the ghost-researcher prompt.

## Output Integration

Results from this skill feed into ghost-researcher's standard output format:

```markdown
## Research Report: {Topic}

### Question
{What was researched}

### Findings

1. **{Finding}**: {description}
   - Evidence: {source URL}

### Recommendation
{Direct answer with supporting evidence}

### Confidence Level
{HIGH / MEDIUM / LOW} — {reason}

### References
- {source 1: URL}
- {source 2: URL}
```

For simple factual lookups, the findings section can be brief — even a single finding with a source link is acceptable.

## Search Query Patterns

### Documentation Lookups
```
"site:docs.example.com {topic}"
"{framework} {version} {feature} documentation"
"{library} API reference {method name}"
```

### Version/Release Checks
```
"{package} latest version {year}"
"{framework} changelog {version}"
"{tool} release notes {year}"
```

### Configuration/Syntax
```
"{tool} configuration {setting name} example"
"{language} {feature} syntax"
"how to configure {tool} {feature}"
```

### Error Resolution
```
"{exact error message}"
"{tool} {error code} fix"
"site:stackoverflow.com {error message}"
"site:github.com/org/repo/issues {error}"
```

### Comparison/Selection
```
"{option A} vs {option B} {year}"
"best {category} for {use case} {year}"
"{tool} alternatives comparison"
```

## Guidelines

### DO:
- Keep searches focused and minimal (1-3 queries)
- Prefer authoritative sources (official docs, reputable publications)
- Include source links for all claims
- Answer concisely — don't over-elaborate
- Note when information may be outdated
- Use search operators to narrow results

### DON'T:
- Generate more than 3 queries for simple questions
- Fetch pages when snippets already answer the question
- Provide lengthy analysis (use deep-research skill for that)
- Present speculation as fact
- Omit source attribution
- Loop on poor results more than once — refine query and try once more, then report what you found

## Error Handling

If `@web-research/multi_search` or `@web-research/fetch_pages` fails:
1. Note the error in your response
2. Fall back to `curl` via `shell` tool (see ghost-researcher prompt for fallback instructions)
3. If curl also fails, report that web research was unavailable and provide what you can from local sources
