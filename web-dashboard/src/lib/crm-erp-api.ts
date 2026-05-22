/**
 * CRM/ERP Dashboard Backend Connector
 * Handles all API communication, caching, and data synchronization
 */

import { createClient } from '@supabase/supabase-js';

interface ApiResponse<T> {
  success: boolean;
  data?: T;
  error?: string;
  timestamp: number;
}

interface CacheEntry<T> {
  data: T;
  timestamp: number;
  ttl: number;
}

export interface LeadMetrics {
  totalLeads: number;
  hotLeads: number;
  visitedLeads: number;
  conversionRate: number;
  averageFollowups: number;
  lostLeads: number;
}

export type LeadQuality = 'Hot' | 'Warm' | 'Cold';

export interface CrmLead {
  id: string;
  alias: string;
  project: string;
  area: string;
  leadQuality: LeadQuality;
  callStatus: string;
  visitStatus: string;
  viewCount?: number;
  visitDuration?: number;
  lastInteraction?: string;
}

interface RawLeadRow {
  id?: unknown;
  alias?: unknown;
  project?: unknown;
  area?: unknown;
  lead_quality?: unknown;
  call_status?: unknown;
  visit_status?: unknown;
  view_count?: unknown;
  visit_duration?: unknown;
  last_interaction?: unknown;
}

interface LeadSearchOptions {
  quality?: LeadQuality;
  status?: string;
  project?: string;
  area?: string;
  assignedTo?: string;
  limit?: number;
  offset?: number;
}

interface VisitedLeadEntry {
  leadId: string;
  visitedAt: string;
  duration: number; // milliseconds
  actions: string[];
  notes: string;
}

/**
 * CRM/ERP API Service Layer
 * Handles all backend communication with caching, retries, and error handling
 */
export class CrmErpApiService {
  private supabase = createClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
  );

  private cache = new Map<string, CacheEntry<unknown>>();
  private requestQueue: Promise<unknown>[] = [];
  private isOnline = true;
  private retryAttempts = 3;
  private requestTimeout = 5000;

  constructor() {
    this.initializeNetworkListener();
    this.initializePeriodicSync();
  }

  /**
   * Core API Request Handler with Retry Logic
   */
  private async request<T>(
    endpoint: string,
    method: 'GET' | 'POST' | 'PUT' | 'DELETE' = 'GET',
    body?: unknown,
  ): Promise<ApiResponse<T>> {
    let lastError: Error | null = null;

    for (let attempt = 0; attempt < this.retryAttempts; attempt++) {
      try {
        const controller = new AbortController();
        const timeout = setTimeout(() => controller.abort(), this.requestTimeout);

        const response = await fetch(`/api/crm-erp/${endpoint}`, {
          method,
          headers: { 'Content-Type': 'application/json' },
          body: body ? JSON.stringify(body) : undefined,
          signal: controller.signal,
        });

        clearTimeout(timeout);

        if (!response.ok) {
          if (response.status === 429) {
            // Rate limit - exponential backoff
            await new Promise((resolve) =>
              setTimeout(resolve, Math.pow(2, attempt) * 1000),
            );
            continue;
          }
          throw new Error(`HTTP ${response.status}: ${response.statusText}`);
        }

        const data: unknown = await response.json();
        if (isApiResponse<T>(data)) return data;
        return { success: true, data: data as T, timestamp: Date.now() };
      } catch (error) {
        lastError = error as Error;
        if (attempt < this.retryAttempts - 1) {
          await new Promise((resolve) =>
            setTimeout(resolve, Math.pow(2, attempt) * 500),
          );
        }
      }
    }

    return {
      success: false,
      error: lastError?.message || 'Request failed',
      timestamp: Date.now(),
    };
  }

  /**
   * Advanced Lead Search with Indexing and Caching
   */
  async searchLeads(
    query: string,
    options: LeadSearchOptions = {},
  ): Promise<CrmLead[]> {
    const { limit, offset, ...filters } = options;
    const cacheKey = `search:${query}:${JSON.stringify(options)}`;
    const cached = this.getFromCache<CrmLead[]>(cacheKey);
    if (cached) return cached;

    // Full-text search with filters
    const response = await this.request<RawLeadRow[]>(
      'leads/search',
      'POST',
      { query, filters, limit, offset },
    );

    if (response.success && Array.isArray(response.data)) {
      const leads = response.data.map(normalizeLead);
      this.setCache(cacheKey, leads, 60000); // 1 minute TTL
      return leads;
    }

    return [];
  }

  /**
   * Visited Leads Tracking
   */
  async trackVisitedLead(
    leadId: string,
    duration: number,
    actions: string[],
    notes?: string,
  ): Promise<boolean> {
    const entry: VisitedLeadEntry = {
      leadId,
      visitedAt: new Date().toISOString(),
      duration,
      actions,
      notes: notes || '',
    };

    const response = await this.request('leads/visit-tracking', 'POST', entry);
    return response.success;
  }

  /**
   * Get Visited Leads with Analytics
   */
  async getVisitedLeads(limit = 50) {
    return this.request(`leads/visited?limit=${encodeURIComponent(String(limit))}`, 'GET');
  }

  /**
   * Combined CRM/ERP Metrics
   */
  async getMetrics(): Promise<LeadMetrics | null> {
    const response = await this.request<LeadMetrics>('metrics', 'GET');
    return response.success ? response.data || null : null;
  }

  /**
   * Lead Management Actions
   */
  async assignLead(leadId: string, assigneeId: string, role: string) {
    return this.request('leads/assign', 'POST', { leadId, assigneeId, role });
  }

  async updateLeadStatus(leadId: string, status: string) {
    return this.request('leads/update-status', 'PUT', { leadId, status });
  }

  async proposeSiteVisit(leadId: string, proposedDate: string, notes?: string) {
    return this.request('leads/propose-visit', 'POST', {
      leadId,
      proposedDate,
      notes,
    });
  }

  async createBrokerLock(
    leadId: string,
    visitProofUrl?: string,
    lockDurationDays = 45,
  ) {
    return this.request('leads/create-lock', 'POST', {
      leadId,
      visitProofUrl,
      lockDurationDays,
    });
  }

  /**
   * Batch Operations for Performance
   */
  async batchUpdateLeads(
    updates: Array<{ leadId: string; updates: Record<string, unknown> }>,
  ) {
    return this.request('leads/batch-update', 'PUT', { updates });
  }

  async batchAssignLeads(assignments: Array<{ leadId: string; assigneeId: string }>) {
    return this.request('leads/batch-assign', 'POST', { assignments });
  }

  /**
   * Cache Management
   */
  private getFromCache<T>(key: string): T | null {
    const entry = this.cache.get(key) as CacheEntry<T> | undefined;
    if (!entry) return null;

    const isExpired = Date.now() - entry.timestamp > entry.ttl;
    if (isExpired) {
      this.cache.delete(key);
      return null;
    }

    return entry.data;
  }

  private setCache<T>(key: string, data: T, ttl: number): void {
    this.cache.set(key, { data, timestamp: Date.now(), ttl });
  }

  clearCache(): void {
    this.cache.clear();
  }

  /**
   * Network Status Handling
   */
  private initializeNetworkListener(): void {
    if (typeof window === 'undefined') return;

    window.addEventListener('online', () => {
      this.isOnline = true;
      this.syncOfflineChanges();
    });

    window.addEventListener('offline', () => {
      this.isOnline = false;
    });
  }

  /**
   * Periodic Synchronization
   */
  private initializePeriodicSync(): void {
    if (typeof window === 'undefined') return;

    // Sync every 5 minutes
    setInterval(() => {
      if (this.isOnline) {
        this.syncOfflineChanges();
      }
    }, 5 * 60 * 1000);
  }

  /**
   * Offline Changes Synchronization
   */
  private async syncOfflineChanges(): Promise<void> {
    // Retrieve offline changes from localStorage
    const offlineChanges = localStorage.getItem('crm:offline-changes');
    if (!offlineChanges) return;

    try {
      const changes = JSON.parse(offlineChanges);
      for (const change of changes) {
        await this.request(change.endpoint, change.method, change.body);
      }
      localStorage.removeItem('crm:offline-changes');
    } catch (error) {
      console.error('Sync failed:', error);
    }
  }

  /**
   * Check API Health
   */
  async healthCheck(): Promise<boolean> {
    const response = await this.request('health', 'GET');
    return response.success;
  }
}

// Singleton instance
export const crmErpApi = new CrmErpApiService();

function isApiResponse<T>(value: unknown): value is ApiResponse<T> {
  return (
    typeof value === 'object' &&
    value !== null &&
    'success' in value &&
    'timestamp' in value
  );
}

function normalizeLead(row: RawLeadRow): CrmLead {
  return {
    id: toStringValue(row.id),
    alias: toStringValue(row.alias),
    project: toStringValue(row.project),
    area: toStringValue(row.area),
    leadQuality: toLeadQuality(row.lead_quality),
    callStatus: toStringValue(row.call_status, 'Not Called'),
    visitStatus: toStringValue(row.visit_status, 'Not Scheduled'),
    viewCount: toOptionalNumber(row.view_count),
    visitDuration: toOptionalNumber(row.visit_duration),
    lastInteraction: toOptionalString(row.last_interaction),
  };
}

function toLeadQuality(value: unknown): LeadQuality {
  return value === 'Hot' || value === 'Warm' || value === 'Cold' ? value : 'Warm';
}

function toStringValue(value: unknown, fallback = ''): string {
  return typeof value === 'string' ? value : fallback;
}

function toOptionalString(value: unknown): string | undefined {
  return typeof value === 'string' ? value : undefined;
}

function toOptionalNumber(value: unknown): number | undefined {
  return typeof value === 'number' && Number.isFinite(value) ? value : undefined;
}
