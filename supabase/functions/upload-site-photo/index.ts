// @ts-ignore: Deno import
import { serve } from 'std/http/server.ts'
import { adminClient, currentUser, requirePermission, safeJson, recordAudit, corsHeaders } from '../_shared/sprint7.ts'



serve(async (req: Request): Promise<Response> => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })

  try {
    const user = await currentUser(req)
    if (!user) return safeJson({ ok: false, reason: 'unauthorized' }, 401)

    const admin = adminClient()

    // 1. Fetch Pilot Context
    const { data: pilot, error: pilotError } = await admin
      .from('pilot_users')
      .select('org_id, status, organizations(status)')
      .eq('user_id', user.id)
      .maybeSingle()

    if (pilotError || !pilot || pilot.status !== 'active' || pilot.organizations?.status !== 'active') {
      return safeJson({ ok: false, reason: 'access_blocked_operational' }, 403)
    }

    // 2. Strict Permission Check
    const allowed = await requirePermission(admin, user.id, 'can_verify_site_visits', pilot.org_id)
    if (!allowed) return safeJson({ ok: false, reason: 'forbidden_permission_required' }, 403)

    const formData = await req.formData()
    const file = formData.get('photo') as File
    const site_visit_id = formData.get('site_visit_id') as string

    if (!file || !site_visit_id) {
      return safeJson({ ok: false, reason: 'invalid_input' }, 400)
    }

    // 3. Validate Visit State
    const { data: visit, error: fetchError } = await admin
      .from('site_visits')
      .select('id, lead_id, status')
      .eq('id', site_visit_id)
      .eq('sourcing_manager_id', user.id)
      .single()

    if (fetchError || !visit || visit.status !== 'gps_verified') {
      return safeJson({ ok: false, reason: 'invalid_state' }, 409)
    }

    // 4. Calculate SHA-256 for Evidence Chain
    const arrayBuffer = await file.arrayBuffer()
    const hashBuffer = await crypto.subtle.digest('SHA-256', arrayBuffer)
    const hashArray = Array.from(new Uint8Array(hashBuffer))
    const hashHex = hashArray.map(b => b.toString(16).padStart(2, '0')).join('')

    // 5. Upload to Storage
    const filePath = `evidence/${visit.lead_id}/${site_visit_id}/${hashHex}.jpg`
    const { error: uploadError } = await admin.storage
      .from('site-evidence')
      .upload(filePath, file, {
          contentType: 'image/jpeg',
          upsert: false
      })

    if (uploadError) throw new Error('storage_upload_failed')

    // 6. Atomic Secure Update
    const { data: result, error: updateError } = await admin.rpc('upload_site_photo_v2', {
        p_visit_id: site_visit_id,
        p_actor_id: user.id,
        p_photo_sha256: hashHex
    })

    if (updateError || !result || !result.ok) {
      return safeJson({ ok: false, reason: 'update_failed' }, 500)
    }

    return safeJson({ ok: true, hash: hashHex })

  } catch (err) {
    return safeJson({ ok: false, reason: 'internal_server_error' }, 500)
  }
})
