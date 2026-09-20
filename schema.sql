-- Dispatch app schema
-- Run this once in your Supabase project's SQL Editor (Project → SQL Editor → New query)

create table if not exists orders (
  id bigint generated always as identity primary key,
  invoice text not null,
  note text not null default '',
  delivery boolean not null default false,
  urgent boolean not null default false,
  paid boolean not null default false,
  arrived boolean not null default false,
  status text not null default 'pending' check (status in ('pending', 'completed')),
  created_at timestamptz not null default now(),
  completed_at timestamptz
);

-- If you already created this table before the "paid"/"arrived" columns existed,
-- run these once to add them (safe to run even if the columns are already there):
alter table orders add column if not exists paid boolean not null default false;
alter table orders add column if not exists arrived boolean not null default false;

-- Helpful index for the common "pending orders, most urgent/newest first" query
create index if not exists orders_status_created_idx on orders (status, created_at desc);

-- Row Level Security
alter table orders enable row level security;

-- Table of specific email addresses allowed to use the app. Used instead of a
-- domain check (like '%@company.com') because a shared provider domain such as
-- gmail.com, yahoo.com, or outlook.com would let in anyone in the world with an
-- account there, not just your team.
create table if not exists allowed_emails (
  email text primary key
);

alter table allowed_emails enable row level security;

-- A signed-in user may only ever check for their OWN email in this table (never
-- list or see anyone else's), which is enough for the app to confirm they're
-- authorized without exposing the full staff list to every logged-in user.
drop policy if exists "Users can check their own email" on allowed_emails;
create policy "Users can check their own email" on allowed_emails
  for select
  using (auth.role() = 'authenticated' and email = (auth.jwt() ->> 'email'));

-- Add every team member's exact email address here. Edit this list and re-run
-- just this statement whenever someone joins or leaves — everything else in this
-- file only needs to be run once. Safe to re-run (skips emails already present).
insert into allowed_emails (email) values
  ('alexanderz.freeziatrading@gmail.com'),
  ('yeseniazhen@gmail.com'),
  ('freeziatradingllc23@gmail.com'),
  ('freeziatradingllc@gmail.com'),
  ('freeziawarehouse@gmail.com')
on conflict (email) do nothing;

-- Only signed-in users whose verified email appears in allowed_emails can read or write.
drop policy if exists "Allow all access" on orders;
drop policy if exists "Company domain access" on orders;
drop policy if exists "Allowlisted users access" on orders;
create policy "Allowlisted users access" on orders
  for all
  using (
    auth.role() = 'authenticated'
    and exists (select 1 from allowed_emails ae where ae.email = (auth.jwt() ->> 'email'))
  )
  with check (
    auth.role() = 'authenticated'
    and exists (select 1 from allowed_emails ae where ae.email = (auth.jwt() ->> 'email'))
  );

-- Enable realtime updates so all connected browsers see new/updated/deleted orders live
alter publication supabase_realtime add table orders;