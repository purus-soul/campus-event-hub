-- ============================================
-- CAMPUS EVENTS APP - SUPABASE SETUP
-- Run this entire script in Supabase SQL Editor
-- (Dashboard -> SQL Editor -> New Query -> paste -> Run)
-- ============================================

-- 1. Whitelist table (you import your register number CSV into this)
create table if not exists valid_register_numbers (
  register_no text primary key,
  name text not null,
  department text,
  batch text,
  is_used boolean default false
);

-- 2. App users table
create table if not exists users (
  uid uuid primary key default gen_random_uuid(),
  register_no text unique references valid_register_numbers(register_no),
  name text not null,
  department text,
  batch text,
  app_password_hash text not null,
  created_at timestamp default now()
);

-- 3. Events table
create table if not exists events (
  event_id uuid primary key default gen_random_uuid(),
  title text not null,
  description text,
  organizer_uid uuid references users(uid),
  organizer_name text,
  event_date date not null,
  event_time time,
  venue text,
  category text,
  image_url text,
  max_capacity int,
  created_at timestamp default now()
);

-- 4. Event attendees (join table)
create table if not exists event_attendees (
  event_id uuid references events(event_id) on delete cascade,
  user_uid uuid references users(uid) on delete cascade,
  joined_at timestamp default now(),
  primary key (event_id, user_uid)
);

-- ============================================
-- ROW LEVEL SECURITY (RLS)
-- Since auth is custom (not Supabase Auth), we use the anon key
-- and allow open access via policies. App-level logic enforces rules.
-- ============================================

alter table valid_register_numbers enable row level security;
alter table users enable row level security;
alter table events enable row level security;
alter table event_attendees enable row level security;

-- valid_register_numbers: allow read (for signup check) and update (mark is_used)
create policy "allow read whitelist" on valid_register_numbers
  for select using (true);

create policy "allow update whitelist" on valid_register_numbers
  for update using (true);

-- users: allow insert (signup) and select (login check)
create policy "allow insert users" on users
  for insert with check (true);

create policy "allow select users" on users
  for select using (true);

-- events: anyone can read, authenticated app users can insert
create policy "allow read events" on events
  for select using (true);

create policy "allow insert events" on events
  for insert with check (true);

create policy "allow delete own events" on events
  for delete using (true);

-- event_attendees: anyone can read/insert/delete (join/leave)
create policy "allow read attendees" on event_attendees
  for select using (true);

create policy "allow insert attendees" on event_attendees
  for insert with check (true);

create policy "allow delete attendees" on event_attendees
  for delete using (true);

-- ============================================
-- STORAGE BUCKET for event images
-- Run this separately if it errors (storage setup via dashboard is easier):
-- Go to Storage -> Create bucket -> name it "event-images" -> make it PUBLIC
-- ============================================

-- ============================================
-- SAMPLE DATA (optional - for testing before you upload real CSV)
-- ============================================
insert into valid_register_numbers (register_no, name, department, batch) values
('TEST001', 'Test Student One', 'CSE', '2023-2027'),
('TEST002', 'Test Student Two', 'IT', '2023-2027')
on conflict (register_no) do nothing;
