// /api/crm-erp/leads/[id]/route.ts
import { NextRequest, NextResponse } from 'next/server';
import { createServerSupabaseClient } from '@/lib/server-supabase';

interface UpdateLeadRequest {
  status?: string;
  quality?: string;
  assignedTo?: string;
  notes?: string;
}

interface LeadRouteContext {
  params: Promise<{ id: string }>;
}

export async function GET(
  request: NextRequest,
  context: LeadRouteContext,
) {
  try {
    const supabase = createServerSupabaseClient();
    const { id } = await context.params;
    const { data, error } = await supabase
      .from('leads')
      .select('*')
      .eq('id', id)
      .single();

    if (error) throw error;

    return NextResponse.json({
      success: true,
      data,
      timestamp: Date.now(),
    });
  } catch (error) {
    console.error('Get lead error:', error);
    return NextResponse.json(
      {
        success: false,
        error: error instanceof Error ? error.message : 'Failed to get lead',
        timestamp: Date.now(),
      },
      { status: 500 },
    );
  }
}

export async function PUT(
  request: NextRequest,
  context: LeadRouteContext,
) {
  try {
    const supabase = createServerSupabaseClient();
    const { id } = await context.params;
    const body: UpdateLeadRequest = await request.json();

    const updateData: Record<string, unknown> = {
      updated_at: new Date().toISOString(),
    };

    if (body.status) updateData.call_status = body.status;
    if (body.quality) updateData.lead_quality = body.quality;
    if (body.assignedTo) updateData.assigned_to = body.assignedTo;
    if (body.notes) updateData.notes = body.notes;

    const { data, error } = await supabase
      .from('leads')
      .update(updateData)
      .eq('id', id)
      .select()
      .single();

    if (error) throw error;

    // Log change
    await supabase.from('lead_history').insert({
      lead_id: id,
      action: 'lead_updated',
      new_value: updateData,
      changed_by: 'user',
    });

    return NextResponse.json({
      success: true,
      data,
      timestamp: Date.now(),
    });
  } catch (error) {
    console.error('Update lead error:', error);
    return NextResponse.json(
      {
        success: false,
        error: error instanceof Error ? error.message : 'Failed to update lead',
        timestamp: Date.now(),
      },
      { status: 500 },
    );
  }
}
