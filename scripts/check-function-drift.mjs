import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const functionsDir = path.join(root, 'supabase', 'functions');
const configPath = path.join(root, 'supabase', 'config.toml');

const functionDirs = fs.readdirSync(functionsDir, { withFileTypes: true })
  .filter((entry) => entry.isDirectory() && entry.name !== '_shared')
  .map((entry) => entry.name)
  .sort();

const configText = fs.readFileSync(configPath, 'utf8');
const configured = [...configText.matchAll(/^\[functions\.("?)([^"\]]+)\1\]/gm)]
  .map((match) => match[2])
  .sort();

const missingConfig = functionDirs.filter((name) => !configured.includes(name));
const staleConfig = configured.filter((name) => !functionDirs.includes(name));

if (missingConfig.length || staleConfig.length) {
  console.error('Supabase function/config drift found.');
  if (missingConfig.length) console.error(`Missing config: ${missingConfig.join(', ')}`);
  if (staleConfig.length) console.error(`Stale config: ${staleConfig.join(', ')}`);
  process.exit(1);
}

console.log(`Supabase function/config drift check passed (${functionDirs.length} functions).`);
