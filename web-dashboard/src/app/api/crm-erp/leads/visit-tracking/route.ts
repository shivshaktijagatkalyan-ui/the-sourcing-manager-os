// /api/crm-erp/leads/visit-tracking/route.ts
import { NextRequest, NextResponse } from 'next/server';
import { createServerSupabaseClient } from '@/lib/server-supabase';

interface VisitTrackingRequest {
  leadId: string;
  duration: number;
  actions: string[];
  notes?: string;
}

export async function POST(request: NextRequest) {
  try {
    const supabase = createServerSupabaseClient();
    const body: VisitTrackingRequest = await request.json();
    const { leadId, duration, actions, notes } = body;

    // Update lead visit count and duration
    const { data: lead, error: leadError } = await supabase
      .from('leads')
      .select('view_count, visit_duration')
      .eq('id', leadId)
      .single();

    if (leadError) throw leadError;

    const newViewCount = (lead?.view_count || 0) + 1;
    const newTotalDuration = (lead?.visit_duration || 0) + duration;

    await supabase
      .from('leads')
      .update({
        view_count: newViewCount,
        visit_duration: newTotalDuration,
        visited_at: new Date().toISOString(),
        last_interaction: new Date().toISOString(),
      })
      .eq('id', leadId);

    // Upsert visited leads tracker
    const { data: existing } = await supabase
      .from('visited_leads')
      .select('*')
      .eq('lead_id', leadId)
      .single();

    if (existing) {
      await supabase
        .from('visited_leads')
        .update({
          last_visited: new Date().toISOString(),
          visit_count: existing.visit_count + 1,
          total_duration: existing.total_duration + duration,
          actions: [...(existing.actions || []), ...actions],
        })
        .eq('lead_id', leadId);
    } else {
      await supabase.from('visited_leads').insert({
        lead_id: leadId,
        first_visited: new Date().toISOString(),
        last_visited: new Date().toISOString(),
        visit_count: 1,
        total_duration: duration,
        actions: actions,
        conversion_status: 'pending',
      });
    }

    // Log activity
    await supabase.from('lead_history').insert({
      lead_id: leadId,
      action: 'lead_viewed',
      new_value: { actions, duration, notes },
      changed_by: 'system',
    });

    return NextResponse.json({
      success: true,
      message: 'Visit tracked',
      timestamp: Date.now(),
    });
  } catch (error) {
    console.error('Visit tracking error:', error);
    return NextResponse.json(
      {
        success: false,
        error: error instanceof Error ? error.message : 'Tracking failed',
        timestamp: Date.now(),
      },
      { status: 500 },
    );
  }
}
