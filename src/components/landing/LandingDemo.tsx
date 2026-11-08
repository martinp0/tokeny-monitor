import { useEffect } from "react";
import { useTranslation } from "react-i18next";
import { useDashboardData } from "@/hooks/useDashboardData";
import { useCurrency } from "@/hooks/useCurrency";
import { KpiCards } from "@/components/dashboard/KpiCards";
import { CostTimeChart } from "@/components/dashboard/CostTimeChart";
import { TokensChart } from "@/components/dashboard/TokensChart";
import { ModelCostChart } from "@/components/dashboard/ModelCostChart";
import { ProviderChart } from "@/components/dashboard/ProviderChart";
import { SpeedChart } from "@/components/dashboard/SpeedChart";
import { RequestsTable } from "@/components/dashboard/RequestsTable";

export default function LandingDemo() {
  const { t } = useTranslation();
  const { prefetchExchangeRate } = useCurrency();
  const {
    filteredData,
    selectedModel,
    setSelectedModel,
    totalCost,
    totalRequests,
    totalTokens,
    avgGenTime,
    costByModel,
    costByProvider,
    timeSeries,
  } = useDashboardData({ demoMode: true });

  useEffect(() => {
    prefetchExchangeRate();
  }, [prefetchExchangeRate]);

  return (
    <div className="space-y-4 min-w-0 max-w-full overflow-hidden">
      <p className="inline-flex items-center rounded-full bg-primary/10 px-3 min-h-8 text-xs font-medium text-primary" role="status">
        {t("sample.badge")}
      </p>
      <KpiCards
        totalCost={totalCost}
        totalRequests={totalRequests}
        totalTokens={totalTokens}
        avgGenTime={avgGenTime}
      />
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-4 min-w-0">
        <div className="min-w-0 overflow-hidden">
          <CostTimeChart data={timeSeries} />
        </div>
        <div className="min-w-0 overflow-hidden">
          <TokensChart data={timeSeries} />
        </div>
      </div>
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-4 min-w-0">
        <div className="min-w-0 overflow-hidden">
          <ModelCostChart data={costByModel} onModelClick={setSelectedModel} selectedModel={selectedModel} />
        </div>
        <div className="min-w-0 overflow-hidden">
          <ProviderChart data={costByProvider} />
        </div>
        <div className="min-w-0 overflow-hidden">
          <SpeedChart data={timeSeries} />
        </div>
      </div>
      <div className="min-w-0 max-w-full overflow-hidden">
        <RequestsTable data={filteredData} />
      </div>
    </div>
  );
}
