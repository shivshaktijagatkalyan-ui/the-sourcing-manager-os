// @ts-ignore: Deno import
import { serve } from 'std/http/server.ts'
import {
  adminClient,
  corsHeaders,
  recordAudit,
  safeJson,
  verifyApiVersion,
} from '../_shared/sprint7.ts'
import {
  buildTaskAuditContext,
  createEnterpriseTask,
  createHumanReviewTicket,
  normalizeTaskMetadata,
  normalizeTaskPayload,
  shouldCreateHumanReview,
  validateTaskType,
} from '../_shared/orchestration/index.ts'

function parseTimestamp(value: unknown) {
  if (typeof value === 'string' || typeof value === 'number') {
    const candidate = new Date(value)
    if (!Number.isNaN(candidate.getTime())) return candidate
  }
  return null
}

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  if (req.method !== 'POST') return safeJson({ ok: false, reason: 'invalid_method' }, 405)

  const versionCheck = verifyApiVersion(req, 1)
  if (!versionCheck.ok) {
    return safeJson({ ok: false, reason: 'unsupported_api_version', version: versionCheck.version }, 426)
  }

  try {
    const body = await req.json().catch(() => ({}))
    const taskType = validateTaskType(body.task_type)
    if (!taskType) return safeJson({ ok: false, reason: 'invalid_task_type' }, 400)

    const payload = normalizeTaskPayload(body.payload)
    const metadata = normalizeTaskMetadata(body.metadata)
    const priority = Number.isFinite(body.priority) ? Math.max(1, Math.min(1000, body.priority)) : 100
    const availableAt = parseTimestamp(body.available_at) ?? new Date()

    const admin = adminClient()
    const taskResult = await createEnterpriseTask(admin, taskType, payload, metadata, priority, availableAt)
    if (!taskResult.ok) {
      if (taskResult.reason === 'duplicate_task') {
        return safeJson({ ok: false, reason: 'duplicate_task' }, 409)
      }
      return safeJson({ ok: false, reason: taskResult.reason ?? 'task_create_failed' }, 500)
    }

    await recordAudit(admin, null, null, null, 'enterprise_task_enqueued', {
      ...buildTaskAuditContext(taskResult.taskId, taskType, taskResult.status),
      priority,
      available_at: availableAt.toISOString(),
    })

    if (shouldCreateHumanReview(taskType, metadata)) {
      await createHumanReviewTicket(admin, taskResult.taskId, metadata)
    }

    return safeJson({
      ok: true,
      task_id: taskResult.taskId,
      task_key: taskResult.taskKey,
      status: taskResult.status,
      workflow_state: taskResult.workflowState,
      available_at: availableAt.toISOString(),
    }, 201)
  } catch (error) {
    return safeJson({ ok: false, reason: 'internal_error' }, 500)
  }
})
