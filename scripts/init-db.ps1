# Builds data\dev.db the way the grader builds its database: contract\schema.sql,
# then contract\seed.sql, then migrations\*.sql in byte order of their names, each in
# its own transaction, with the same checks as the base image's default migrate.
# Needs sqlite3.exe on PATH.
#
# Usage: .\scripts\init-db.ps1 [--force]
# Refuses to replace an existing data\dev.db unless you pass --force.
#
# If you replaced /app/migrate, set $env:MIGRATE to the path of your migrate script.
# It runs with sh (for example Git Bash's), with DATABASE_PATH and MIGRATIONS_DIR set.
$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "..")

$force = $false
if ($args.Count -eq 1 -and ($args[0] -eq "--force" -or $args[0] -eq "-Force")) {
  $force = $true
} elseif ($args.Count -ne 0) {
  [Console]::Error.WriteLine("usage: .\scripts\init-db.ps1 [--force]")
  exit 2
}

if (-not (Get-Command sqlite3 -ErrorAction SilentlyContinue)) { throw "init-db: install the sqlite3 CLI first" }

if ((Test-Path data\dev.db) -and -not $force) {
  [Console]::Error.WriteLine(@'
init-db: data\dev.db already exists, so nothing was changed.
Rebuilding it deletes every row in it, including the webhook deliveries and sync
runs your service recorded. That traffic is part of what you commit.
To apply one new migration to the existing database instead, run:
  sqlite3 -bail data/dev.db "BEGIN;" ".read migrations/NNNN_description.sql" "COMMIT;"
To delete it and rebuild from scratch anyway, run: .\scripts\init-db.ps1 --force
'@)
  exit 1
}

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
  foreach ($name in $names) {
    $lines = Get-Content "migrations/$name"
    if ($lines -match '(?i)^\s*(BEGIN(\s+(DEFERRED|IMMEDIATE|EXCLUSIVE))?(\s+TRANSACTION)?\s*;|COMMIT(\s+TRANSACTION)?\s*;|END\s+TRANSACTION|ROLLBACK)') {
      throw "migrate: ${name}: remove BEGIN/COMMIT/ROLLBACK; each file already runs in its own transaction"
    }
    if ($lines -match '^\s*\.') {
      throw "migrate: ${name}: remove sqlite3 dot-commands; only SQL statements are allowed"
    }
    sqlite3 -bail data/dev.db "BEGIN;" ".read 'migrations/$name'" "COMMIT;"
    if ($LASTEXITCODE -ne 0) { throw "migrate: $name failed" }
    Write-Output "migrate: applied $name"
  }
}
Write-Output "init-db: data\dev.db is ready"
