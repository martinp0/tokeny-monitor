import type { ComponentType } from "react";
import { useParams } from "react-router-dom";
import NotFound from "./NotFound";
import { findPostBySlug, type BlogLocale } from "@/content/blog/catalog";
import { useBlogLocale } from "@/content/blog/locale";
import BlogAiCostSaving from "./BlogAiCostSaving";
import BlogPromptOptimization from "./BlogPromptOptimization";
import BlogTokenWindow from "./BlogTokenWindow";
import BlogModelComparison from "./BlogModelComparison";
import BlogMonitoringAiCosts from "./BlogMonitoringAiCosts";
import BlogMultiProvider from "./BlogMultiProvider";
import BlogGrokTokens from "./BlogGrokTokens";
import BlogAiAgentCosts from "./BlogAiAgentCosts";
import BlogTrackCursorGrokCosts from "./BlogTrackCursorGrokCosts";
import BlogLocalModels from "./BlogLocalModels";
import BlogWhatAiCosts from "./BlogWhatAiCosts";

const BODIES: Record<string, ComponentType<{ locale: BlogLocale }>> = {
  "track-cursor": BlogTrackCursorGrokCosts,
  "ai-agents": BlogAiAgentCosts,
  "grok-tokens": BlogGrokTokens,
  "local-models": BlogLocalModels,
  "multi-provider": BlogMultiProvider,
  "model-comparison": BlogModelComparison,
  "monitoring": BlogMonitoringAiCosts,
  "ai-cost-saving": BlogAiCostSaving,
  "prompt-optimization": BlogPromptOptimization,
  "token-window": BlogTokenWindow,
  "what-ai-costs": BlogWhatAiCosts,
};

export default function BlogArticle() {
  const { slug = "" } = useParams();
  const locale = useBlogLocale();
  const post = findPostBySlug(locale, slug);
  if (!post) return <NotFound />;
  const Body = BODIES[post.id];
  if (!Body) return <NotFound />;
  return <Body locale={locale} />;
}
