// Supabase Deno Edge Function: kafka-decoder
// Decodes and ingests Kafka message streams (e.g. from Upstash or Confluent Sink webhooks).
// Supports standard JSON streams and binary Avro streams using Confluent's 5-byte magic envelope.

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import {
  adminClient,
  safeJson,
  corsHeaders,
  validUuid,
  sanitizeHtml,
  validatePhone,
  verifyApiVersion,
  timingSafeEqualHex,
  hmacSha256
} from "../_shared/sprint7.ts"

// Schema registry database (Mock cache for Avro schemas)
const SCHEMA_REGISTRY: Record<number, { name: string; fields: string[] }> = {
  10001: {
    name: "LeadSourcedEvent",
    fields: ["broker_id", "lead_alias", "phone", "area", "city"]
  },
  10002: {
    name: "SiteVisitCompletedEvent",
    fields: ["site_visit_id", "sourcing_manager_id", "photo_hash", "gps_verified"]
  }
}

// Converts a base64 string to a Uint8Array
function base64ToBytes(base64: string): Uint8Array {
  const binString = atob(base64)
  const bytes = new Uint8Array(binString.length)
  for (let i = 0; i < binString.length; i++) {
    bytes[i] = binString.charCodeAt(i)
  }
  return bytes
}

// Decodes a standard Avro Zigzag integer/long from a binary stream reader
function readZigzagLong(bytes: Uint8Array, state: { offset: number }): number {
  let value = 0
  let shift = 0
  let b = 0
  do {
    b = bytes[state.offset++]
    value |= (b & 0x7f) << shift
    shift += 7
  } while ((b & 0x80) !== 0)

  // Convert zigzag back to standard integer
  return (value >>> 1) ^ -(value & 1)
}

// Reads a variable length string from binary Avro representation
function readAvroString(bytes: Uint8Array, state: { offset: number }): string {
  const length = readZigzagLong(bytes, state)
  if (length <= 0) return ""
  const slice = bytes.slice(state.offset, state.offset + length)
  state.offset += length
  return new TextDecoder().decode(slice)
}

// Decodes Avro payload conforming to Confluent Wire Format (Magic Byte 0x00 + 4-byte Schema ID)
function decodeConfluentAvro(base64Payload: string): { schemaId: number; schemaName: string; decoded: Record<string, any> } {
  const bytes = base64ToBytes(base64Payload)

  if (bytes.length < 5) {
    throw new Error("payload_too_short")
  }

  // 1. Verify Magic Byte (0x00)
  if (bytes[0] !== 0x00) {
    throw new Error("invalid_confluent_magic_byte")
  }

  // 2. Extract Schema ID (4-byte Big-Endian Int)
  const schemaId = (bytes[1] << 24) | (bytes[2] << 16) | (bytes[3] << 8) | bytes[4]
  const schema = SCHEMA_REGISTRY[schemaId]
  if (!schema) {
    throw new Error(`schema_not_found_in_registry: ${schemaId}`)
  }

  const decoded: Record<string, any> = {}
  const state = { offset: 5 }

  // 3. Decode binary payload sequentially based on mock schema fields
  // In a production setup, this would utilize a dynamic parser (like avsc or fast-avro) linked to schema registry definitions
  if (schema.name === "LeadSourcedEvent") {
    decoded.broker_id = readAvroString(bytes, state)
    decoded.lead_alias = readAvroString(bytes, state)
    decoded.phone = readAvroString(bytes, state)
    decoded.area = readAvroString(bytes, state)
    decoded.city = readAvroString(bytes, state)
  } else if (schema.name === "SiteVisitCompletedEvent") {
    decoded.site_visit_id = readAvroString(bytes, state)
    decoded.sourcing_manager_id = readAvroString(bytes, state)
    decoded.photo_hash = readAvroString(bytes, state)
    decoded.gps_verified = bytes[state.offset++] === 1
  } else {
    throw new Error(`unsupported_schema: ${schema.name}`)
  }

  return { schemaId, schemaName: schema.name, decoded }
}

serve(async (req: Request): Promise<Response> => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  if (req.method !== 'POST') return safeJson({ ok: false, reason: 'invalid_method' }, 405)

  // 1. Verify API Version
  const apiCheck = verifyApiVersion(req, 1)
  if (!apiCheck.ok) {
    return safeJson({ ok: false, reason: 'api_version_unsupported' }, 400)
  }

  try {
    const admin = adminClient()

    // 2. Authenticate Webhook Client (Timing-Safe Signature Matching)
    const suppliedSignature = req.headers.get("X-Kafka-Signature")
    const webhookSecret = Deno.env.get("KAFKA_WEBHOOK_SECRET") || "secret-kafka-key-2026"

    const rawBody = await req.text()
    const expectedSignature = await hmacSha256(rawBody, webhookSecret)

    if (!suppliedSignature || !timingSafeEqualHex(suppliedSignature, expectedSignature)) {
      // Log auth rejection to audit events
      await admin.from('audit_events').insert({
        event_type: 'kafka_webhook_unauthorized',
        event_context: {
          ip: req.headers.get("x-forwarded-for") || "unknown",
          signature_present: Boolean(suppliedSignature)
        }
      })
      return safeJson({ ok: false, reason: 'unauthorized_signature' }, 401)
    }

    const body = JSON.parse(rawBody)
    const { topic, partition, offset, value, is_avro } = body

    if (!topic || !value) {
      return safeJson({ ok: false, reason: 'invalid_kafka_message_structure' }, 400)
    }

    let decodedPayload: Record<string, any> = {}
    let schemaName = "JSON"
    let schemaId: number | null = null

    // 3. Perform Stream Decoding (Avro Binary vs. Plain JSON)
    if (is_avro === true || is_avro === "true") {
      try {
        const result = decodeConfluentAvro(value)
        decodedPayload = result.decoded
        schemaName = result.schemaName
        schemaId = result.schemaId
      } catch (err) {
        return safeJson({ ok: false, reason: 'avro_decoding_failed', details: err.message }, 422)
      }
    } else {
      // Direct JSON parsing if not binary Avro
      try {
        decodedPayload = typeof value === "string" ? JSON.parse(value) : value
      } catch {
        return safeJson({ ok: false, reason: 'json_parsing_failed' }, 400)
      }
    }

    // 4. Input Sanitization & Validation (Sanitize names and validate phones)
    const sanitizedAlias = sanitizeHtml(decodedPayload.lead_alias || decodedPayload.alias || "")
    const validatedPhone = validatePhone(decodedPayload.phone || "")
    const sanitizedArea = sanitizeHtml(decodedPayload.area || "")
    const sanitizedCity = sanitizeHtml(decodedPayload.city || "")

    // 5. Ingestion routing based on topic
    if (topic === "leads-sourced") {
      if (!sanitizedAlias || !validatedPhone) {
        return safeJson({ ok: false, reason: 'sanitization_failed_missing_required_fields' }, 400)
      }

      // Check for duplicates or register the lead in the system
      const brokerId = validUuid(decodedPayload.broker_id)

      // Save Ingested Kafka Lead to Audit Log & System Ingestion queue
      await admin.from('audit_events').insert({
        event_type: 'kafka_lead_ingested',
        event_context: {
          topic,
          partition,
          offset,
          schema_id: schemaId,
          schema_name: schemaName,
          broker_id: brokerId,
          lead_alias: sanitizedAlias,
          area: sanitizedArea,
          city: sanitizedCity
        }
      })

      return safeJson({
        ok: true,
        topic,
        offset,
        schema_name: schemaName,
        status: "lead_successfully_ingested"
      }, 200)

    } else if (topic === "site-visits-events") {
      const visitId = validUuid(decodedPayload.site_visit_id)
      if (!visitId) {
        return safeJson({ ok: false, reason: 'invalid_site_visit_id' }, 400)
      }

      await admin.from('audit_events').insert({
        event_type: 'kafka_site_visit_synced',
        event_context: {
          topic,
          partition,
          offset,
          schema_id: schemaId,
          schema_name: schemaName,
          site_visit_id: visitId,
          gps_verified: decodedPayload.gps_verified || false
        }
      })

      return safeJson({
        ok: true,
        topic,
        offset,
        schema_name: schemaName,
        status: "site_visit_successfully_synced"
      }, 200)

    } else {
      return safeJson({ ok: false, reason: 'unsupported_kafka_topic', topic }, 400)
    }

  } catch (err) {
    return safeJson({ ok: false, reason: 'internal_server_error' }, 500)
  }
})
