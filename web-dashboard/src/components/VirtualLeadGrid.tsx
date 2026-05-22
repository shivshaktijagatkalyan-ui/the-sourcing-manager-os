'use client';

import React, { useCallback, useRef, useMemo } from 'react';
import { ChevronDown, ChevronUp } from 'lucide-react';

interface BrokerLead {
  id: string;
  alias: string;
  project: string;
  area: string;
  city: string;
  budget: string;
  buyerType: 'End User' | 'Investor' | 'Family Decision';
  assignedTo: string;
  assignedRole: 'Caller' | 'Sourcing Manager' | 'Unassigned';
  dataLoan: string;
  loanExpiresAt?: string;
  callStatus: string;
  visitStatus: string;
  brokerLock: string;
  bookingStage: string;
  brokerageStatus: string;
  leadQuality: string;
  dataQuality: string;
  followupAt?: string;
  callsAttempted: number;
  nextAction: string;
  lastUpdated: string;
}

interface VirtualLeadGridProps {
  leads: BrokerLead[];
  selectedLeadId: string;
  expandedLeadIds: Set<string>;
  onSelect: (leadId: string) => void;
  onToggleExpand: (leadId: string) => void;
  onAction?: (action: string, lead: BrokerLead) => void;
}

const ITEM_HEIGHT_COLLAPSED = 290;
const ITEM_HEIGHT_EXPANDED = 480;
const VISIBLE_ITEMS = 12;

export function VirtualLeadGrid({
  leads,
  selectedLeadId,
  expandedLeadIds,
  onSelect,
  onToggleExpand,
}: VirtualLeadGridProps) {
  const scrollRef = useRef<HTMLDivElement>(null);
  const [scrollTop, setScrollTop] = React.useState(0);

  const containerHeight = VISIBLE_ITEMS * ITEM_HEIGHT_COLLAPSED;

  const getItemHeight = useCallback(
    (leadId: string) => {
      return expandedLeadIds.has(leadId) ? ITEM_HEIGHT_EXPANDED : ITEM_HEIGHT_COLLAPSED;
    },
    [expandedLeadIds]
  );

  const visibleRange = useMemo(() => {
    let accumHeight = 0;
    let startIdx = 0;
    let endIdx = 0;
    let foundStart = false;

    for (let i = 0; i < leads.length; i++) {
      const itemHeight = getItemHeight(leads[i].id);

      if (accumHeight + itemHeight > scrollTop && !foundStart) {
        startIdx = Math.max(0, i - 1);
        foundStart = true;
      }

      if (accumHeight > scrollTop + containerHeight) {
        endIdx = i;
        break;
      }

      accumHeight += itemHeight;
      endIdx = i;
    }

    return { startIdx, endIdx };
  }, [leads, scrollTop, containerHeight, getItemHeight]);

  const handleScroll = (e: React.UIEvent<HTMLDivElement>) => {
    setScrollTop((e.target as HTMLDivElement).scrollTop);
  };

  const totalHeight = useMemo(() => {
    return leads.reduce((sum, lead) => sum + getItemHeight(lead.id), 0);
  }, [leads, getItemHeight]);

  const offsetY = useMemo(() => {
    let offset = 0;
    for (let i = 0; i < visibleRange.startIdx; i++) {
      offset += getItemHeight(leads[i].id);
    }
    return offset;
  }, [leads, visibleRange.startIdx, getItemHeight]);

  const visibleLeads = leads.slice(visibleRange.startIdx, visibleRange.endIdx + 1);

  return (
    <div
      ref={scrollRef}
      onScroll={handleScroll}
      className="overflow-y-auto"
      style={{ height: `${containerHeight}px` }}
    >
      <div style={{ height: `${totalHeight}px`, position: 'relative' }}>
        <div style={{ transform: `translateY(${offsetY}px)` }}>
          <div className="grid gap-3 lg:grid-cols-2">
            {visibleLeads.map((lead) => (
              <LeadCardVirtual
                key={lead.id}
                lead={lead}
                selected={lead.id === selectedLeadId}
                expanded={expandedLeadIds.has(lead.id)}
                onSelect={() => onSelect(lead.id)}
                onToggleExpand={() => onToggleExpand(lead.id)}
              />
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}

function LeadCardVirtual({
  lead,
  selected,
  expanded,
  onSelect,
  onToggleExpand,
}: {
  lead: BrokerLead;
  selected: boolean;
  expanded: boolean;
  onSelect: () => void;
  onToggleExpand: () => void;
}) {
  return (
    <article
      data-testid={`lead-card-${lead.alias}`}
      onClick={onSelect}
      role="button"
      tabIndex={0}
      onKeyDown={(event) => {
        if (event.key === 'Enter' || event.key === ' ') {
          event.preventDefault();
          onSelect();
        }
      }}
      className={`min-h-[${expanded ? '480px' : '290px'}] rounded-lg border p-4 text-left transition focus:outline-none focus:ring-2 focus:ring-amber-200 cursor-pointer ${
        selected
          ? 'border-amber-300/60 bg-amber-300/10'
          : 'border-white/10 bg-white/[0.035] hover:border-white/20 hover:bg-white/[0.055]'
      }`}
    >
      <div className="flex items-start justify-between gap-3">
        <div className="flex-1">
          <h3 className="text-lg font-semibold text-white">{lead.alias}</h3>
          <p className="mt-1 text-sm text-slate-400">{lead.project} · {lead.area}</p>
        </div>
      </div>

      <div className="mt-4 flex flex-wrap gap-2">
        <StatusBadge label={lead.leadQuality} />
        <StatusBadge label={lead.dataLoan} />
        <StatusBadge label={lead.callStatus} />
      </div>

      <div className="mt-4 rounded-md border border-white/10 bg-black/20 p-3">
        <p className="text-xs font-semibold uppercase tracking-[0.16em] text-slate-500">Next action</p>
        <p className="mt-1 text-sm text-amber-100 line-clamp-2">{lead.nextAction}</p>
      </div>

      {expanded && (
        <div className="mt-4 grid grid-cols-2 gap-2 animate-in fade-in duration-200">
          <Field label="Budget" value={lead.budget} />
          <Field label="Buyer" value={lead.buyerType} />
          <Field label="Assigned" value={lead.assignedTo} />
          <Field label="Calls" value={lead.callsAttempted} />
          <Field label="Visit" value={lead.visitStatus} />
          <Field label="Lock" value={lead.brokerLock} />
          <Field label="Booking" value={lead.bookingStage} />
          <Field label="Brokerage" value={lead.brokerageStatus} />
        </div>
      )}

      <button
        type="button"
        onClick={(event) => {
          event.stopPropagation();
          onToggleExpand();
        }}
        className="mt-4 inline-flex h-9 items-center gap-2 rounded-md border border-white/10 bg-white/[0.035] px-3 text-sm font-semibold text-slate-100 transition hover:bg-white/[0.07]"
      >
        {expanded ? <ChevronUp size={15} /> : <ChevronDown size={15} />}
        {expanded ? 'Hide details' : 'View details'}
      </button>
    </article>
  );
}

function StatusBadge({ label }: { label: string }) {
  const colors = getStatusColor(label);
  return (
    <span className={`inline-flex items-center rounded-full border px-2 py-1 text-xs font-semibold ${colors}`}>
      {label}
    </span>
  );
}

function Field({ label, value }: { label: string; value: React.ReactNode }) {
  return (
    <div className="min-w-0 rounded-md bg-black/20 p-2">
      <p className="text-xs text-slate-500">{label}</p>
      <p className="mt-1 truncate text-sm font-medium text-slate-100">{value}</p>
    </div>
  );
}

function getStatusColor(label: string): string {
  const normalized = label.toLowerCase();
  if (['active', 'verified', 'eligible', 'hot', 'strong'].includes(normalized)) {
    return 'border-emerald-300/20 bg-emerald-300/10 text-emerald-100';
  }
  if (['pending', 'warm', 'medium', 'tracking'].includes(normalized)) {
    return 'border-amber-300/20 bg-amber-300/10 text-amber-100';
  }
  if (['expired', 'revoked', 'cold', 'weak'].includes(normalized)) {
    return 'border-red-300/20 bg-red-300/10 text-red-100';
  }
  return 'border-slate-300/15 bg-slate-300/10 text-slate-200';
}
