'use client';

import React, { useState, useEffect } from 'react';
import { crmErpApi, type CrmLead, type LeadMetrics } from '@/lib/crm-erp-api';
import { SearchLeadOptimized, VisitedLeadsAnalytics } from './SearchLeadOptimized';

interface CrmErpDashboardState {
  leads: CrmLead[];
  loading: boolean;
  error: string | null;
  selectedLead: CrmLead | null;
  metrics: LeadMetrics | null;
}

/**
 * Complete Integrated CRM/ERP Dashboard
 * Combines lead management, search, tracking, and analytics
 */
export function IntegratedCrmErpDashboard() {
  const [state, setState] = useState<CrmErpDashboardState>({
    leads: [],
    loading: true,
    error: null,
    selectedLead: null,
    metrics: null,
  });

  // Load leads and metrics on mount
  useEffect(() => {
    loadDashboard();
    const interval = setInterval(() => {
      loadMetrics();
    }, 30000); // Refresh metrics every 30 seconds

    return () => clearInterval(interval);
  }, []);

  const loadDashboard = async () => {
    try {
      setState((prev) => ({ ...prev, loading: true }));
      const [leads, metrics] = await Promise.all([
        crmErpApi.searchLeads('', { limit: 1000 }),
        crmErpApi.getMetrics(),
      ]);

      setState((prev) => ({
        ...prev,
        leads,
        metrics,
        loading: false,
        error: null,
      }));
    } catch (error) {
      setState((prev) => ({
        ...prev,
        loading: false,
        error: error instanceof Error ? error.message : 'Failed to load dashboard',
      }));
    }
  };

  const loadMetrics = async () => {
    try {
      const metrics = await crmErpApi.getMetrics();
      setState((prev) => ({
        ...prev,
        metrics,
      }));
    } catch (error) {
      console.error('Metrics load error:', error);
    }
  };

  const handleLeadSelect = (lead: CrmLead) => {
    setState((prev) => ({ ...prev, selectedLead: lead }));
    void crmErpApi.trackVisitedLead(lead.id, 0, ['viewed']);
  };

  const handleLeadUpdate = async (leadId: string, updates: LeadUpdate) => {
    try {
      await fetch(`/api/crm-erp/leads/${leadId}`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(updates),
      });

      // Reload dashboard
      await loadDashboard();
    } catch (error) {
      console.error('Update error:', error);
    }
  };

  if (state.loading) {
    return (
      <div className="flex items-center justify-center h-screen">
        <div className="text-white">Loading CRM/ERP Dashboard...</div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-[#071013] text-white p-4">
      <div className="max-w-7xl mx-auto space-y-6">
        {/* Header */}
        <div className="flex items-center justify-between">
          <div>
            <h1 className="text-3xl font-bold">CRM/ERP Dashboard</h1>
            <p className="text-slate-400 mt-1">Unified lead management and analytics</p>
          </div>
          <button
            onClick={loadDashboard}
            className="px-4 py-2 bg-amber-400 text-slate-950 rounded-md font-semibold hover:bg-amber-300"
          >
            Refresh
          </button>
        </div>

        {/* Metrics Cards */}
        {state.metrics && (
          <div className="grid grid-cols-1 md:grid-cols-5 gap-4">
            <MetricCard label="Total Leads" value={state.metrics.totalLeads} />
            <MetricCard label="Hot Leads" value={state.metrics.hotLeads} tone="orange" />
            <MetricCard label="Visited" value={state.metrics.visitedLeads} tone="green" />
            <MetricCard label="Conversion" value={`${(state.metrics.conversionRate * 100).toFixed(0)}%`} tone="blue" />
            <MetricCard label="Avg Followups" value={state.metrics.averageFollowups.toFixed(1)} tone="purple" />
          </div>
        )}

        {/* Search and Lead Management */}
        <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
          <div className="lg:col-span-2">
            <SearchLeadOptimized leads={state.leads} onLeadSelect={handleLeadSelect} />
          </div>

          {/* Selected Lead Details */}
          {state.selectedLead && (
            <div className="rounded-lg border border-white/10 bg-white/[0.035] p-4">
              <h3 className="text-lg font-semibold text-white mb-4">{state.selectedLead.alias}</h3>
              <div className="space-y-3">
                <DetailField label="Project" value={state.selectedLead.project} />
                <DetailField label="Area" value={state.selectedLead.area} />
                <DetailField label="Quality" value={state.selectedLead.leadQuality} />
                <DetailField label="Call Status" value={state.selectedLead.callStatus} />
                <DetailField label="Visit Status" value={state.selectedLead.visitStatus} />
                <DetailField label="Views" value={state.selectedLead.viewCount?.toString() || '0'} />

                <button
                  onClick={() =>
                    handleLeadUpdate(state.selectedLead!.id, {
                      status: 'Interested',
                    })
                  }
                  className="w-full mt-4 px-3 py-2 bg-amber-400 text-slate-950 rounded-md font-semibold hover:bg-amber-300"
                >
                  Mark as Interested
                </button>
              </div>
            </div>
          )}
        </div>

        {/* Visited Leads Analytics */}
        <VisitedLeadsAnalytics leads={state.leads} />

        {/* Error Handling */}
        {state.error && (
          <div className="rounded-lg border border-red-300/20 bg-red-300/10 p-4 text-red-100">
            {state.error}
          </div>
        )}
      </div>
    </div>
  );
}

function MetricCard({ label, value, tone = 'slate' }: { label: string; value: string | number; tone?: string }) {
  const colors = {
    slate: 'border-white/10 bg-white/[0.035]',
    orange: 'border-orange-300/20 bg-orange-300/10',
    green: 'border-emerald-300/20 bg-emerald-300/10',
    blue: 'border-sky-300/20 bg-sky-300/10',
    purple: 'border-violet-300/20 bg-violet-300/10',
  };

  return (
    <div className={`rounded-lg border p-4 ${colors[tone as keyof typeof colors] || colors.slate}`}>
      <p className="text-sm text-slate-400">{label}</p>
      <p className="text-2xl font-bold text-white mt-1">{value}</p>
    </div>
  );
}

function DetailField({ label, value }: { label: string; value: string }) {
  return (
    <div>
      <p className="text-xs text-slate-500">{label}</p>
      <p className="text-sm text-white mt-1">{value}</p>
    </div>
  );
}

interface LeadUpdate {
  status?: string;
  quality?: string;
  assignedTo?: string;
  notes?: string;
}
