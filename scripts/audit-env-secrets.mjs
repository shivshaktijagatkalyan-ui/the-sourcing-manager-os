import { readFileSync, readdirSync } from 'fs'
import { join } from 'path'

const root = process.cwd()
const secretPatterns = [
  /EXOTEL_/,
  /VOICE_AI_/,
  /GOOGLE_OAUTH_/,
  /SUPABASE_/,
  /SERVICE_ROLE/,
]

function findEnvFiles(basePath) {
  return readdirSync(basePath, { withFileTypes: true })
    .filter((entry) => entry.isFile() && /^\.(env|env\.[a-zA-Z0-9._-]+)$/.test(entry.name))
    .map((entry) => join(basePath, entry.name))
}

function scanFile(filePath) {
  const contents = readFileSync(filePath, 'utf8')
  const lines = contents.split(/\r?\n/)
  const violations = []

  for (const [index, rawLine] of lines.entries()) {
    const line = rawLine.trim()
    if (!line || line.startsWith('#')) continue
    const [key] = line.split('=', 1)
    if (!key) continue
    if (secretPatterns.some((pattern) => pattern.test(key))) {
      violations.push({ line: index + 1, key })
    }
  }

  return violations
}

const envFiles = [...findEnvFiles(root), ...findEnvFiles(join(root, 'supabase'))]
let total = 0
let found = 0

for (const filePath of envFiles) {
  total += 1
  const violations = scanFile(filePath)
  if (violations.length > 0) {
    found += 1
    console.warn(`Found secrets-like env keys in ${filePath}:`)
    for (const violation of violations) {
      console.warn(`  line ${violation.line}: ${violation.key}`)
    }
  }
}

if (found === 0) {
  console.log(`No local env secret patterns found in ${total} files.`)
  process.exit(0)
} else {
  console.error(`Secret patterns found in ${found} file(s). Remove or relocate sensitive keys.`)
  process.exit(1)
}
