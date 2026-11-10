/**
 * The bundled sample (src/data/sample.csv) is a labelled preview of chart shape.
 * It must never be written to activity_rows, and the dashboard must not put it next to
 * budget, billing, alerts, exports, shared dashboards, or the assistant (those read the real account).
 */

export const SAMPLE_BLOCKED_SURFACES = ["budget", "alerts", "exports", "sharing", "billing", "ai"] as const;

export type SampleBlockedSurface = (typeof SAMPLE_BLOCKED_SURFACES)[number];

export interface DashboardChrome {
  budget: boolean;
  alerts: boolean;
  exports: boolean;
  sharing: boolean;
  /** Assistant tools read the signed-in account, so they stay off during the sample preview. */
  ai: boolean;
  /** "Older rows are stored" is false while the visitor is looking at rows that were never stored. */
  planNote: boolean;
}

export function dashboardChrome(samplePreview: boolean): DashboardChrome {
  if (samplePreview) {
    return { budget: false, alerts: false, exports: false, sharing: false, ai: false, planNote: false };
  }
  return { budget: true, alerts: true, exports: true, sharing: true, ai: true, planNote: true };
}
