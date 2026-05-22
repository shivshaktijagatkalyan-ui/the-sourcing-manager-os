// /api/crm-erp/leads/visited/route.ts
import { NextRequest, NextResponse } from 'next/server';
import { createServerSupabaseClient } from '@/lib/server-supabase';

export async function GET(request: NextRequest) {
  try {
    const supabase = createServerSupabaseClient();
    const limit = request.nextUrl.searchParams.get('limit') || '50';

    const { data, error } = await supabase
      .from('visited_leads')
      .select(`
        *,
        leads:lead_id(*)
      `)
      .order('last_visited', { ascending: false })
      .limit(parseInt(limit));

    if (error) throw error;

    return NextResponse.json({
      success: true,
      data: data || [],
      timestamp: Date.now(),
    });
  } catch (error) {
    console.error('Get visited leads error:', error);
    return NextResponse.json(
      {
        success: false,
        error: error instanceof Error ? error.message : 'Failed to get visited leads',
        timestamp: Date.now(),
      },
      { status: 500 },
    );
  }
}
