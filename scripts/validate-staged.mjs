#!/usr/bin/env node
import { execFileSync } from 'node:child_process';

const repoRoot = execFileSync('git', ['rev-parse', '--show-toplevel'], {
  encoding: 'utf8',
}).trim();

const stagedFiles = execFileSync(
  'git',
  ['diff', '--cached', '--name-only', '--diff-filter=ACMR'],
  { encoding: 'utf8' },
)
  .split(/\r?\n/)
  .map((entry) => entry.trim())
  .filter(Boolean);

const blockedPathPatterns = [
  /\.(env|pem|p12|pfx|key|jks|keystore|mobileprovision)$/i,
  /(^|\/)\.env(?!\.example$)(\..+)?$/i,
  /(^|\/)\.env\.local$/i,
  /(^|\/)\.next($|\/)/i,
  /(^|\/)node_modules($|\/)/i,
  /(^|\/)build($|\/)/i,
  /(^|\/)dist($|\/)/i,
  /(^|\/)\.dart_tool($|\/)/i,
  /(^|\/)\.pub($|\/)/i,
  /(^|\/)\.temp($|\/)/i,
  /(^|\/)supabase\/\.temp($|\/)/i,
  /(^|\/)supabase_remote_schema\.sql$/i,
  /(^|\/).*\.log$/i,
];

const scanContentFor = [
  { label: 'service role key', regex: /SUPABASE_SERVICE_ROLE_KEY\s*[:=]\s*['"]?[A-Za-z0-9._-]{20,}/i },
  { label: 'database password', regex: /SUPABASE_DB_PASSWORD\s*[:=]\s*['"]?.{8,}/i },
  { label: 'google client secret', regex: /GOOGLE_CLIENT_SECRET\s*[:=]\s*['"]?.{8,}/i },
  { label: 'smtp password', regex: /SMTP_(?:PASSWORD|PASS|SECRET)\s*[:=]\s*['"]?.{8,}/i },
  { label: 'private key block', regex: /BEGIN (?:RSA|EC|OPENSSH|PRIVATE) PRIVATE KEY/ },
  { label: 'generic api key', regex: /(?:api[_-]?key|secret|token)\s*[:=]\s*['"]?[A-Za-z0-9/_+=-]{24,}/i },
];

function isExampleOrDocs(filePath) {
  return (
    filePath.endsWith('.example') ||
    filePath.includes('/docs/') ||
    filePath.startsWith('docs/') ||
    filePath.startsWith('.github/')
  );
}

const errors = [];

for (const filePath of stagedFiles) {
  if (blockedPathPatterns.some((pattern) => pattern.test(filePath))) {
    errors.push(`blocked file path: ${filePath}`);
  }

  if (isExampleOrDocs(filePath)) {
    continue;
  }

  let content = '';
  try {
    content = execFileSync(
      'git',
      ['show', `:${filePath}`],
      { encoding: 'utf8', maxBuffer: 2 * 1024 * 1024 },
    );
  } catch {
    continue;
  }

  for (const rule of scanContentFor) {
    if (rule.regex.test(content)) {
      errors.push(`${filePath}: matched ${rule.label}`);
    }
  }
}

if (errors.length > 0) {
  console.error('\nSecret / artifact gate failed:\n');
  for (const error of errors) {
    console.error(`- ${error}`);
  }
  console.error(
    '\nMove secrets to environment variables or GitHub/Supabase secret stores, and keep build artifacts out of the repo.',
  );
  process.exit(1);
}

console.log(`Staged-file security gate passed for ${stagedFiles.length} file(s).`);
