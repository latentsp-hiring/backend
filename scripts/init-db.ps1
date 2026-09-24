# Builds data\dev.db exactly the way the grader builds its database:
# contract\schema.sql, then contract\seed.sql, then migrations\*.sql in name order,
# each in its own transaction. Needs sqlite3.exe on PATH.
$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "..")
if (-not (Get-Command sqlite3 -ErrorAction SilentlyContinue)) { throw "init-db: install the sqlite3 CLI first" }
New-Item -ItemType Directory -Force -Path data | Out-Null
Remove-Item -Force -ErrorAction SilentlyContinue data\dev.db, data\dev.db-wal, data\dev.db-shm
Get-Content contract\schema.sql -Raw | sqlite3 -bail data\dev.db
Get-Content contract\seed.sql -Raw | sqlite3 -bail data\dev.db
Get-ChildItem migrations\*.sql -ErrorAction SilentlyContinue | Sort-Object Name | ForEach-Object {
  $sql = Get-Content $_.FullName -Raw
  if ($sql -match '(?im)^\s*(BEGIN(\s+(DEFERRED|IMMEDIATE|EXCLUSIVE))?(\s+TRANSACTION)?\s*;|COMMIT(\s+TRANSACTION)?\s*;|END\s+TRANSACTION|ROLLBACK)') {
    throw "migrate: $($_.Name): remove BEGIN/COMMIT/ROLLBACK; each file already runs in its own transaction"
  }
  "BEGIN;`n$sql`nCOMMIT;" | sqlite3 -bail data\dev.db
  if ($LASTEXITCODE -ne 0) { throw "migrate: $($_.Name) failed" }
  Write-Output "migrate: applied $($_.Name)"
}
Write-Output "init-db: data\dev.db is ready"
