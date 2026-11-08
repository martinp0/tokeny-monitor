# Local CSV import

The phone can read a CSV the user picks with the system document picker (Storage Access Framework). The bytes are parsed on the device. Nothing is sent to `tokeny.martinpohl.cz`. A preview lists what would be stored, and the rows are written only after confirmation, into the app-private file `files/local-ledger.json` (cleared with the app, and backup is off). The user can delete that file from the import screen.

The labeled sample never shares a screen with these rows. Sample copy says “ukázka”. Import copy says “import”. Entering the sample does not delete the file, and opening the file does not show sample amounts.

## Formats, taken from the web importer

Detection uses the header, same order as `src/hooks/useDashboardData.ts`: a Cursor / Grok Bot usage export (`src/lib/usage-export.ts`) wins when its columns are present; otherwise an OpenRouter activity export (`src/lib/csv-parser.ts`) is recognized by `generation_id` and `created_at`. Anything else is rejected before a preview can be saved.

| | OpenRouter activity | Cursor / Grok Bot usage export |
|---|---|---|
| Required header | `generation_id`, `created_at` (trimmed, exact) | `Billing Item ID`, `Event Time`, `Product`, and `Usage` or the separate token columns. Aliases match `HEADER_ALIASES` (case and punctuation ignored). |
| Cost | `cost_total`, JavaScript `parseFloat`. Empty or garbage becomes 0 and is counted in the preview. | `Pricing Contracted`. `$`, spaces, and thousands commas are removed (`$1,234.50`). |
| Id collision in the file | Last row wins | First row wins |
| Re-import of the same id | Overwrites (web posts these without `ignoreDuplicates`) | Keeps the stored row (`ignoreDuplicates: true`) |
| Provider | `provider_name`, source `openrouter` | `cursor` → Cursor, `grok-bot` → Grok Bot. `Grok Bot` and `grok_bot` map too. Other products are skipped. |
| Model | `model_permaslug` | `Model`, or the product source when the model is empty |
| Tokens | prompt, completion, reasoning, cached. Non-positive values become 0. | prompt = fresh + cached read + cache write. Cached and cache-write are kept separately. Output is completion. `int()` keeps only values above zero. |
| Billing tag | none | `Usage Type` `included` / `on_demand` / `credits`, otherwise omitted |
| Currency | USD, there is no currency column | Blank or `USD` only. Any other currency is skipped. |
| Not stored | `user`, `api_key_name`, and the other OpenRouter columns that are not spend metrics | `User Email`, `Principal ID`, `Principal Type`, `Charge Category` |

A cost written only as a comma decimal (`0,50` or `"0,50"`) is skipped and counted as `ambiguous_decimal`. The web usage importer would delete the comma and store 50. The OpenRouter importer would keep the digits before the comma. This app stores neither.

## Time zone

Days and months are `Europe/Prague`, not the phone zone.

- A timestamp with `Z` or a numeric offset is an instant. The civil day is Prague, including the 2026 transitions: spring forward on 29 March (02:00–03:00 does not exist) and fall back on 25 October (02:00–03:00 happens twice). `2026-03-28T23:30:00Z` is 29 March in Prague. `2026-10-24T22:30:00Z` is 25 October in Prague.
- A timestamp with no offset (`2026-05-13 11:45:06.165`, or `2026-10-22T09:15:00`) is a Prague wall clock. That keeps the date written in an OpenRouter export on the day the web dashboard shows, instead of shifting it by the device zone. A wall time inside the spring gap is moved forward one hour (still the same written day). A wall time inside the fall overlap uses the earlier, summer offset.

The chart for the import is the Prague month of the latest row, not “this month” unless that month is current. Today is the Prague day of the clock. If the file has no row that day, the total is 0 and the screen says so. Previous-month spend is shown only when the file contains that month. It is not a Pro entitlement.

## Limits

- 8 MB. Reading stops and nothing is parsed past that.
- 20 000 data rows in one file.
- 20 000 stored rows after merge. A preview that would pass the cap cannot be saved.
- Ids longer than 300 characters, fields longer than 16 000 characters, and timestamps longer than 40 characters are skipped. The server truncates some of these; this app does not, because a cut id could collide.

## What is not computed

No ČNB rate and no fallback of 23.5 is applied to imported USD. No monthly budget, alert threshold, or month-end forecast is invented. The budget tab says those exist on the server for a signed-in Pro account. The web’s free-plan 30-day floor is also not applied: this copy is not an account plan.

Token totals follow `computeTotals` in `src/lib/aggregations.ts`: prompt + completion + reasoning. Cached tokens are not added again. For a usage export, the plan split follows `usageBreakdown` (rows with a billing tag only).
