// /api/crm-erp/metrics/route.ts
import { NextResponse } from 'next/server';
import { createServerSupabaseClient } from '@/lib/server-supabase';

export async function GET() {
  try {
    const supabase = createServerSupabaseClient();
    const { data: leads, error: leadsError } = await supabase
      .from('leads')
      .select('*');

    if (leadsError) throw leadsError;

    // Calculate metrics
    const totalLeads = leads?.length || 0;
    const hotLeads = leads?.filter((l) => l.lead_quality === 'Hot').length || 0;
    const visitedLeads = leads?.filter((l) => l.view_count > 0).length || 0;
    const lostLeads = leads?.filter((l) => l.lead_quality === 'Cold' || l.brokerage_status === 'Blocked').length || 0;

    const conversionRate = totalLeads > 0 ? visitedLeads / totalLeads : 0;

    const totalFollowups = leads?.reduce((sum, lead) => {
      return sum + (lead.calls_attempted || 0);
    }, 0) || 0;

    const averageFollowups = totalLeads > 0 ? totalFollowups / totalLeads : 0;

    return NextResponse.json({
      success: true,
      data: {
        totalLeads,
        hotLeads,
        visitedLeads,
        conversionRate: Number(conversionRate.toFixed(2)),
        averageFollowups: Number(averageFollowups.toFixed(1)),
        lostLeads,
      },
      timestamp: Date.now(),
    });
  } catch (error) {
    console.error('Metrics error:', error);
    return NextResponse.json(
      {
        success: false,
        error: error instanceof Error ? error.message : 'Metrics failed',
        timestamp: Date.now(),
      },
      { status: 500 },
    );
  }
}
