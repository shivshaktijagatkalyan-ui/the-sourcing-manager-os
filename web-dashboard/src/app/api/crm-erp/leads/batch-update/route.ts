// /api/crm-erp/leads/batch-update/route.ts
import { NextRequest, NextResponse } from 'next/server';
import { createServerSupabaseClient } from '@/lib/server-supabase';

interface BatchUpdateRequest {
  updates: Array<{
    leadId: string;
    updates: Record<string, unknown>;
  }>;
}

export async function PUT(request: NextRequest) {
  try {
    const supabase = createServerSupabaseClient();
    const body: BatchUpdateRequest = await request.json();
    const { updates } = body;

    const results = [];

    for (const update of updates) {
      const updateData = {
        ...update.updates,
        updated_at: new Date().toISOString(),
      };

      const { data, error } = await supabase
        .from('leads')
        .update(updateData)
        .eq('id', update.leadId)
        .select()
        .single();

      if (!error) {
        results.push({ leadId: update.leadId, success: true, data });

        // Log change
        await supabase.from('lead_history').insert({
          lead_id: update.leadId,
          action: 'lead_updated',
          new_value: updateData,
          changed_by: 'batch_operation',
        });
      } else {
        results.push({ leadId: update.leadId, success: false, error: error.message });
      }
    }

    return NextResponse.json({
      success: true,
      data: results,
      timestamp: Date.now(),
    });
  } catch (error) {
    console.error('Batch update error:', error);
    return NextResponse.json(
      {
        success: false,
        error: error instanceof Error ? error.message : 'Batch update failed',
        timestamp: Date.now(),
      },
      { status: 500 },
    );
  }
}
