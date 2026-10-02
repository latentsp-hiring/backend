# Builds data\dev.db the way the grader builds its database: contract\schema.sql,
# then contract\seed.sql, then your migrations. Needs sqlite3.exe on PATH.
#
# The migrations step is a PowerShell port of images/base/migrate: it applies
# migrations\*.sql in byte order of their names, records each in _migrations and
# skips recorded ones, rejects the same transaction control and dot-command lines,
# and sends sqlite3 the same bytes migrate pipes to it (BEGIN;, the file, the
# _migrations INSERT, COMMIT;). If the two ever disagree, images/base/migrate is
# what the grader runs.
#
# Usage: .\scripts\init-db.ps1 [--force]
# Refuses to replace an existing data\dev.db unless you pass --force.
#
# If you replaced /app/migrate, set $env:MIGRATE to the path of your migrate script.
# It runs with sh (for example Git Bash's), with DATABASE_PATH and MIGRATIONS_DIR set.
$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path

$force = $false
if ($args.Count -eq 1 -and $args[0] -ceq "--force") {
  $force = $true
} elseif ($args.Count -ne 0) {
  [Console]::Error.WriteLine("usage: .\scripts\init-db.ps1 [--force]")
  exit 2
}

if (-not (Get-Command sqlite3 -ErrorAction SilentlyContinue)) { throw "init-db: install the sqlite3 CLI first" }

if ((Test-Path (Join-Path $root "data\dev.db")) -and -not $force) {
  [Console]::Error.WriteLine(@'
init-db: data\dev.db already exists, so nothing was changed.
Rebuilding it deletes every row in it, including the webhook deliveries and sync
runs your service recorded. That traffic is part of what you commit.
To apply new migrations to the existing database instead, run the default migrate
on it from Git Bash; it skips the files it already applied:
  DATABASE_PATH=data/dev.db MIGRATIONS_DIR=migrations sh images/base/migrate
To delete it and rebuild from scratch anyway, run: .\scripts\init-db.ps1 --force
'@)
  exit 1
}

$previousDatabasePath = $env:DATABASE_PATH
$previousMigrationsDir = $env:MIGRATIONS_DIR
$wrapped = Join-Path $root "data\.migrate.sql"
Push-Location $root
try {
  New-Item -ItemType Directory -Force -Path data | Out-Null
  Remove-Item -Force -ErrorAction SilentlyContinue data\dev.db, data\dev.db-wal, data\dev.db-shm

  sqlite3 -bail data/dev.db ".read 'contract/schema.sql'"
  if ($LASTEXITCODE -ne 0) { throw "init-db: contract/schema.sql failed" }
  sqlite3 -bail data/dev.db ".read 'contract/seed.sql'"
  if ($LASTEXITCODE -ne 0) { throw "init-db: contract/seed.sql failed" }

  if ($env:MIGRATE) {
    if (-not (Get-Command sh -ErrorAction SilentlyContinue)) { throw "init-db: MIGRATE is set, but sh is not on PATH" }
    $env:DATABASE_PATH = "data/dev.db"
    $env:MIGRATIONS_DIR = "migrations"
    sh $env:MIGRATE
    if ($LASTEXITCODE -ne 0) { throw "init-db: $env:MIGRATE failed" }
  } else {
    $names = [string[]]@(Get-ChildItem migrations -Filter *.sql -File -ErrorAction SilentlyContinue | ForEach-Object { $_.Name })
    [Array]::Sort($names, [StringComparer]::Ordinal)
    $ascii = [Text.Encoding]::ASCII
    $utf8 = New-Object Text.UTF8Encoding($false)
    sqlite3 -bail data/dev.db "CREATE TABLE IF NOT EXISTS _migrations (name TEXT PRIMARY KEY, applied_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')));"
    if ($LASTEXITCODE -ne 0) { throw "migrate: could not create _migrations" }
    foreach ($name in $names) {
      $quoted = "'" + $name.Replace("'", "''") + "'"
      $seen = sqlite3 -bail data/dev.db "SELECT 1 FROM _migrations WHERE name = $quoted;"
      if ($LASTEXITCODE -ne 0) { throw "migrate: could not read _migrations" }
      if ($seen) {
        Write-Output "migrate: $name already applied"
        continue
      }
      # Raw bytes, so sqlite3 sees exactly what migrate's `cat` would give it,
      # whatever the file's encoding or line endings.
      $body = [IO.File]::ReadAllBytes((Join-Path $root "migrations\$name"))
      $lines = [Text.Encoding]::UTF8.GetString($body) -split "`n"
      if ($lines -match '(?i)^\s*(BEGIN(\s+(DEFERRED|IMMEDIATE|EXCLUSIVE))?(\s+TRANSACTION)?\s*;|COMMIT(\s+TRANSACTION)?\s*;|END\s+TRANSACTION|ROLLBACK)') {
        throw "migrate: ${name}: remove BEGIN/COMMIT/ROLLBACK; each file already runs in its own transaction"
      }
      if ($lines -cmatch '^\s*\.') {
        throw "migrate: ${name}: remove sqlite3 dot-commands; only SQL statements are allowed"
      }
      # PowerShell re-encodes text it pipes to a native command, so write the
      # bytes migrate would pipe to a file and have sqlite3 .read it instead.
      $bytes = New-Object System.Collections.Generic.List[byte]
      $bytes.AddRange($ascii.GetBytes("BEGIN;`n"))
      $bytes.AddRange($body)
      $bytes.AddRange($utf8.GetBytes("`nINSERT INTO _migrations (name) VALUES ($quoted);`nCOMMIT;`n"))
      [IO.File]::WriteAllBytes($wrapped, $bytes.ToArray())
      sqlite3 -bail data/dev.db ".read 'data/.migrate.sql'"
      if ($LASTEXITCODE -ne 0) { throw "migrate: $name failed" }
      Write-Output "migrate: applied $name"
    }
  }
} finally {
  Remove-Item -Force -ErrorAction SilentlyContinue $wrapped
  $env:DATABASE_PATH = $previousDatabasePath
  $env:MIGRATIONS_DIR = $previousMigrationsDir
  Pop-Location
}
Write-Output "init-db: data\dev.db is ready"
