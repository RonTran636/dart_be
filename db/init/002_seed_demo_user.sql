-- Demo account for local development: demo@example.com / Password123!
-- Remove this file before deploying to production.

INSERT INTO users (email, name, password_hash)
VALUES ('demo@example.com', 'Demo User', '$2a$10$4V0X97sVwpI0JWXUA1chgedDJJ0CHu/Yd23vDwCvVryoHkZsFyWq2')
ON CONFLICT (email) DO NOTHING;
