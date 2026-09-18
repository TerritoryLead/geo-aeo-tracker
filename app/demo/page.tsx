import { SovereignDashboard } from "@/components/sovereign-dashboard";

export const metadata = {
  title: "Octo AEO — Demo",
  description: "Read-only demo of Octo AEO. Explore AI-visibility tracking, competitor battlecards, citation analysis, and the SRO pipeline.",
};

export default function DemoPage() {
  return <SovereignDashboard demoMode />;
}
