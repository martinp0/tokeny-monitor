# Model price sources

Checked 2026-11-17. Amounts are USD per 1,000,000 tokens, short context only. `cacheWrite` is the 5-minute cache write when the provider publishes a separate 1-hour write. The catalog does not guess a price the page does not print.

`batchFraction` is set only when the published batch input, output and cached rates are exactly that share of the standard rates. A missing fraction means the batch tip stays off.

## Anthropic

Source: <https://platform.claude.com/docs/en/about-claude/pricing> (checked 2026-11-17).

Columns: base input, 5-minute cache write, cache hits, output. Batch is 50% of input and output.

| id | input | 5m cache write | cache hit | output | batchFraction |
| --- | --- | --- | --- | --- | --- |
| claude-opus-4-6 | 5 | 6.25 | 0.50 | 25 | 0.5 |
| claude-opus-4-5 | 5 | 6.25 | 0.50 | 25 | 0.5 |
| claude-sonnet-5-5 | 2 | 2.50 | 0.10 | 10 | 0.5 |
| claude-sonnet-4-6 | 3 | 3.75 | 0.30 | 15 | 0.5 |
| claude-haiku-4-5 | 1 | 1.25 | 0.10 | 5 | 0.5 |
| claude-haiku-5-5 | 0.10 | 0.125 | 0.01 | 0.50 | 0.5 |

Haiku 5.5 in the file is the rate for prompts up to 100,000 tokens. Prompts over that length are a different published rate and are not stored. The 1-hour cache write is published and is not the `cacheWrite` column.

## OpenAI

Source: <https://developers.openai.com/api/docs/pricing> (checked 2026-11-17). Standard, short context (≤272K).

| id | input | cached | output | batchFraction |
| --- | --- | --- | --- | --- |
| gpt-5.6-sol | 4 | 0.40 | 20 | 0.5 |
| gpt-5.6-terra | 2 | 0.20 | 12 | 0.5 |
| gpt-5.6-luna | 0.20 | 0.02 | 1.20 | 0.5 |
| gpt-5.4 | 2.50 | 0.25 | 15 | omitted |
| gpt-6-sol | 2 | 0.20 | 10 | 0.5 |
| gpt-6-luna | 0.10 | 0.01 | 0.50 | 0.5 |
| gpt-6.1-sol | 2 | 0.10 | 10 | 0.5 |
| gpt-6.1-terra | 1 | 0.05 | 5 | 0.5 |

`gpt-5.4` batch cached input is published as $0.13, not half of $0.25, so `batchFraction` is omitted.

`gpt-5.6-sol` promotional pricing is available until 30 Nov 2026. The page does not publish the price after that date. The row is valid through 2026-11-30. From 2026-12-01 the id is listed under `unverified` and is not used.

## Gemini

Source: <https://ai.google.dev/gemini-api/docs/pricing> (checked 2026-11-17). The paid-tier description says the Batch API is a 50% cost reduction. Cached rates below are the published context-caching prices.

| id | when | input | cached | output |
| --- | --- | --- | --- | --- |
| gemini-4-carbon | through 2026-11-30 | 2 | 0.10 | 10 |
| gemini-4-carbon | from 2026-12-01 | 4 | 0.20 | 20 |
| gemini-4-argon | through 2026-11-30 | 2 | 0.10 | 10 |
| gemini-4-argon | from 2026-12-01 | 4 | 0.20 | 20 |
| gemini-4-hydrogen | current | 1.50 | 0.075 | 7.50 |
| gemini-3.5-flash-lite | current | 0.30 | 0.03 | 2.50 |

Carbon and Argon do not stop after 30 Nov 2026. The same page, and <https://blog.google/innovation-and-ai/models-and-research/gemini-models/gemini-4-carbon-now-available/> (10 Nov 2026), state the introductory $2 / $10 rate through 30 Nov 2026 and $4 / $20 from 1 Dec 2026. Both periods are stored. `batchFraction` is 0.5 on each.

## xAI

Source: <https://docs.x.ai/developers/pricing> (checked 2026-11-17). Rates below are for prompts under 200,000 tokens.

| id | input | cached | output |
| --- | --- | --- | --- |
| grok-4.7 | 2 | 0.50 | 6 |
| grok-4.3 | 1.25 | 0.20 | 2.50 |

Batch for these models is 20% off, not half. `batchFraction` is omitted so the tip, which describes a half-price batch tier, does not claim 50%.
