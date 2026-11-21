import { useEffect } from "react";
import { useQuery } from "@tanstack/react-query";
import { api } from "@/lib/api";
import { pricesFor, type PricingVariant } from "@/config/pricing";

interface PricingOfferResponse {
  variant?: string;
  experiment?: boolean;
}

/**
 * The price this browser should see. Until the server answers, and whenever the experiment
 * is off, that is the control price (99 / 990). The server assigns the variant; this hook
 * does not hash anything itself.
 */
export function usePricingOffer() {
  const { data, isSuccess } = useQuery({
    queryKey: ["pricing-offer"],
    queryFn: () => api<PricingOfferResponse>("/pricing"),
    enabled: typeof window !== "undefined",
    staleTime: 30 * 60 * 1000,
    retry: 1,
  });
  const variant: PricingVariant = data?.experiment && data.variant === "b" ? "b" : "control";
  return {
    variant,
    experiment: data?.experiment === true,
    prices: pricesFor(variant),
    ready: isSuccess,
  };
}

/** One view_paywall per browser. The server ignores any variant the client might send. */
export function useRecordPaywallView(active: boolean) {
  const { ready } = usePricingOffer();
  useEffect(() => {
    if (!active || !ready) return;
    void api("/pricing/event", { body: { event: "view_paywall" } }).catch(() => {});
  }, [active, ready]);
}
