// @ts-ignore: Deno import
import { serve } from 'std/http/server.ts'
import {
  adminClient,
  currentUser,
  requirePermission,
  safeJson,
  corsHeaders,
  validUuid,
  verifyApiVersion,
} from '../_shared/sprint7.ts'

serve(async (req: Request): Promise<Response> => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  if (req.method !== 'POST') return safeJson({ ok: false, reason: 'invalid_method' }, 405)

  const apiCheck = verifyApiVersion(req, 1)
  if (!apiCheck.ok) {
    return safeJson({ ok: false, reason: 'unsupported_api_version', version: apiCheck.version }, 426)
  }

  const user = await currentUser(req)
  if (!user) return safeJson({ ok: false, reason: 'unauthorized' }, 401)

  try {
    const body = await req.json().catch(() => ({}))
    const taskId = validUuid(body.task_id)
    const action = typeof body.action === 'string' ? body.action.toLowerCase() : ''
    const reason = typeof body.reason === 'string' ? body.reason.trim().slice(0, 512) : ''

    if (!taskId || (action !== 'approve' && action !== 'reject')) {
      return safeJson({ ok: false, reason: 'invalid_input' }, 400)
    }

    const admin = adminClient()
    const hasPermission = await requirePermission(admin, user.id, 'can_review_site_visits')
    if (!hasPermission) return safeJson({ ok: false, reason: 'forbidden_permission_required' }, 403)

    const { data: reviewRecord, error: reviewError } = await admin
      .from('enterprise_human_review_queue')
      .select('id, task_id, review_status, assigned_reviewer, review_metadata')
      .eq('task_id', taskId)
      .maybeSingle()

    if (reviewError || !reviewRecord) {
      return safeJson({ ok: false, reason: 'review_record_not_found' }, 404)
    }

    if (reviewRecord.assigned_reviewer && reviewRecord.assigned_reviewer !== user.id) {
      return safeJson({ ok: false, reason: 'reviewer_mismatch' }, 403)
    }

    const reviewStatus = action === 'approve' ? 'approved' : 'rejected'
    const taskStatus = action === 'approve' ? 'completed' : 'rejected'
    const updatedMetadata = {
      ...(reviewRecord.review_metadata ?? {}),
      reviewed_by: user.id,
      reviewed_at: new Date().toISOString(),
      action,
      reason,
    }

    const { error: updateReviewError } = await admin
      .from('enterprise_human_review_queue')
      .update({
        review_status: reviewStatus,
        review_reason: reason,
        assigned_reviewer: user.id,
        review_metadata: updatedMetadata,
        updated_at: new Date().toISOString(),
      })
      .eq('id', reviewRecord.id)

    if (updateReviewError) {
      return safeJson({ ok: false, reason: 'review_update_failed' }, 500)
    }

    const { error: updateTaskError } = await admin
      .from('enterprise_task_queue')
      .update({ status: taskStatus, updated_at: new Date().toISOString() })
      .eq('id', taskId)

    if (updateTaskError) {
      return safeJson({ ok: false, reason: 'task_update_failed' }, 500)
    }

    await admin.from('enterprise_task_history').insert({
      task_id: taskId,
      event_type: `human_review_${reviewStatus}`,
      event_payload: { reviewer: user.id, action, reason },
      agent_name: 'enterprise-review',
    })

    await admin.from('enterprise_task_workflow').update({
      current_state: taskStatus,
      last_agent: 'enterprise-review',
      metadata: updatedMetadata,
      updated_at: new Date().toISOString(),
    }).eq('task_id', taskId)

    return safeJson({ ok: true, task_id: taskId, review_status: reviewStatus })
  } catch (error) {
    return safeJson({ ok: false, reason: 'internal_error' }, 500)
  }
})
