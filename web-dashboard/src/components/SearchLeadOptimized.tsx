'use client';

import React, { useState, useCallback, useMemo, useRef, useEffect } from 'react';
import { 
  Search, 
  TrendingUp, 
  Eye, 
  Clock, 
  CheckCircle2,
  Flame,
  Sparkles,
  Moon,
  LayoutGrid,
  List,
  Table
} from 'lucide-react';
import type { CrmLead } from '@/lib/crm-erp-api';

type Lead = CrmLead;

/**
 * Premium Urgency Heatmap Ribbon
 * Displays a bird's-eye view of all leads as an interactive color-coded strip.
 */
function UrgencyHeatmapRibbon({
  leads,
  onLeadSelect,
  selectedLeadId,
}: {
  leads: Lead[];
  onLeadSelect: (lead: Lead) => void;
  selectedLeadId?: string;
}) {
  if (leads.length === 0) return null;

  return (
    <div className="mb-4 rounded-lg border border-white/5 bg-black/40 p-3">
      <div className="flex items-center justify-between mb-2">
        <span className="text-xs font-semibold uppercase tracking-[0.16em] text-slate-400 flex items-center gap-1.5">
          <span className="h-1.5 w-1.5 rounded-full bg-amber-400 animate-pulse" />
          Interactive Urgency Heatmap
        </span>
        <span className="text-[10px] text-slate-500">
          Click block to select · {leads.length} leads loaded
        </span>
      </div>
      <div className="flex flex-wrap gap-1 max-h-12 overflow-y-auto pr-1 custom-scrollbar">
        {leads.map((lead) => {
          const isSelected = lead.id === selectedLeadId;
          const isVisited = (lead.viewCount ?? 0) > 0;
          
          // Determine color based on quality and visited status
          let blockColor = 'bg-slate-600 border-slate-700 hover:bg-slate-500';
          let borderGlow = '';
          if (lead.leadQuality === 'Hot') {
            blockColor = isVisited 
              ? 'bg-rose-500 border-rose-600 hover:bg-rose-400 text-rose-100' 
              : 'bg-rose-600 border-rose-700 hover:bg-rose-500 text-rose-200';
          } else if (lead.leadQuality === 'Warm') {
            blockColor = isVisited 
              ? 'bg-amber-400 border-amber-500 hover:bg-amber-300 text-amber-950' 
              : 'bg-amber-500 border-amber-600 hover:bg-amber-400 text-amber-900';
          } else if (isVisited) {
            blockColor = 'bg-emerald-500 border-emerald-600 hover:bg-emerald-400 text-emerald-100';
          }

          if (isSelected) {
            borderGlow = 'ring-2 ring-white scale-110 z-10';
          }

          return (
            <div
              key={lead.id}
              onClick={() => onLeadSelect(lead)}
              className={`group relative h-3.5 w-3.5 cursor-pointer rounded-sm border transition duration-150 ease-out active:scale-95 ${blockColor} ${borderGlow}`}
              title={`${lead.alias} (${lead.leadQuality})`}
            >
              {/* Premium Hover Tooltip */}
              <div className="pointer-events-none absolute bottom-full left-1/2 -translate-x-1/2 mb-2 hidden w-44 rounded-md border border-white/10 bg-slate-950/95 p-2 shadow-2xl backdrop-blur-md group-hover:block z-50 animate-in fade-in slide-in-from-bottom-1 duration-150">
                <div className="text-[11px] font-bold text-white mb-0.5">{lead.alias}</div>
                <div className="text-[10px] text-slate-400 truncate">{lead.project} · {lead.area}</div>
                <div className="mt-1 flex items-center justify-between border-t border-white/5 pt-1 text-[9px]">
                  <span className={`px-1 rounded-sm font-semibold uppercase ${
                    lead.leadQuality === 'Hot' ? 'bg-rose-500/20 text-rose-300' :
                    lead.leadQuality === 'Warm' ? 'bg-amber-500/20 text-amber-300' :
                    'bg-slate-500/20 text-slate-300'
                  }`}>
                    {lead.leadQuality}
                  </span>
                  <span className="text-slate-500 flex items-center gap-0.5">
                    <Eye size={9} /> {lead.viewCount ?? 0} views
                  </span>
                </div>
                <div className="absolute top-full left-1/2 -translate-x-1/2 border-4 border-transparent border-t-slate-950/95" />
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
}

/**
 * Optimized Lead Search Component with Virtual Scrolling support and interactive heatmap
 */
export function SearchLeadOptimized({
  leads,
  onLeadSelect,
}: {
  leads: Lead[];
  onLeadSelect: (lead: Lead) => void;
}) {
  const [search, setSearch] = useState('');
  const [filter, setFilter] = useState<'All' | 'Visited' | 'Not Visited'>('All');
  const [priorityTab, setPriorityTab] = useState<'all' | 'due' | 'active' | 'dormant'>('all');
  const [density, setDensity] = useState<'comfortable' | 'compact' | 'micro'>('comfortable');
  const [selectedLeadId, setSelectedLeadId] = useState<string | undefined>(undefined);
  const [visibleCount, setVisibleCount] = useState(12);

  const ITEMS_PER_PAGE = 12;

  // Combined search and priority logic
  const filteredLeads = useMemo(() => {
    return leads.filter((lead) => {
      // 1. Text Search Filter
      const matchesSearch =
        lead.alias.toLowerCase().includes(search.toLowerCase()) ||
        lead.project.toLowerCase().includes(search.toLowerCase()) ||
        lead.area.toLowerCase().includes(search.toLowerCase());

      if (!matchesSearch) return false;

      // 2. Visited vs Not Visited Filter Button
      if (filter === 'Visited' && (lead.viewCount ?? 0) === 0) return false;
      if (filter === 'Not Visited' && (lead.viewCount ?? 0) > 0) return false;

      // 3. Priority Action Tab Filter
      const isVisited = (lead.viewCount ?? 0) > 0;
      if (priorityTab === 'due') {
        // High Urgency: Hot or Warm leads that haven't been visited yet
        return lead.leadQuality === 'Hot' || (lead.leadQuality === 'Warm' && !isVisited);
      }
      if (priorityTab === 'active') {
        // Active Engagement: Has views or active visit
        return isVisited || lead.visitStatus === 'Visited';
      }
      if (priorityTab === 'dormant') {
        // Low Touch: Cold leads
        return lead.leadQuality === 'Cold';
      }

      return true;
    });
  }, [leads, search, filter, priorityTab]);

  const displayedLeads = filteredLeads.slice(0, visibleCount);

  const handleLoadMore = useCallback(() => {
    setVisibleCount((prev) => prev + ITEMS_PER_PAGE);
  }, []);

  const handleLeadClick = useCallback(
    (lead: Lead) => {
      setSelectedLeadId(lead.id);
      onLeadSelect(lead);
      // Track visit
      trackLeadVisit(lead.id);
    },
    [onLeadSelect],
  );

  return (
    <div className="rounded-lg border border-white/10 bg-white/[0.035] p-4 transition-all duration-300">
      
      {/* Interactive Urgency Heatmap Ribbon */}
      <UrgencyHeatmapRibbon 
        leads={filteredLeads}
        onLeadSelect={handleLeadClick}
        selectedLeadId={selectedLeadId}
      />

      {/* Main Search and Basic Filters Row */}
      <div className="mb-4 flex flex-col gap-3 sm:flex-row sm:items-center sm:gap-3">
        <div className="relative flex-1">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-500" size={18} />
          <input
            type="text"
            placeholder="Search leads..."
            value={search}
            onChange={(e) => {
              setSearch(e.target.value);
              setVisibleCount(ITEMS_PER_PAGE);
            }}
            className="w-full h-10 rounded-md border border-white/10 bg-black/30 pl-10 pr-3 text-sm text-white outline-none placeholder:text-slate-600 focus:border-amber-300 transition"
          />
        </div>

        <div className="flex gap-2">
          {(['All', 'Visited', 'Not Visited'] as const).map((f) => (
            <button
              key={f}
              onClick={() => {
                setFilter(f);
                setVisibleCount(ITEMS_PER_PAGE);
              }}
              className={`h-10 rounded-md px-3 text-sm font-medium transition ${
                filter === f
                  ? 'bg-amber-400 text-slate-950'
                  : 'border border-white/10 bg-white/[0.035] text-slate-300 hover:bg-white/[0.07]'
              }`}
            >
              {f}
            </button>
          ))}
        </div>
      </div>

      {/* Sub-Toolbar: Priority Triage & Density Switcher */}
      <div className="mb-4 flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between border-t border-white/5 pt-3">
        
        {/* Urgency Triage Tabs */}
        <div className="flex flex-wrap gap-1 bg-black/20 p-1 rounded-lg border border-white/5">
          {(['all', 'due', 'active', 'dormant'] as const).map((tab) => {
            let label: React.ReactNode = 'All Leads';
            if (tab === 'due') {
              label = (
                <span className="flex items-center gap-1">
                  <Flame size={12} className="text-rose-400" />
                  Actions Due
                </span>
              );
            } else if (tab === 'active') {
              label = (
                <span className="flex items-center gap-1">
                  <Sparkles size={12} className="text-amber-400" />
                  Active
                </span>
              );
            } else if (tab === 'dormant') {
              label = (
                <span className="flex items-center gap-1">
                  <Moon size={12} className="text-slate-400" />
                  Dormant
                </span>
              );
            }

            return (
              <button
                key={tab}
                type="button"
                onClick={() => {
                  setPriorityTab(tab);
                  setVisibleCount(ITEMS_PER_PAGE);
                }}
                className={`px-3 py-1 text-xs font-semibold rounded-md transition duration-150 ${
                  priorityTab === tab
                    ? 'bg-white/10 text-white border border-white/5'
                    : 'text-slate-400 hover:text-white border border-transparent'
                }`}
              >
                {label}
              </button>
            );
          })}
        </div>

        {/* View Density Mode Controls */}
        <div className="flex items-center gap-2">
          <span className="text-[10px] text-slate-500 uppercase tracking-wider font-semibold">Density</span>
          <div className="flex gap-1 bg-black/20 p-1 rounded-lg border border-white/5">
            <button
              onClick={() => setDensity('comfortable')}
              className={`p-1.5 rounded transition ${
                density === 'comfortable' ? 'bg-amber-400 text-slate-950' : 'text-slate-400 hover:text-white'
              }`}
              title="Comfortable Grid View"
            >
              <LayoutGrid size={14} />
            </button>
            <button
              onClick={() => setDensity('compact')}
              className={`p-1.5 rounded transition ${
                density === 'compact' ? 'bg-amber-400 text-slate-950' : 'text-slate-400 hover:text-white'
              }`}
              title="Compact Horizontal View"
            >
              <List size={14} />
            </button>
            <button
              onClick={() => setDensity('micro')}
              className={`p-1.5 rounded transition ${
                density === 'micro' ? 'bg-amber-400 text-slate-950' : 'text-slate-400 hover:text-white'
              }`}
              title="Micro Spreadsheet View (Zero Scroll)"
            >
              <Table size={14} />
            </button>
          </div>
        </div>
      </div>

      {/* Main Lists with Dynamic Layouts */}
      {filteredLeads.length === 0 ? (
        <div className="py-8 text-center text-slate-500 text-sm">No leads match your search criteria.</div>
      ) : (
        <>
          {/* Density 1: Comfortable Cards */}
          {density === 'comfortable' && (
            <div className="grid gap-3 lg:grid-cols-2">
              {displayedLeads.map((lead) => (
                <LeadCardOptimized
                  key={lead.id}
                  lead={lead}
                  selected={lead.id === selectedLeadId}
                  onSelect={() => handleLeadClick(lead)}
                />
              ))}
            </div>
          )}

          {/* Density 2: Compact Rows */}
          {density === 'compact' && (
            <div className="grid gap-2">
              {displayedLeads.map((lead) => (
                <LeadRowCompact
                  key={lead.id}
                  lead={lead}
                  selected={lead.id === selectedLeadId}
                  onSelect={() => handleLeadClick(lead)}
                />
              ))}
            </div>
          )}

          {/* Density 3: Micro Table Spreadsheet */}
          {density === 'micro' && (
            <div className="overflow-x-auto rounded-lg border border-white/5 bg-black/20">
              <table className="w-full border-collapse text-left text-xs">
                <thead>
                  <tr className="border-b border-white/5 bg-white/[0.02] text-slate-400 font-semibold uppercase tracking-wider">
                    <th className="p-2.5">Alias</th>
                    <th className="p-2.5">Project / Area</th>
                    <th className="p-2.5">Quality</th>
                    <th className="p-2.5">Call Status</th>
                    <th className="p-2.5">Visit Status</th>
                    <th className="p-2.5 text-center">Views</th>
                    <th className="p-2.5 text-right">Actions</th>
                  </tr>
                </thead>
                <tbody>
                  {displayedLeads.map((lead) => (
                    <LeadRowMicroTable
                      key={lead.id}
                      lead={lead}
                      selected={lead.id === selectedLeadId}
                      onSelect={() => handleLeadClick(lead)}
                    />
                  ))}
                </tbody>
              </table>
            </div>
          )}

          {/* Pagination Load More Button */}
          {filteredLeads.length > displayedLeads.length && (
            <button
              onClick={handleLoadMore}
              className="mt-4 h-10 w-full rounded-md border border-white/10 bg-white/[0.035] text-sm font-semibold text-slate-100 transition hover:bg-white/[0.07]"
            >
              Load {Math.min(ITEMS_PER_PAGE, filteredLeads.length - displayedLeads.length)} more
            </button>
          )}
        </>
      )}
    </div>
  );
}

/**
 * Optimized Lead Card with Visit Tracking & Selected Glow
 */
function LeadCardOptimized({ 
  lead, 
  selected, 
  onSelect 
}: { 
  lead: Lead; 
  selected: boolean; 
  onSelect: () => void; 
}) {
  const cardRef = useRef<HTMLButtonElement>(null);
  const [isInView, setIsInView] = useState(false);

  useEffect(() => {
    const observer = new IntersectionObserver(
      ([entry]) => {
        setIsInView(entry.isIntersecting);
      },
      { threshold: 0.1 },
    );

    if (cardRef.current) {
      observer.observe(cardRef.current);
    }

    return () => observer.disconnect();
  }, []);

  return (
    <button
      ref={cardRef}
      onClick={onSelect}
      className={`rounded-lg border p-4 text-left transition duration-150 focus:outline-none focus:ring-2 focus:ring-amber-200 w-full ${
        selected
          ? 'border-amber-300/60 bg-amber-300/10'
          : 'border-white/10 bg-white/[0.035] hover:border-amber-300/40 hover:bg-white/[0.055]'
      }`}
    >
      <div className="flex items-start justify-between gap-2">
        <div>
          <h3 className="text-lg font-semibold text-white">{lead.alias}</h3>
          <p className="mt-1 text-sm text-slate-400 truncate">{lead.project} · {lead.area}</p>
        </div>
        <span className={`inline-flex items-center rounded-full px-2 py-1 text-xs font-semibold ${
          lead.leadQuality === 'Hot'
            ? 'border-orange-300/20 bg-orange-300/10 text-orange-200'
            : lead.leadQuality === 'Warm'
              ? 'border-amber-300/20 bg-amber-300/10 text-amber-200'
              : 'border-slate-300/15 bg-slate-300/10 text-slate-200'
        }`}>
          {lead.leadQuality}
        </span>
      </div>

      <div className="mt-3 grid grid-cols-3 gap-2 text-center text-xs text-slate-500">
        <div className="rounded-md bg-black/20 p-2">
          <p>Views</p>
          <p className="mt-1 font-semibold text-white">{lead.viewCount ?? 0}</p>
        </div>
        <div className="rounded-md bg-black/20 p-2">
          <p>Duration</p>
          <p className="mt-1 font-semibold text-white truncate">
            {lead.visitDuration ? `${Math.round(lead.visitDuration / 60000)}m` : '—'}
          </p>
        </div>
        <div className="rounded-md bg-black/20 p-2">
          <p>Status</p>
          <p className="mt-1 font-semibold text-white truncate">{lead.callStatus.slice(0, 8)}</p>
        </div>
      </div>

      {isInView && <div className="mt-3 h-1 w-full bg-gradient-to-r from-amber-300 to-transparent rounded-full animate-pulse" />}
    </button>
  );
}

/**
 * Compact View Card for Lead rows (takes 50% less space)
 */
function LeadRowCompact({
  lead,
  selected,
  onSelect,
}: {
  lead: Lead;
  selected: boolean;
  onSelect: () => void;
}) {
  return (
    <button
      onClick={onSelect}
      className={`flex items-center justify-between rounded-lg border p-3 text-left transition duration-150 focus:outline-none focus:ring-2 focus:ring-amber-200 w-full ${
        selected
          ? 'border-amber-300/60 bg-amber-300/10 shadow-lg'
          : 'border-white/5 bg-white/[0.025] hover:border-white/10 hover:bg-white/[0.045]'
      }`}
    >
      <div className="flex items-center gap-3 min-w-0">
        <span className={`flex h-2.5 w-2.5 rounded-full ${
          lead.leadQuality === 'Hot' ? 'bg-rose-400 animate-pulse' :
          lead.leadQuality === 'Warm' ? 'bg-amber-400' :
          'bg-slate-400'
        }`} />
        <div className="min-w-0">
          <h4 className="font-semibold text-sm text-white truncate">{lead.alias}</h4>
          <p className="text-xs text-slate-400 truncate">{lead.project} · {lead.area}</p>
        </div>
      </div>

      <div className="flex items-center gap-4">
        <span className="hidden sm:inline-flex items-center gap-1 text-[11px] text-slate-500">
          <Eye size={12} /> {lead.viewCount ?? 0}
        </span>
        <span className={`text-[10px] font-semibold px-2 py-0.5 rounded-md ${
          lead.callStatus.toLowerCase().includes('interested') 
            ? 'bg-emerald-500/10 text-emerald-300 border border-emerald-500/20' 
            : 'bg-white/5 text-slate-300 border border-white/5'
        }`}>
          {lead.callStatus.slice(0, 10)}
        </span>
        <span className={`inline-flex items-center rounded px-1.5 py-0.5 text-[10px] font-bold uppercase tracking-wider ${
          lead.leadQuality === 'Hot' ? 'bg-rose-500/10 text-rose-300 border border-rose-500/20' :
          lead.leadQuality === 'Warm' ? 'bg-amber-500/10 text-amber-300 border border-amber-300/20' :
          'bg-slate-500/10 text-slate-400 border border-slate-500/10'
        }`}>
          {lead.leadQuality}
        </span>
      </div>
    </button>
  );
}

/**
 * Micro Table Spreadsheet row (takes ~36px height, zero-scroll friendly)
 */
function LeadRowMicroTable({
  lead,
  selected,
  onSelect,
}: {
  lead: Lead;
  selected: boolean;
  onSelect: () => void;
}) {
  return (
    <tr
      onClick={onSelect}
      className={`border-b border-white/5 cursor-pointer text-slate-200 transition-colors duration-100 ${
        selected
          ? 'bg-amber-400/10 text-amber-200 border-l-2 border-l-amber-400'
          : 'hover:bg-white/[0.035]'
      }`}
    >
      <td className="p-2 font-mono font-semibold text-white">{lead.alias}</td>
      <td className="p-2 max-w-[200px] truncate text-slate-400">
        {lead.project} <span className="text-slate-600">·</span> {lead.area}
      </td>
      <td className="p-2">
        <span className={`text-[11px] font-semibold ${
          lead.leadQuality === 'Hot' ? 'text-rose-400 font-bold' :
          lead.leadQuality === 'Warm' ? 'text-amber-400' :
          'text-slate-400'
        }`}>
          ● {lead.leadQuality}
        </span>
      </td>
      <td className="p-2 font-medium truncate max-w-[120px]">{lead.callStatus}</td>
      <td className="p-2 font-medium text-slate-400">{lead.visitStatus}</td>
      <td className="p-2 text-center font-semibold text-slate-300">{lead.viewCount ?? 0}</td>
      <td className="p-2 text-right">
        <button
          onClick={(e) => {
            e.stopPropagation();
            onSelect();
          }}
          className="rounded bg-white/[0.05] hover:bg-white/[0.12] px-2.5 py-0.5 text-[10px] font-semibold text-white transition active:scale-95"
        >
          Select
        </button>
      </td>
    </tr>
  );
}

/**
 * Visited Leads Analytics Dashboard
 */
export function VisitedLeadsAnalytics({ leads }: { leads: Lead[] }) {
  const analytics = useMemo<VisitedAnalytics>(() => {
    const visited = leads.filter((lead) => (lead.viewCount ?? 0) > 0);
    const totalDuration = visited.reduce((sum, lead) => sum + (lead.visitDuration ?? 0), 0);
    const avgDuration = visited.length > 0 ? totalDuration / visited.length : 0;

    // Sort by view count
    const mostViewed = [...leads].sort((a, b) => (b.viewCount ?? 0) - (a.viewCount ?? 0)).slice(0, 5);

    // Recently viewed
    const recentlyViewed = [...leads]
      .sort((a, b) => {
        const dateA = new Date(a.lastInteraction ?? '1970-01-01').getTime();
        const dateB = new Date(b.lastInteraction ?? '1970-01-01').getTime();
        return dateB - dateA;
      })
      .slice(0, 5);

    return {
      totalVisited: visited.length,
      averageDuration: avgDuration,
      conversionRate: leads.length > 0 ? visited.length / leads.length : 0,
      mostViewedLeads: mostViewed,
      recentlyViewed,
    };
  }, [leads]);

  return (
    <div className="grid gap-4 lg:grid-cols-3">
      <div className="rounded-lg border border-emerald-300/20 bg-emerald-300/10 p-4">
        <div className="flex items-center gap-2">
          <Eye className="text-emerald-300" size={18} />
          <p className="text-sm font-semibold text-emerald-100">Leads Visited</p>
        </div>
        <p className="mt-2 text-2xl font-semibold text-white">{analytics.totalVisited}</p>
        <p className="mt-1 text-xs text-emerald-50/75">{(analytics.conversionRate * 100).toFixed(1)}% conversion</p>
      </div>

      <div className="rounded-lg border border-sky-300/20 bg-sky-300/10 p-4">
        <div className="flex items-center gap-2">
          <Clock className="text-sky-300" size={18} />
          <p className="text-sm font-semibold text-sky-100">Avg. Duration</p>
        </div>
        <p className="mt-2 text-2xl font-semibold text-white">
          {Math.round(analytics.averageDuration / 60000)}m
        </p>
        <p className="mt-1 text-xs text-sky-50/75">per lead interaction</p>
      </div>

      <div className="rounded-lg border border-violet-300/20 bg-violet-300/10 p-4">
        <div className="flex items-center gap-2">
          <TrendingUp className="text-violet-300" size={18} />
          <p className="text-sm font-semibold text-violet-100">Engagement</p>
        </div>
        <p className="mt-2 text-2xl font-semibold text-white">
          {(analytics.conversionRate * 100).toFixed(0)}%
        </p>
        <p className="mt-1 text-xs text-violet-50/75">viewed vs total</p>
      </div>

      <div className="rounded-lg border border-white/10 bg-white/[0.035] p-4 lg:col-span-2">
        <p className="text-sm font-semibold text-white">Most Viewed</p>
        <div className="mt-3 space-y-2">
          {analytics.mostViewedLeads.map((lead) => (
            <div key={lead.id} className="flex items-center justify-between rounded-md bg-black/20 p-2">
              <p className="text-sm text-white">{lead.alias}</p>
              <span className="text-xs font-semibold text-amber-300">{lead.viewCount ?? 0} views</span>
            </div>
          ))}
        </div>
      </div>

      <div className="rounded-lg border border-white/10 bg-white/[0.035] p-4">
        <p className="text-sm font-semibold text-white">Recently Viewed</p>
        <div className="mt-3 space-y-2">
          {analytics.recentlyViewed.map((lead) => (
            <div key={lead.id} className="flex items-center gap-2 rounded-md bg-black/20 p-2">
              <CheckCircle2 size={14} className="text-emerald-300" />
              <p className="text-xs text-slate-300">{lead.alias}</p>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}

/**
 * Track Lead Visit Helper Function
 */
function trackLeadVisit(leadId: string): void {
  if (typeof window === 'undefined') return;

  // Save to localStorage for batch sync
  const visits = JSON.parse(localStorage.getItem('lead:visits') || '{}');
  if (!visits[leadId]) {
    visits[leadId] = {
      firstVisited: new Date().toISOString(),
      viewCount: 0,
      totalDuration: 0,
      actions: [],
    };
  }

  visits[leadId].lastVisited = new Date().toISOString();
  visits[leadId].viewCount += 1;
  localStorage.setItem('lead:visits', JSON.stringify(visits));

  // Send to backend asynchronously
  fetch('/api/crm-erp/leads/visit-tracking', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      leadId,
      duration: 0,
      actions: ['viewed'],
    }),
  }).catch(() => {
    // Offline - will retry on next sync
  });
}

interface VisitedAnalytics {
  totalVisited: number;
  averageDuration: number;
  conversionRate: number;
  mostViewedLeads: Lead[];
  recentlyViewed: Lead[];
}
