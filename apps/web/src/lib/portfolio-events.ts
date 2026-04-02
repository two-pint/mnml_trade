export const PORTFOLIOS_CHANGED_EVENT = "mnml-portfolios-changed";

export function dispatchPortfoliosChanged(): void {
  if (typeof window !== "undefined") {
    window.dispatchEvent(new Event(PORTFOLIOS_CHANGED_EVENT));
  }
}
