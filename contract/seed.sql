-- Fixture rows the grader inserts after schema.sql and before /app/migrate.
-- The seeded Argyle account is the one the mock's /simulate/connect-seeded fills.
INSERT INTO users (id, email, name, argyle_user_id)
VALUES ('test-user-1', 'candidate@example.com', 'Test User',
        '019b41cf-9ab5-7a93-b6ef-263a6d29b82d');

INSERT INTO user_tokens (id, user_id, provider, external_connection_id)
VALUES ('test-token-1', 'test-user-1', 'ARGYLE', '019b41cf-9ab5-7a93-b6ef-263a6d29b82d');

INSERT INTO incomes (id, user_id, name, source, provider_id, external_source_id,
                     external_account_id, status)
VALUES ('test-income-1', 'test-user-1', 'Acme Corp', 'FORM_W2', 'ARGYLE', 'argyle-item-123',
        '019b41d0-7a84-72db-beab-4f62f8e86ce4', 'ACTIVE');
