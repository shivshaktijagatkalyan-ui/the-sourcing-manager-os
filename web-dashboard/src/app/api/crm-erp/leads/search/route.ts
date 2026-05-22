// /api/crm-erp/leads/search/route.ts
import { NextRequest, NextResponse } from 'next/server';
import { createServerSupabaseClient } from '@/lib/server-supabase';

interface SearchRequest {
  query: string;
  filters?: {
    quality?: string;
    status?: string;
    project?: string;
    area?: string;
    assignedTo?: string;
  };
  limit?: number;
  offset?: number;
}

export async function POST(request: NextRequest) {
  try {
    const supabase = createServerSupabaseClient();
    const body: SearchRequest = await request.json();
    const { query = '', filters = {}, limit = 50, offset = 0 } = body;

    let dbQuery = supabase.from('leads').select('*');

    // Full-text search
    if (query.trim()) {
      const searchTerm = query.toLowerCase();
      dbQuery = dbQuery.or(
        `alias.ilike.%${searchTerm}%,project.ilike.%${searchTerm}%,area.ilike.%${searchTerm}%,assigned_to.ilike.%${searchTerm}%`,
      );
    }

    // Apply filters
    if (filters.quality) dbQuery = dbQuery.eq('lead_quality', filters.quality);
    if (filters.status) dbQuery = dbQuery.eq('call_status', filters.status);
    if (filters.project) dbQuery = dbQuery.eq('project', filters.project);
    if (filters.area) dbQuery = dbQuery.eq('area', filters.area);
    if (filters.assignedTo) dbQuery = dbQuery.eq('assigned_to', filters.assignedTo);

    // Pagination
    dbQuery = dbQuery.range(offset, offset + limit - 1);

    const { data, error, count } = await dbQuery;

    if (error) throw error;

    return NextResponse.json({
      success: true,
      data: data || [],
      total: count || 0,
      timestamp: Date.now(),
    });
  } catch (error) {
    console.error('Search error:', error);
    return NextResponse.json(
      {
        success: false,
        error: error instanceof Error ? error.message : 'Search failed',
        timestamp: Date.now(),
      },
      { status: 500 },
    );
  }
}
