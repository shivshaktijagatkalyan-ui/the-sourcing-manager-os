import { cleanText, sha256 } from '../sprint7.ts'

const enterpriseTaskTypeSet = new Set([
  'broker_upload_lead',
  'site_visit_verification',
  'site_visit_evidence',
  'risk_review',
  'compliance_check',
  'data_loan_request',
  'human_review',
  'salesforce_inbound_ingest',
  'salesforce_outbound_sync',
])

export function normalizeTaskPayload(payload: unknown) {
  if (payload && typeof payload === 'object' && !Array.isArray(payload)) {
    return payload as Record<string, unknown>
  }
  return {}
}

export function normalizeTaskMetadata(metadata: unknown) {
  return normalizeTaskPayload(metadata)
}

export function validateTaskType(taskType: unknown) {
  if (typeof taskType !== 'string') return null
  const cleaned = cleanText(taskType, 80).toLowerCase().replace(/[^a-z0-9_]/g, '_')
  return enterpriseTaskTypeSet.has(cleaned) ? cleaned : null
}

export function initialWorkflowState(taskType: string) {
  if (taskType === 'human_review' || taskType === 'risk_review') return 'awaiting_human_review'
  return 'pending'
}

export function shouldCreateHumanReview(taskType: string, metadata: Record<string, unknown>) {
  return (
    metadata.review_required === true ||
    taskType === 'human_review' ||
    taskType === 'risk_review'
  )
}

export async function buildTaskKey(
  taskType: string,
  payload: Record<string, unknown>,
  metadata: Record<string, unknown>,
) {
  const digest = await sha256(JSON.stringify({ payload, metadata }))
  return `${taskType}:${digest}`
}

export async function createEnterpriseTask(
  admin: any,
  taskType: string,
  payload: Record<string, unknown>,
  metadata: Record<string, unknown>,
  priority = 100,
  availableAt = new Date(),
) {
  const taskKey = await buildTaskKey(taskType, payload, metadata)
  const insert = await admin
    .from('enterprise_task_queue')
    .insert({
      task_key: taskKey,
      task_type: taskType,
      payload,
      priority,
      metadata,
      available_at: availableAt.toISOString(),
      status: initialWorkflowState(taskType) === 'pending' ? 'pending' : 'pending',
    })
    .select('id, task_key')
    .single()

  if (insert.error) {
    const duplicate = typeof insert.error.message === 'string' && /duplicate/i.test(insert.error.message)
    return { ok: false, reason: duplicate ? 'duplicate_task' : 'queue_insert_failed', error: insert.error }
  }

  const taskId = insert.data?.id as string
  const workflowState = initialWorkflowState(taskType)
  const status = workflowState === 'awaiting_human_review' ? 'pending_review' : 'pending'

  await admin.from('enterprise_task_workflow').insert({
    task_id: taskId,
    current_state: workflowState,
    metadata,
  })

  return {
    ok: true,
    taskId,
    taskKey,
    status,
    workflowState,
  }
}

export async function createHumanReviewTicket(admin: any, taskId: string, metadata: Record<string, unknown>) {
  const insert = await admin
    .from('enterprise_human_review_queue')
    .insert({ task_id: taskId, review_status: 'pending', review_metadata: metadata })
    .select('id, task_id, review_status')
    .single()

  if (insert.error) {
    return { ok: false, reason: 'human_review_create_failed', error: insert.error }
  }

  return { ok: true, review: insert.data }
}

export function workflowStateTransition(currentState: string, nextState: string) {
  return {
    previous_state: currentState,
    next_state: nextState,
    transitioned_at: new Date().toISOString(),
  }
}

export function buildTaskAuditContext(taskId: string, taskType: string, status: string) {
  return {
    task_id: taskId,
    task_type: taskType,
    status,
  }
}
