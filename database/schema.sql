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
