"use client";

import {
  AnimatePresence,
  motion,
  useReducedMotion,
} from "framer-motion";
import {
  AlertTriangle,
  ArrowUpRight,
  BadgeCheck,
  BarChart3,
  Building2,
  CalendarClock,
  CheckCircle2,
  ChevronRight,
  CircleDollarSign,
  ClipboardCheck,
  Clock3,
  FileWarning,
  Flame,
  Gauge,
  HandCoins,
  KeyRound,
  Landmark,
  LockKeyhole,
  MapPin,
  MoreHorizontal,
  RadioTower,
  ShieldCheck,
  Sparkles,
  Target,
  TimerReset,
  TrendingUp,
  UserCheck,
  Users,
  X,
  Zap,
} from "lucide-react";
import { ReactNode, useMemo, useState } from "react";

type LeadQuality = "Hot" | "Warm" | "Cold";
type DataLoanStatus = "Active" | "Expired" | "Revoked";
type CallStatus = "Pending" | "Interested" | "Not Reachable" | "Call Later";
type VisitStatus = "Not Scheduled" | "Scheduled" | "Verified" | "No Show";
type BrokerLockStatus = "Pending" | "Active" | "Expired" | "Blocked" | "Not Started";
type BookingStage =
  | "Not Started"
  | "Booking Discussion"
  | "Token"
  | "Closed"
  | "Lost";
type BrokerageStatus = "Tracking" | "Eligible" | "Paid" | "Disputed" | "Blocked";

type SafeLead = {
  alias: string;
  project: string;
  area: string;
  budget: string;
  assignedTo: string;
  dataLoan: DataLoanStatus;
  callStatus: CallStatus;
  visitStatus: VisitStatus;
  brokerLock: BrokerLockStatus;
  bookingStage: BookingStage;
  brokerageStatus: BrokerageStatus;
  quality: LeadQuality;
  nextAction: string;
};

type ActionItem = {
  title: string;
  helper: string;
  icon: ReactNode;
  tone: "gold" | "green" | "blue" | "orange" | "red" | "zinc";
};

const broker = {
  firstName: "Jitu",
  brokerId: "BRK-JSN-0001",
  name: "Jitu Gupta",
  company: "JSN Enterprise",
  area: "Mira Road",
  project: "The Wadhwa Wise City, Panvel",
  manager: "Vinod Gupta",
  status: "Verified Active Broker",
  rank: "Silver",
  rankBadge: "Verified Performance Rank #4",
  trustScore: "98%",
};

const leads: SafeLead[] = [
  {
    alias: "L-1042",
    project: "Wadhwa Wise City",
    area: "Mira Road",
    budget: "₹80L–₹1Cr",
    assignedTo: "Rahul Caller",
    dataLoan: "Active",
    callStatus: "Interested",
    visitStatus: "Scheduled",
    brokerLock: "Pending",
    bookingStage: "Not Started",
    brokerageStatus: "Tracking",
    quality: "Hot",
    nextAction: "Confirm Sunday site visit",
  },
  {
    alias: "L-1088",
    project: "Wadhwa Wise City",
    area: "Bhayandar",
    budget: "₹65L–₹85L",
    assignedTo: "Vinod SM",
    dataLoan: "Expired",
    callStatus: "Call Later",
    visitStatus: "Not Scheduled",
    brokerLock: "Not Started",
    bookingStage: "Not Started",
    brokerageStatus: "Tracking",
    quality: "Warm",
    nextAction: "Renew call access",
  },
  {
    alias: "L-1120",
    project: "Wadhwa Wise City",
    area: "Mira Road",
    budget: "₹1Cr–₹1.25Cr",
    assignedTo: "Rahul Caller",
    dataLoan: "Revoked",
    callStatus: "Not Reachable",
    visitStatus: "Not Scheduled",
    brokerLock: "Blocked",
    bookingStage: "Lost",
    brokerageStatus: "Blocked",
    quality: "Cold",
    nextAction: "Review lead quality",
  },
];

const actions: ActionItem[] = [
  {
    title: "Secure Call",
    helper: "Protected bridge request only",
    icon: <RadioTower className="h-5 w-5" />,
    tone: "green",
  },
  {
    title: "Assign to Caller",
    helper: "Caller sees only safe lead alias",
    icon: <Users className="h-5 w-5" />,
    tone: "blue",
  },
  {
    title: "Assign to Sourcing Manager",
    helper: "Move lead to Vinod SM queue",
    icon: <UserCheck className="h-5 w-5" />,
    tone: "gold",
  },
  {
    title: "Revoke Access",
    helper: "Stop active call permission",
    icon: <LockKeyhole className="h-5 w-5" />,
    tone: "red",
  },
  {
    title: "Extend Access",
    helper: "Add more time for allowed caller",
    icon: <TimerReset className="h-5 w-5" />,
    tone: "orange",
  },
  {
    title: "Set Follow-up",
    helper: "Create next action reminder",
    icon: <CalendarClock className="h-5 w-5" />,
    tone: "orange",
  },
  {
    title: "View Broker Lock",
    helper: "Check credit protection status",
    icon: <ShieldCheck className="h-5 w-5" />,
    tone: "green",
  },
  {
    title: "Raise Issue",
    helper: "Open protected broker credit review",
    icon: <FileWarning className="h-5 w-5" />,
    tone: "red",
  },
];

const kpis = [
  { label: "Total Leads", value: "126", icon: <ClipboardCheck />, tone: "blue" },
  { label: "Hot Leads", value: "18", icon: <Flame />, tone: "purple" },
  { label: "Calls Attempted", value: "74", icon: <RadioTower />, tone: "green" },
  { label: "Interested Leads", value: "31", icon: <BadgeCheck />, tone: "green" },
  { label: "Site Visits Scheduled", value: "12", icon: <CalendarClock />, tone: "blue" },
  { label: "Verified Visits", value: "9", icon: <CheckCircle2 />, tone: "green" },
  { label: "Active 45-Day Locks", value: "7", icon: <ShieldCheck />, tone: "gold", highlight: true },
  { label: "Data Loans Active", value: "14", icon: <KeyRound />, tone: "orange" },
  { label: "Booking Discussions", value: "5", icon: <Landmark />, tone: "orange" },
  { label: "Brokerage Tracking", value: "₹18.4L", icon: <HandCoins />, tone: "gold" },
];

function cn(...classes: Array<string | false | null | undefined>) {
  return classes.filter(Boolean).join(" ");
}

function toneClasses(tone: string) {
  const tones: Record<string, string> = {
    green: "border-green-500/20 bg-green-500/10 text-green-400 shadow-green-500/10",
    orange: "border-orange-500/20 bg-orange-500/10 text-orange-400 shadow-orange-500/10",
    red: "border-red-500/20 bg-red-500/10 text-red-400 shadow-red-500/10",
    blue: "border-blue-500/20 bg-blue-500/10 text-blue-400 shadow-blue-500/10",
    purple: "border-purple-500/20 bg-purple-500/10 text-purple-400 shadow-purple-500/10",
    gold: "border-amber-400/30 bg-amber-400/10 text-amber-300 shadow-amber-500/20",
    zinc: "border-zinc-500/20 bg-zinc-500/10 text-zinc-400 shadow-zinc-500/10",
  };
  return tones[tone] ?? tones.zinc;
}

function statusTone(value: string) {
  const safe = value.toLowerCase();
  if (["not scheduled", "not started", "inactive", "cold"].some((x) => safe.includes(x))) return "zinc";
  if (["verified", "active", "interested", "completed", "paid", "eligible"].some((x) => safe.includes(x))) return "green";
  if (["pending", "call later", "follow", "booking discussion", "tracking", "warm"].some((x) => safe.includes(x))) return "orange";
  if (["blocked", "revoked", "expired", "rejected", "lost", "no show", "disputed"].some((x) => safe.includes(x))) return "red";
  if (["scheduled", "assigned"].some((x) => safe.includes(x))) return "blue";
  if (["hot", "high", "premium"].some((x) => safe.includes(x))) return "purple";
  return "zinc";
}

function actionTone(tone: ActionItem["tone"]) {
  const tones: Record<ActionItem["tone"], string> = {
    gold: "text-amber-300 bg-amber-400/10 border-amber-400/20",
    green: "text-green-400 bg-green-500/10 border-green-500/20",
    blue: "text-blue-400 bg-blue-500/10 border-blue-500/20",
    orange: "text-orange-400 bg-orange-500/10 border-orange-500/20",
    red: "text-red-400 bg-red-500/10 border-red-500/20",
    zinc: "text-zinc-400 bg-zinc-500/10 border-zinc-500/20",
  };
  return tones[tone];
}

function primaryActionForLead(lead: SafeLead) {
  if (lead.dataLoan === "Expired") return "Renew Call Access";
  if (lead.visitStatus === "Scheduled" || lead.visitStatus === "Verified") return "View Visit Status";
  if (lead.callStatus === "Call Later") return "Schedule Follow-up";
  return "Grant Call Access";
}

function MotionCard({
  children,
  className,
  delay = 0,
}: {
  children: ReactNode;
  className?: string;
  delay?: number;
}) {
  const reduceMotion = useReducedMotion();
  return (
    <motion.section
      initial={reduceMotion ? false : { y: 14, opacity: 0 }}
      animate={reduceMotion ? undefined : { y: 0, opacity: 1 }}
      transition={{ duration: 0.42, delay, ease: "easeOut" }}
      whileHover={reduceMotion ? undefined : { y: -2 }}
      className={cn(
        "rounded-2xl border border-white/5 bg-white/[0.03] shadow-2xl shadow-black/20 backdrop-blur-xl",
        "transition-colors hover:border-amber-300/20",
        className,
      )}
    >
      {children}
    </motion.section>
  );
}

export default function BrokerDashboardFutureTrust() {
  const [activeLead, setActiveLead] = useState<SafeLead | null>(null);
  const [desktopLead, setDesktopLead] = useState<string | null>(null);

  const loanSummary = useMemo(
    () => ({
      active: leads.filter((lead) => lead.dataLoan === "Active").length,
      expired: leads.filter((lead) => lead.dataLoan === "Expired").length,
      revoked: leads.filter((lead) => lead.dataLoan === "Revoked").length,
    }),
    [],
  );

  return (
    <main
      className="min-h-screen overflow-x-hidden bg-zinc-950 text-zinc-50"
      style={{ fontFamily: "Inter, Roboto, system-ui, sans-serif" }}
    >
      <div className="pointer-events-none fixed inset-0 -z-10">
        <div className="absolute left-1/2 top-[-8rem] h-80 w-80 -translate-x-1/2 rounded-full bg-amber-500/10 blur-3xl" />
        <div className="absolute right-[-8rem] top-1/3 h-80 w-80 rounded-full bg-blue-500/10 blur-3xl" />
        <div className="absolute bottom-[-12rem] left-[-10rem] h-96 w-96 rounded-full bg-green-500/10 blur-3xl" />
      </div>

      <StickyTrustHeader />

      <div className="mx-auto max-w-7xl px-4 pb-24 pt-5 sm:px-6 lg:px-8">
        <KpiRibbon />

        <div className="mt-5 grid gap-4 lg:grid-cols-[1.05fr_0.95fr] xl:grid-cols-[1.12fr_0.88fr]">
          <div className="space-y-4">
            <BrokerIdentityCard />
            <GrowthInsightCard />
            <LeadPipelineSummary />
            <section>
              <SectionTitle
                icon={<LockKeyhole className="h-5 w-5" />}
                title="Secure Lead Cards Feed"
                helper="Lead alias, status, and next action only"
              />
              <div className="mt-3 space-y-4">
                {leads.length === 0 ? (
                  <SafeEmptyState />
                ) : (
                  leads.map((lead, index) => (
                    <SecureLeadCard
                      key={lead.alias}
                      lead={lead}
                      index={index}
                      isDesktopMenuOpen={desktopLead === lead.alias}
                      onOpenMobile={() => setActiveLead(lead)}
                      onToggleDesktop={() =>
                        setDesktopLead((current) =>
                          current === lead.alias ? null : lead.alias,
                        )
                      }
                      onCloseDesktop={() => setDesktopLead(null)}
                    />
                  ))
                )}
              </div>
            </section>
          </div>

          <aside className="space-y-4 lg:sticky lg:top-24 lg:self-start">
            <SecureNoticeBanner />
            <DataLoanStatusStrip summary={loanSummary} />
            <BrokerLockTimeline />
            <BrokerageBookingStatus />
            <SuggestedNextActions />
          </aside>
        </div>
      </div>

      <LeadActionBottomSheet
        lead={activeLead}
        actions={actions}
        onClose={() => setActiveLead(null)}
      />
    </main>
  );
}

function StickyTrustHeader() {
  const reduceMotion = useReducedMotion();
  return (
    <motion.header
      initial={reduceMotion ? false : { y: -24, opacity: 0 }}
      animate={reduceMotion ? undefined : { y: 0, opacity: 1 }}
      transition={{ duration: 0.45, ease: "easeOut" }}
      className="sticky top-0 z-40 border-b border-white/5 bg-zinc-950/78 backdrop-blur-2xl"
    >
      <div className="mx-auto flex max-w-7xl items-center gap-3 px-4 py-3 sm:px-6 lg:px-8">
        <div className="flex h-11 w-11 shrink-0 items-center justify-center rounded-2xl border border-amber-300/20 bg-amber-400/10 shadow-lg shadow-amber-500/10">
          <ShieldCheck className="h-5 w-5 text-amber-300" />
        </div>
        <div className="min-w-0 flex-1">
          <div className="flex items-center gap-2">
            <h1 className="truncate text-lg font-black tracking-tight text-white sm:text-xl">
              Good Morning, {broker.firstName}
            </h1>
            <span className="hidden rounded-full border border-green-500/20 bg-green-500/10 px-2 py-1 text-[11px] font-bold text-green-400 sm:inline-flex">
              {broker.status}
            </span>
          </div>
          <p className="mt-0.5 truncate text-sm font-medium text-zinc-400">
            {broker.company} • {broker.area}
          </p>
        </div>
        <div className="hidden items-center gap-2 md:flex">
          <HeaderBadge icon={<BadgeCheck />} label={broker.rankBadge} tone="gold" />
          <HeaderBadge icon={<Gauge />} label={`Trust Score ${broker.trustScore}`} tone="green" />
          <HeaderBadge icon={<LockKeyhole />} label="Data Protected" tone="blue" />
        </div>
        <button
          className="inline-flex h-11 items-center justify-center rounded-xl border border-white/10 bg-white/[0.04] px-3 text-sm font-bold text-zinc-200 active:scale-95 md:hidden"
          type="button"
        >
          Vault
        </button>
      </div>
      <div className="scrollbar-hide flex gap-2 overflow-x-auto px-4 pb-3 md:hidden">
        <HeaderBadge icon={<BadgeCheck />} label="Rank #4" tone="gold" />
        <HeaderBadge icon={<Gauge />} label={broker.trustScore} tone="green" />
        <HeaderBadge icon={<LockKeyhole />} label="Protected" tone="blue" />
      </div>
    </motion.header>
  );
}

function HeaderBadge({
  icon,
  label,
  tone,
}: {
  icon: ReactNode;
  label: string;
  tone: string;
}) {
  return (
    <span
      className={cn(
        "inline-flex shrink-0 items-center gap-1.5 rounded-full border px-3 py-1.5 text-xs font-bold shadow-lg",
        toneClasses(tone),
      )}
    >
      <span className="[&>svg]:h-3.5 [&>svg]:w-3.5">{icon}</span>
      {label}
    </span>
  );
}

function KpiRibbon() {
  const reduceMotion = useReducedMotion();
  return (
    <motion.section
      initial={reduceMotion ? false : { y: 12, opacity: 0 }}
      animate={reduceMotion ? undefined : { y: 0, opacity: 1 }}
      transition={{ duration: 0.42, delay: 0.08, ease: "easeOut" }}
      className="scrollbar-hide -mx-4 flex snap-x gap-3 overflow-x-auto px-4 pb-1 sm:mx-0 sm:px-0"
    >
      {kpis.map((kpi) => (
        <KpiCard key={kpi.label} {...kpi} />
      ))}
    </motion.section>
  );
}

function KpiCard({
  label,
  value,
  icon,
  tone,
  highlight,
}: {
  label: string;
  value: string;
  icon: ReactNode;
  tone: string;
  highlight?: boolean;
}) {
  return (
    <motion.article
      whileHover={{ y: -2 }}
      whileTap={{ scale: 0.98 }}
      className={cn(
        "min-w-[156px] snap-start rounded-2xl border bg-zinc-900/70 p-4 shadow-xl backdrop-blur",
        "sm:min-w-[180px]",
        highlight
          ? "border-amber-300/30 bg-amber-400/[0.08] shadow-amber-500/20"
          : "border-white/5 shadow-black/20",
      )}
    >
      <div className="mb-3 flex items-center justify-between">
        <span className={cn("rounded-xl border p-2", toneClasses(tone))}>
          <span className="[&>svg]:h-4 [&>svg]:w-4">{icon}</span>
        </span>
        {highlight ? (
          <span className="h-2 w-2 rounded-full bg-amber-300 shadow-[0_0_18px_rgba(251,191,36,0.9)]" />
        ) : null}
      </div>
      <p className="text-2xl font-black tracking-tight text-white">{value}</p>
      <p className="mt-1 text-xs font-semibold uppercase tracking-wide text-zinc-500">
        {label}
      </p>
    </motion.article>
  );
}

function BrokerIdentityCard() {
  const identity = [
    ["Broker ID", broker.brokerId],
    ["Broker Name", broker.name],
    ["Company", broker.company],
    ["Area Strength", broker.area],
    ["Connected Project", broker.project],
    ["Connected Sourcing Manager", broker.manager],
    ["Status", broker.status],
    ["Verified Performance Rank", broker.rank],
    ["Trust Score", broker.trustScore],
  ];

  return (
    <MotionCard className="overflow-hidden">
      <div className="relative p-5">
        <div className="absolute right-0 top-0 h-32 w-32 rounded-full bg-amber-400/10 blur-3xl" />
        <div className="relative flex items-start justify-between gap-4">
          <div>
            <p className="text-xs font-bold uppercase tracking-[0.22em] text-amber-300">
              Broker Business Vault
            </p>
            <h2 className="mt-2 text-2xl font-black tracking-tight text-white sm:text-3xl">
              {broker.name}
            </h2>
            <p className="mt-1 text-sm font-medium text-zinc-400">
              Aapka broker credit system mein protected hai.
            </p>
          </div>
          <div className="hidden h-14 w-14 shrink-0 items-center justify-center rounded-2xl border border-amber-300/20 bg-amber-400/10 sm:flex">
            <BadgeCheck className="h-7 w-7 text-amber-300" />
          </div>
        </div>

        <div className="relative mt-5 grid gap-3 sm:grid-cols-2">
          {identity.map(([label, value]) => (
            <div
              key={label}
              className="rounded-xl border border-white/5 bg-black/20 p-3"
            >
              <p className="text-[11px] font-bold uppercase tracking-wide text-zinc-500">
                {label}
              </p>
              <p className="mt-1 text-sm font-bold leading-snug text-zinc-100">
                {value}
              </p>
            </div>
          ))}
        </div>
      </div>
    </MotionCard>
  );
}

function GrowthInsightCard() {
  return (
    <MotionCard className="p-5" delay={0.04}>
      <div className="flex items-start gap-3">
        <div className="flex h-11 w-11 shrink-0 items-center justify-center rounded-2xl border border-amber-300/20 bg-amber-400/10">
          <Sparkles className="h-5 w-5 text-amber-300" />
        </div>
        <div className="min-w-0 flex-1">
          <p className="text-xs font-bold uppercase tracking-[0.2em] text-zinc-500">
            Today&apos;s Smart Growth Tip
          </p>
          <p className="mt-2 text-base font-semibold leading-7 text-white">
            Your Mira Road leads are converting better for Wadhwa Wise City.
            Send more ₹80L–₹1Cr budget buyers this week.
          </p>
          <div className="mt-4 flex flex-wrap gap-2">
            <StatusPill label="Strongest Area: Mira Road" />
            <StatusPill label="Best Project: Wadhwa Wise City" />
            <StatusPill label="Lead Quality: Strong" />
          </div>
          <motion.button
            whileTap={{ scale: 0.95 }}
            className="mt-4 inline-flex h-12 items-center gap-2 rounded-xl bg-amber-400 px-5 text-sm font-black text-zinc-950 shadow-lg shadow-amber-500/20"
            type="button"
          >
            View Growth Plan
            <ArrowUpRight className="h-4 w-4" />
          </motion.button>
        </div>
      </div>
    </MotionCard>
  );
}

function LeadPipelineSummary() {
  const rows = [
    { label: "Lead Received", value: 126, tone: "blue" },
    { label: "Interested", value: 31, tone: "green" },
    { label: "Visit Scheduled", value: 12, tone: "blue" },
    { label: "Verified", value: 9, tone: "green" },
    { label: "Booking Discussion", value: 5, tone: "orange" },
  ];

  return (
    <MotionCard className="p-5" delay={0.08}>
      <SectionTitle
        icon={<BarChart3 className="h-5 w-5" />}
        title="Lead Pipeline Summary"
        helper="Simple movement view for today"
        nested
      />
      <div className="mt-4 space-y-3">
        {rows.map((row) => (
          <div key={row.label}>
            <div className="mb-1.5 flex items-center justify-between text-sm">
              <span className="font-semibold text-zinc-300">{row.label}</span>
              <span className="font-black text-white">{row.value}</span>
            </div>
            <div className="h-2 overflow-hidden rounded-full bg-white/5">
              <div
                className={cn(
                  "h-full rounded-full",
                  row.tone === "green" && "bg-green-400",
                  row.tone === "blue" && "bg-blue-400",
                  row.tone === "orange" && "bg-orange-400",
                )}
                style={{ width: `${Math.max(12, Math.min(100, row.value))}%` }}
              />
            </div>
          </div>
        ))}
      </div>
    </MotionCard>
  );
}

function SecureLeadCard({
  lead,
  index,
  isDesktopMenuOpen,
  onOpenMobile,
  onToggleDesktop,
  onCloseDesktop,
}: {
  lead: SafeLead;
  index: number;
  isDesktopMenuOpen: boolean;
  onOpenMobile: () => void;
  onToggleDesktop: () => void;
  onCloseDesktop: () => void;
}) {
  const reduceMotion = useReducedMotion();
  const primaryAction = primaryActionForLead(lead);

  return (
    <motion.article
      initial={reduceMotion ? false : { y: 18, opacity: 0 }}
      animate={reduceMotion ? undefined : { y: 0, opacity: 1 }}
      transition={{ duration: 0.38, delay: index * 0.09, ease: "easeOut" }}
      whileHover={reduceMotion ? undefined : { y: -2 }}
      whileTap={{ scale: 0.99 }}
      className="relative rounded-2xl border border-white/5 bg-zinc-900/80 p-4 shadow-2xl shadow-black/20 transition-colors hover:border-amber-300/20"
    >
      <div className="flex items-start justify-between gap-3">
        <div>
          <div className="flex flex-wrap items-center gap-2">
            <h3 className="text-xl font-black tracking-tight text-white">
              Lead {lead.alias}
            </h3>
            <StatusPill label={lead.quality} />
          </div>
          <p className="mt-1 text-sm font-medium text-zinc-400">
            {lead.project} • {lead.area}
          </p>
        </div>
        <div className="rounded-2xl border border-white/5 bg-white/[0.03] p-2 text-amber-300">
          <Building2 className="h-5 w-5" />
        </div>
      </div>

      <div className="mt-4 grid grid-cols-2 gap-2 sm:grid-cols-3">
        <StatusPill label={`Data Loan: ${lead.dataLoan}`} />
        <StatusPill label={`Call Status: ${lead.callStatus}`} />
        <StatusPill label={`Visit Status: ${lead.visitStatus}`} />
        <StatusPill label={`Broker Lock: ${lead.brokerLock}`} />
        <StatusPill label={`Booking: ${lead.bookingStage}`} />
        <StatusPill label={`Brokerage: ${lead.brokerageStatus}`} />
      </div>

      <div className="mt-4 grid gap-3 rounded-2xl border border-white/5 bg-black/20 p-3 sm:grid-cols-2">
        <SafeMeta icon={<CircleDollarSign />} label="Budget Range" value={lead.budget} />
        <SafeMeta icon={<UserCheck />} label="Assigned To" value={lead.assignedTo} />
        <SafeMeta icon={<Clock3 />} label="Next Follow-up" value="Today / Tomorrow" />
        <SafeMeta icon={<Target />} label="Suggested Next Action" value={lead.nextAction} />
      </div>

      <div className="mt-4 flex gap-2">
        <motion.button
          whileTap={{ scale: 0.95 }}
          className="h-14 flex-[0.7] rounded-xl bg-amber-400 px-4 text-sm font-black text-zinc-950 shadow-lg shadow-amber-500/25"
          type="button"
        >
          {primaryAction}
        </motion.button>
        <motion.button
          whileTap={{ scale: 0.95 }}
          onClick={() => {
            onOpenMobile();
            onToggleDesktop();
          }}
          className="flex h-14 flex-[0.3] items-center justify-center rounded-xl border border-white/10 bg-white/[0.04] text-zinc-100"
          type="button"
          aria-label={`Open actions for lead ${lead.alias}`}
        >
          <MoreHorizontal className="h-6 w-6" />
        </motion.button>
      </div>

      <DesktopActionPopover
        lead={lead}
        open={isDesktopMenuOpen}
        actions={actions}
        onClose={onCloseDesktop}
      />
    </motion.article>
  );
}

function SafeMeta({
  icon,
  label,
  value,
}: {
  icon: ReactNode;
  label: string;
  value: string;
}) {
  return (
    <div className="flex gap-2">
      <span className="mt-0.5 text-zinc-500 [&>svg]:h-4 [&>svg]:w-4">{icon}</span>
      <div className="min-w-0">
        <p className="text-[11px] font-bold uppercase tracking-wide text-zinc-500">
          {label}
        </p>
        <p className="truncate text-sm font-bold text-zinc-100">{value}</p>
      </div>
    </div>
  );
}

function StatusPill({ label }: { label: string }) {
  return (
    <span
      className={cn(
        "inline-flex min-h-8 items-center rounded-full border px-3 py-1 text-[11px] font-extrabold leading-tight shadow-lg",
        toneClasses(statusTone(label)),
      )}
    >
      {label}
    </span>
  );
}

function LeadActionBottomSheet({
  lead,
  actions,
  onClose,
}: {
  lead: SafeLead | null;
  actions: ActionItem[];
  onClose: () => void;
}) {
  return (
    <AnimatePresence>
      {lead ? (
        <motion.div
          className="fixed inset-0 z-50 md:hidden"
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          exit={{ opacity: 0 }}
        >
          <button
            className="absolute inset-0 bg-black/60 backdrop-blur-sm"
            type="button"
            aria-label="Close actions"
            onClick={onClose}
          />
          <motion.div
            initial={{ y: "100%" }}
            animate={{ y: 0 }}
            exit={{ y: "100%" }}
            transition={{ type: "spring", damping: 26, stiffness: 260 }}
            className="absolute inset-x-0 bottom-0 max-h-[86vh] overflow-y-auto rounded-t-[2rem] border border-white/10 bg-zinc-950/95 p-4 shadow-2xl shadow-black"
          >
            <div className="mx-auto mb-4 h-1.5 w-12 rounded-full bg-white/20" />
            <div className="flex items-start justify-between gap-4">
              <div>
                <p className="text-xs font-bold uppercase tracking-[0.2em] text-amber-300">
                  Lead {lead.alias}
                </p>
                <h3 className="mt-1 text-xl font-black text-white">
                  Action Menu
                </h3>
                <p className="mt-1 text-sm font-semibold text-zinc-400">
                  Contact details are protected.
                </p>
              </div>
              <button
                onClick={onClose}
                type="button"
                className="flex h-11 w-11 items-center justify-center rounded-xl border border-white/10 bg-white/[0.04] text-zinc-200 active:scale-95"
                aria-label="Close action menu"
              >
                <X className="h-5 w-5" />
              </button>
            </div>
            <div className="mt-5 space-y-2 pb-3">
              {actions.map((action) => (
                <ActionRow key={action.title} action={action} />
              ))}
            </div>
          </motion.div>
        </motion.div>
      ) : null}
    </AnimatePresence>
  );
}

function DesktopActionPopover({
  lead,
  open,
  actions,
  onClose,
}: {
  lead: SafeLead;
  open: boolean;
  actions: ActionItem[];
  onClose: () => void;
}) {
  return (
    <AnimatePresence>
      {open ? (
        <motion.div
          initial={{ scale: 0.95, opacity: 0 }}
          animate={{ scale: 1, opacity: 1 }}
          exit={{ scale: 0.95, opacity: 0 }}
          transition={{ duration: 0.15, ease: "easeOut" }}
          className="absolute right-4 top-[calc(100%-1rem)] z-30 hidden w-80 rounded-2xl border border-white/10 bg-zinc-950/95 p-3 shadow-2xl shadow-black/40 backdrop-blur-xl md:block"
        >
          <div className="mb-2 flex items-center justify-between border-b border-white/5 pb-3">
            <div>
              <p className="text-xs font-black uppercase tracking-[0.18em] text-amber-300">
                Lead {lead.alias}
              </p>
              <p className="mt-1 text-xs font-semibold text-zinc-500">
                Contact details are protected.
              </p>
            </div>
            <button
              type="button"
              onClick={onClose}
              className="flex h-9 w-9 items-center justify-center rounded-xl border border-white/10 bg-white/[0.04] text-zinc-300"
              aria-label="Close action popover"
            >
              <X className="h-4 w-4" />
            </button>
          </div>
          <div className="space-y-1.5">
            {actions.map((action) => (
              <ActionRow key={action.title} action={action} compact />
            ))}
          </div>
        </motion.div>
      ) : null}
    </AnimatePresence>
  );
}

function ActionRow({
  action,
  compact,
}: {
  action: ActionItem;
  compact?: boolean;
}) {
  return (
    <motion.button
      whileTap={{ scale: 0.98 }}
      type="button"
      className={cn(
        "flex w-full items-center gap-3 rounded-2xl border border-white/5 bg-white/[0.03] p-3 text-left transition-colors hover:border-amber-300/20 hover:bg-white/[0.06]",
        compact ? "min-h-14" : "min-h-16",
      )}
    >
      <span
        className={cn(
          "flex h-11 w-11 shrink-0 items-center justify-center rounded-xl border",
          actionTone(action.tone),
        )}
      >
        {action.icon}
      </span>
      <span className="min-w-0 flex-1">
        <span className="block text-sm font-black text-white">{action.title}</span>
        <span className="mt-0.5 block text-xs font-medium text-zinc-500">
          {action.helper}
        </span>
      </span>
      <ChevronRight className="h-4 w-4 text-zinc-600" />
    </motion.button>
  );
}

function DataLoanStatusStrip({
  summary,
}: {
  summary: { active: number; expired: number; revoked: number };
}) {
  return (
    <MotionCard className="p-5" delay={0.1}>
      <SectionTitle
        icon={<KeyRound className="h-5 w-5" />}
        title="Data Loan / Call Access Status"
        helper="Caller ko access diya gaya hai"
        nested
      />
      <div className="mt-4 grid grid-cols-3 gap-2">
        <MiniMetric label="Active" value={summary.active} tone="green" />
        <MiniMetric label="Expired" value={summary.expired} tone="red" />
        <MiniMetric label="Revoked" value={summary.revoked} tone="red" />
      </div>
      <div className="mt-4 rounded-2xl border border-amber-300/15 bg-amber-400/[0.06] p-3">
        <p className="text-sm font-bold text-amber-200">
          Secure bridge only. Number screen par kabhi nahi dikhega.
        </p>
      </div>
    </MotionCard>
  );
}

function BrokerLockTimeline() {
  const timeline = [
    {
      title: "Interested lead verified",
      helper: "L-1042 ready for visit push",
      tone: "green",
    },
    {
      title: "Sunday visit scheduled",
      helper: "Visit proof pending",
      tone: "blue",
    },
    {
      title: "45-day lock pending",
      helper: "Aapka commission locked after visit approval",
      tone: "gold",
    },
  ];

  return (
    <MotionCard className="p-5" delay={0.14}>
      <SectionTitle
        icon={<ShieldCheck className="h-5 w-5" />}
        title="Site Visit & Broker Lock Timeline"
        helper="Credit protection status"
        nested
      />
      <div className="mt-5 space-y-4">
        {timeline.map((item, index) => (
          <div key={item.title} className="relative flex gap-3">
            <div className="flex flex-col items-center">
              <span className={cn("h-4 w-4 rounded-full border shadow-lg", toneClasses(item.tone))} />
              {index < timeline.length - 1 ? (
                <span className="mt-1 h-10 w-px bg-white/10" />
              ) : null}
            </div>
            <div className="-mt-1">
              <p className="text-sm font-black text-white">{item.title}</p>
              <p className="mt-0.5 text-xs font-medium text-zinc-500">
                {item.helper}
              </p>
            </div>
          </div>
        ))}
      </div>
    </MotionCard>
  );
}

function BrokerageBookingStatus() {
  return (
    <MotionCard className="p-5" delay={0.18}>
      <SectionTitle
        icon={<Landmark className="h-5 w-5" />}
        title="Brokerage / Booking Status"
        helper="Where your business stands"
        nested
      />
      <div className="mt-4 grid gap-3">
        <StatusLine label="Booking Discussions" value="5 open" tone="orange" />
        <StatusLine label="Brokerage Tracking" value="₹18.4L pipeline" tone="gold" />
        <StatusLine label="Eligible Credits" value="3 protected" tone="green" />
      </div>
    </MotionCard>
  );
}

function SuggestedNextActions() {
  const next = [
    "Confirm Sunday site visit for Lead L-1042",
    "Renew access for Lead L-1088",
    "Review low-quality lead L-1120",
  ];

  return (
    <MotionCard className="p-5" delay={0.22}>
      <SectionTitle
        icon={<Zap className="h-5 w-5" />}
        title="Suggested Next Actions"
        helper="What should I do now?"
        nested
      />
      <div className="mt-4 space-y-2">
        {next.map((item) => (
          <button
            key={item}
            type="button"
            className="flex min-h-12 w-full items-center justify-between gap-3 rounded-xl border border-white/5 bg-white/[0.03] px-3 py-2 text-left text-sm font-bold text-zinc-200 transition hover:border-amber-300/20 hover:bg-white/[0.06] active:scale-[0.99]"
          >
            <span>{item}</span>
            <ChevronRight className="h-4 w-4 shrink-0 text-zinc-500" />
          </button>
        ))}
      </div>
    </MotionCard>
  );
}

function SecureNoticeBanner() {
  return (
    <MotionCard className="border-green-500/10 bg-green-500/[0.06] p-4">
      <div className="flex gap-3">
        <div className="flex h-11 w-11 shrink-0 items-center justify-center rounded-2xl border border-green-500/20 bg-green-500/10">
          <LockKeyhole className="h-5 w-5 text-green-400" />
        </div>
        <div>
          <p className="text-sm font-black text-white">Your Credit: Protected</p>
          <p className="mt-1 text-sm font-medium leading-6 text-green-100/70">
            Buyer details stay inside the secure vault. Every action uses safe
            permission flow.
          </p>
        </div>
      </div>
    </MotionCard>
  );
}

function SafeEmptyState() {
  return (
    <div className="rounded-2xl border border-dashed border-white/10 bg-white/[0.03] p-6 text-center">
      <AlertTriangle className="mx-auto h-8 w-8 text-zinc-500" />
      <p className="mt-3 text-sm font-bold text-zinc-300">
        No safe lead aliases available.
      </p>
      <p className="mt-1 text-xs font-medium text-zinc-500">
        Add leads through the protected vault flow.
      </p>
    </div>
  );
}

function MiniMetric({
  label,
  value,
  tone,
}: {
  label: string;
  value: number;
  tone: string;
}) {
  return (
    <div className={cn("rounded-2xl border p-3 text-center", toneClasses(tone))}>
      <p className="text-2xl font-black text-white">{value}</p>
      <p className="mt-1 text-[11px] font-bold uppercase tracking-wide">{label}</p>
    </div>
  );
}

function StatusLine({
  label,
  value,
  tone,
}: {
  label: string;
  value: string;
  tone: string;
}) {
  return (
    <div className="flex items-center justify-between gap-3 rounded-xl border border-white/5 bg-black/20 p-3">
      <p className="text-sm font-bold text-zinc-300">{label}</p>
      <span className={cn("rounded-full border px-3 py-1 text-xs font-black", toneClasses(tone))}>
        {value}
      </span>
    </div>
  );
}

function SectionTitle({
  icon,
  title,
  helper,
  nested,
}: {
  icon: ReactNode;
  title: string;
  helper: string;
  nested?: boolean;
}) {
  return (
    <div className={cn("flex items-start gap-3", !nested && "mt-1")}>
      <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-2xl border border-amber-300/20 bg-amber-400/10 text-amber-300">
        {icon}
      </div>
      <div>
        <h2 className="text-base font-black tracking-tight text-white">{title}</h2>
        <p className="mt-0.5 text-sm font-medium text-zinc-500">{helper}</p>
      </div>
    </div>
  );
}
