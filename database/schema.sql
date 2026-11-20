-- AL MARKAZ TELECOM database schema
create extension if not exists pgcrypto;

create table if not exists public.products (
  id uuid primary key default gen_random_uuid(),
  sku text unique,
  name text not null,
  category text not null,
  description text default '',
  image_url text,
  price_sar numeric(12,2) not null check (price_sar >= 0),
  stock integer not null default 0 check (stock >= 0),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.user_roles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  role text not null check (role in ('admin'))
);

create table if not exists public.orders (
  id uuid primary key default gen_random_uuid(),
  order_number text unique not null default ('AM-' || upper(substr(replace(gen_random_uuid()::text,'-',''),1,10))),
  customer_name text not null,
  customer_email text,
  customer_phone text not null,
  shipping_address text not null,
  payment_method text not null check (payment_method in ('moyasar','bank_transfer','cod')),
  payment_status text not null default 'pending' check (payment_status in ('pending','paid','failed','refunded')),
  order_status text not null default 'new' check (order_status in ('new','confirmed','processing','shipped','delivered','cancelled')),
  subtotal_sar numeric(12,2) not null check (subtotal_sar >= 0),
  shipping_sar numeric(12,2) not null default 0 check (shipping_sar >= 0),
  total_sar numeric(12,2) not null check (total_sar >= 0),
  moyasar_payment_id text,
  created_at timestamptz not null default now()
);

create table if not exists public.order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  product_id uuid references public.products(id) on delete set null,
  product_name text not null,
  unit_price_sar numeric(12,2) not null check (unit_price_sar >= 0),
  quantity integer not null check (quantity > 0),
  line_total_sar numeric(12,2) not null check (line_total_sar >= 0)
);

create or replace function public.is_store_admin()
returns boolean language sql stable security definer
set search_path = public
as $$
  select exists (
    select 1 from public.user_roles
    where user_id = auth.uid() and role = 'admin'
  );
$$;

alter table public.products enable row level security;
alter table public.user_roles enable row level security;
alter table public.orders enable row level security;
alter table public.order_items enable row level security;

drop policy if exists "Public can view active products" on public.products;
create policy "Public can view active products" on public.products
for select to anon, authenticated using (is_active = true);

drop policy if exists "Admins manage products" on public.products;
create policy "Admins manage products" on public.products
for all to authenticated using (public.is_store_admin())
with check (public.is_store_admin());

drop policy if exists "Admins view roles" on public.user_roles;
create policy "Admins view roles" on public.user_roles
for select to authenticated using (public.is_store_admin() or user_id = auth.uid());

drop policy if exists "Admins view orders" on public.orders;
create policy "Admins view orders" on public.orders
for select to authenticated using (public.is_store_admin());

drop policy if exists "Admins update orders" on public.orders;
create policy "Admins update orders" on public.orders
for update to authenticated using (public.is_store_admin())
with check (public.is_store_admin());

drop policy if exists "Admins view order items" on public.order_items;
create policy "Admins view order items" on public.order_items
for select to authenticated using (public.is_store_admin());

-- Orders must be created by a trusted server function.
-- Never expose the service-role key in the browser.

insert into public.products (sku,name,category,description,price_sar,stock)
values
('IPH17PM-256','iPhone 17 Pro Max 256GB','هواتف آيفون','سعر تجريبي - حدّثه قبل البيع',5699,5),
('IPH17P-256','iPhone 17 Pro 256GB','هواتف آيفون','سعر تجريبي - حدّثه قبل البيع',4999,5),
('SAM-S25U-256','Samsung Galaxy S25 Ultra 256GB','هواتف سامسونج','سعر تجريبي - حدّثه قبل البيع',4899,5),
('TAB-IPAD-AIR','iPad Air 11-inch','أجهزة لوحية','سعر تجريبي - حدّثه قبل البيع',2699,3),
('ACC-USB-C-30W','USB-C Fast Charger 30W','شواحن وكابلات','سعر تجريبي - حدّثه قبل البيع',129,20)
on conflict (sku) do nothing;
