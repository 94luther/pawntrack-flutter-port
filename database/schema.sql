create table if not exists sheet_snapshots (
  id bigserial primary key,
  source text not null,
  synced_at timestamptz,
  payload jsonb not null,
  created_at timestamptz not null default now()
);

create table if not exists loans (
  id bigserial primary key,
  sheet_name text not null,
  row_number integer not null,
  client_name text,
  item_pawned text,
  loan_amount numeric(14,2) default 0,
  interest_amount numeric(14,2) default 0,
  total_payback numeric(14,2) default 0,
  amount_paid numeric(14,2) default 0,
  remaining_balance numeric(14,2) default 0,
  due_date date,
  date_given date,
  location text,
  risk_score integer default 0,
  payload jsonb,
  updated_at timestamptz not null default now(),
  unique (sheet_name, row_number)
);

create table if not exists inventory_items (
  id bigserial primary key,
  sheet_name text not null default 'Company Owned Items',
  row_number integer not null,
  product text,
  category text,
  listed_amount numeric(14,2) default 0,
  pawned_amount numeric(14,2) default 0,
  sell_amount numeric(14,2) default 0,
  profit numeric(14,2) default 0,
  status text,
  payload jsonb,
  updated_at timestamptz not null default now(),
  unique (sheet_name, row_number)
);

create table if not exists inventory_sales (
  id bigserial primary key,
  sheet_name text not null,
  row_number integer not null,
  product text,
  category text,
  listed_amount numeric(14,2) default 0,
  pawned_amount numeric(14,2) default 0,
  expected_repayment numeric(14,2) default 0,
  sell_amount numeric(14,2) default 0,
  profit numeric(14,2) default 0,
  sale_date date,
  date_given date,
  days_held integer,
  payload jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (sheet_name, row_number)
);

create table if not exists payments (
  id bigserial primary key,
  sheet_name text not null,
  row_number integer not null,
  client_name text,
  amount numeric(14,2) not null,
  due_date date,
  payload jsonb,
  created_at timestamptz not null default now()
);

create table if not exists sync_jobs (
  id bigserial primary key,
  kind text not null,
  status text not null default 'pending',
  payload jsonb not null,
  attempts integer not null default 0,
  last_error text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists customers (
  id bigserial primary key,
  customer_code text unique,
  full_name text not null,
  omang text,
  phone_number text,
  emergency_contact text,
  address_area text,
  customer_photo_url text,
  id_photo_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists pawn_items (
  id bigserial primary key,
  customer_id bigint references customers(id),
  loan_id bigint references loans(id),
  product text,
  category text,
  serial_or_imei text,
  proof_of_ownership text,
  item_photo_urls text[],
  testing_checklist jsonb,
  storage_location text,
  status text not null default 'pawned',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists risk_scores (
  id bigserial primary key,
  customer_id bigint references customers(id),
  loan_id bigint references loans(id),
  score integer not null,
  band text not null,
  reasons jsonb,
  calculated_at timestamptz not null default now()
);

create table if not exists staff_users (
  id bigserial primary key,
  display_name text not null,
  role text,
  active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists audit_log (
  id bigserial primary key,
  staff_user_id bigint references staff_users(id),
  entity_type text not null,
  entity_id text,
  action text not null,
  correction_reason text,
  before_payload jsonb,
  after_payload jsonb,
  created_at timestamptz not null default now()
);

create table if not exists whatsapp_messages (
  id bigserial primary key,
  customer_id bigint references customers(id),
  loan_id bigint references loans(id),
  phone_number text,
  message text not null,
  status text not null default 'draft',
  sent_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists voice_commands (
  id bigserial primary key,
  staff_user_id bigint references staff_users(id),
  transcript text not null,
  parsed_action text,
  status text not null default 'received',
  payload jsonb,
  created_at timestamptz not null default now()
);
