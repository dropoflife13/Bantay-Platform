import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { ShieldCheck, MapPin, Database, WifiOff, Users, ArrowRight } from "lucide-react";

export default function Home() {
  const roles = [
    {
      title: "LGU Admin",
      role: "lgu_admin",
      description: "City/Municipal wide oversight, cross-market analytics, compliance, and revenue monitoring.",
    },
    {
      title: "Market Admin",
      role: "market_admin",
      description: "Supervise assigned public market, stall allocations, vendor compliance, and localized reporting.",
    },
    {
      title: "Vendor / Merchant",
      role: "vendor",
      description: "Offline-first Point-of-Sale, QR payments, boundary check, and confidential credit ledger (Utang).",
    },
  ];

  const architecturalPillars = [
    {
      icon: Database,
      title: "Database-Level Multi-Tenancy (RLS)",
      desc: "PostgreSQL Row-Level Security bound to Supabase JWT claims ensures tenant isolation.",
    },
    {
      icon: WifiOff,
      title: "Offline-First Sync Engine",
      desc: "IndexedDB queues synced via idempotent sync_offline_batch RPC function.",
    },
    {
      icon: MapPin,
      title: "PostGIS Geofencing",
      desc: "Automated geofence verification detecting out-of-bounds stall sales in real-time.",
    },
    {
      icon: ShieldCheck,
      title: "Immutable Ledger & Privacy",
      desc: "Strictly unmodifiable transactions with zero-access vendor debt privacy.",
    },
  ];

  return (
    <main className="mx-auto flex w-full max-w-4xl flex-1 flex-col gap-10 px-4 py-12 sm:py-16">
      <header className="flex flex-col gap-4">
        <div className="flex items-center gap-2">
          <span className="inline-flex items-center gap-1.5 rounded-full border border-border px-3 py-1 text-xs font-semibold text-primary">
            <span className="h-2 w-2 rounded-full bg-emerald-500 animate-pulse" />
            Bantay LGU Platform
          </span>
          <span className="text-xs text-muted-foreground">v0.1.0 MVP</span>
        </div>
        <h1 className="text-3xl font-bold tracking-tight sm:text-5xl">
          Formalizing Local Micro-Economies
        </h1>
        <p className="text-lg text-muted-foreground leading-relaxed">
          An enterprise B2G multi-tenant system purpose-built for intermittent-connectivity 
          environments, wet markets, and registered street vendors across local government units.
        </p>
      </header>

      {/* Persona Access Cards */}
      <section className="flex flex-col gap-4">
        <div className="flex items-center justify-between">
          <h2 className="text-xl font-semibold flex items-center gap-2">
            <Users className="h-5 w-5 text-muted-foreground" />
            Platform Portals & Personas
          </h2>
        </div>
        <div className="grid gap-4 sm:grid-cols-3">
          {roles.map((item) => (
            <Card key={item.role} className="flex flex-col justify-between">
              <CardHeader className="pb-3">
                <CardTitle className="text-base font-semibold">{item.title}</CardTitle>
                <CardDescription className="text-xs font-mono text-muted-foreground">
                  role: {item.role}
                </CardDescription>
              </CardHeader>
              <CardContent className="flex flex-col justify-between flex-1 gap-4">
                <p className="text-sm text-muted-foreground">{item.description}</p>
                <Button variant="outline" size="sm" className="w-full justify-between mt-auto">
                  <span>Enter Portal</span>
                  <ArrowRight className="h-3.5 w-3.5" />
                </Button>
              </CardContent>
            </Card>
          ))}
        </div>
      </section>

      {/* Core Architectural Pillars */}
      <section className="flex flex-col gap-4">
        <h2 className="text-xl font-semibold">Core Architectural Guarantees</h2>
        <div className="grid gap-4 sm:grid-cols-2">
          {architecturalPillars.map((pillar) => {
            const Icon = pillar.icon;
            return (
              <Card key={pillar.title}>
                <CardHeader className="flex flex-row items-start gap-3 space-y-0 pb-2">
                  <div className="rounded-md bg-secondary p-2 text-foreground">
                    <Icon className="h-5 w-5" />
                  </div>
                  <div className="flex flex-col gap-1">
                    <CardTitle className="text-base">{pillar.title}</CardTitle>
                    <CardDescription className="text-sm leading-normal">
                      {pillar.desc}
                    </CardDescription>
                  </div>
                </CardHeader>
              </Card>
            );
          })}
        </div>
      </section>

      <footer className="mt-auto border-t border-border pt-6 flex flex-col sm:flex-row items-center justify-between gap-4 text-xs text-muted-foreground">
        <span>Bantay LGU Platform • Next.js 16 + Supabase + PostGIS + Dexie.js</span>
        <span>Row-Level Security & Offline Ingestion Enforced</span>
      </footer>
    </main>
  );
}
