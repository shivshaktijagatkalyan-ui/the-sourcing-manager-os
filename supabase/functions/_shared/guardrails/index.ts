export function stripHtmlTags(value: string) {
  return value.replace(/<script\b[^<]*(?:(?!<\/script>)<[^<]*)*<\/script>/gi, '').replace(/<[^>]*>/g, '').trim()
}

export function allowListText(value: unknown, maxLen = 120) {
  if (typeof value !== 'string') return ''
  return value.replace(/[^a-zA-Z0-9 \-_\.]/g, '').slice(0, maxLen)
}

export function isValidExternalUrl(value: unknown) {
  if (typeof value !== 'string') return false
  try {
    const url = new URL(value)
    return ['https:', 'http:'].includes(url.protocol)
  } catch {
    return false
  }
}
