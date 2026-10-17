-- Задачник: таблица для зашифрованных записей.
-- Выполните один раз: Supabase → SQL Editor → New query → вставьте всё → Run.

create table if not exists public.items (
  user_id    uuid        not null default auth.uid() references auth.users(id) on delete cascade,
  id         text        not null check (char_length(id) between 1 and 80),
  iv         text,                                   -- случайный вектор шифрования
  data       text check (data is null or char_length(data) <= 200000), -- шифротекст AES-GCM
  deleted    boolean     not null default false,
  updated_at timestamptz not null default now(),
  primary key (user_id, id)
);

create index if not exists items_user_updated on public.items (user_id, updated_at);

-- Время изменения ставит сервер, а не устройство
create or replace function public.items_touch() returns trigger
language plpgsql set search_path = '' as $$
begin
  new.updated_at := clock_timestamp();
  return new;
end $$;

drop trigger if exists items_touch on public.items;
create trigger items_touch before insert or update on public.items
  for each row execute function public.items_touch();

-- Каждый видит и меняет только свои строки
alter table public.items enable row level security;

drop policy if exists "items_select_own" on public.items;
drop policy if exists "items_insert_own" on public.items;
drop policy if exists "items_update_own" on public.items;
drop policy if exists "items_delete_own" on public.items;

create policy "items_select_own" on public.items for select to authenticated
  using ((select auth.uid()) = user_id);
create policy "items_insert_own" on public.items for insert to authenticated
  with check ((select auth.uid()) = user_id);
create policy "items_update_own" on public.items for update to authenticated
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy "items_delete_own" on public.items for delete to authenticated
  using ((select auth.uid()) = user_id);

-- Анонимным посетителям доступа нет совсем
revoke all on public.items from anon;
grant select, insert, update, delete on public.items to authenticated;
