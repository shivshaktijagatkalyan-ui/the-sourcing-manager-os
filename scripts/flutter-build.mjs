import { existsSync } from 'node:fs'
import { spawnSync } from 'node:child_process'
import { join } from 'node:path'

const candidates = [
  process.env.FLUTTER_BIN,
  process.platform === 'win32' ? 'flutter.bat' : 'flutter',
  process.platform === 'win32' ? 'C:\\src\\flutter\\bin\\flutter.bat' : undefined,
].filter(Boolean)

let flutterBin = null

for (const candidate of candidates) {
  if (candidate.includes('\\') || candidate.includes('/')) {
    if (existsSync(candidate)) {
      flutterBin = candidate
      break
    }
    continue
  }

  const probe = spawnSync(candidate, ['--version'], { stdio: 'ignore', shell: process.platform === 'win32' })
  if (probe.status === 0) {
    flutterBin = candidate
    break
  }
}

if (!flutterBin) {
  console.error('Flutter SDK not found. Set FLUTTER_BIN or add Flutter to PATH.')
  process.exit(1)
}

const result = spawnSync(flutterBin, ['build', 'web', '--release', '--no-web-resources-cdn'], {
  cwd: join(process.cwd(), 'flutter_app'),
  stdio: 'inherit',
  shell: process.platform === 'win32',
})

process.exit(result.status ?? 1)
