-- Dispatch app schema
-- Run this once in your Supabase project's SQL Editor (Project → SQL Editor → New query)

create table if not exists orders (
  id bigint generated always as identity primary key,
  invoice text not null,
  note text not null default '',
  delivery boolean not null default false,
  urgent boolean not null default false,
  status text not null default 'pending' check (status in ('pending', 'completed')),
  created_at timestamptz not null default now(),
  completed_at timestamptz
);

-- Helpful index for the common "pending orders, most urgent/newest first" query
create index if not exists orders_status_created_idx on orders (status, created_at desc);

-- Row Level Security
alter table orders enable row level security;

-- NOTE: this policy allows any holder of the anon/public key to read and write freely.
-- That's fine for an internal tool or a prototype, but before exposing this publicly
-- you should add real authentication (Supabase Auth) and scope this policy to
-- authenticated users, e.g. `using (auth.role() = 'authenticated')`.
drop policy if exists "Allow all access" on orders;
create policy "Allow all access" on orders
  for all
  using (true)
  with check (true);

-- Enable realtime updates so all connected browsers see new/updated/deleted orders live
alter publication supabase_realtime add table orders;
