-- workflows: регистрация только по коду приглашения.
-- Выполните один раз: Supabase → SQL Editor → New query → вставьте всё → Run.
-- Уже созданные аккаунты продолжают работать, проверка касается только новых регистраций.
--
-- Как это работает: приложение и сайт передают код в метаданных регистрации,
-- триггер на auth.users проверяет его на сервере и списывает одно использование.
-- Без подходящего кода Supabase не создаёт пользователя, и обойти это из приложения
-- или его форка нельзя: проверка живёт в вашей базе.

create table if not exists public.invites (
  code       text        primary key,                 -- вида WF-ABCD-EFGH
  note       text,                                    -- для кого код, видно только вам
  max_uses   int         not null default 1 check (max_uses > 0),
  uses       int         not null default 0,
  expires_at timestamptz,                             -- пусто = бессрочно
  used_by    uuid[]      not null default '{}',
  created_at timestamptz not null default now()
);

-- Таблицу не видит никто, кроме вас в панели Supabase: RLS включён, правил доступа нет.
alter table public.invites enable row level security;
revoke all on table public.invites from anon, authenticated;

-- Нормализация: регистр, пробелы и дефисы не важны.
create or replace function public.invite_norm(t text) returns text
language sql immutable as $$ select upper(regexp_replace(coalesce(t, ''), '[^A-Za-z0-9]', '', 'g')) $$;

create or replace function public.check_invite() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  c text := public.invite_norm(new.raw_user_meta_data->>'invite');
begin
  update public.invites
     set uses = uses + 1, used_by = used_by || new.id
   where public.invite_norm(code) = c
     and c <> ''
     and uses < max_uses
     and (expires_at is null or expires_at > now());
  if not found then
    raise exception 'invite_invalid';
  end if;
  -- сам код в профиле пользователя не храним
  new.raw_user_meta_data := new.raw_user_meta_data - 'invite';
  return new;
end $$;

drop trigger if exists require_invite on auth.users;
create trigger require_invite
  before insert on auth.users
  for each row execute function public.check_invite();

-- Генератор кодов. Буквы без похожих друг на друга (нет O/0, I/1).
create or replace function public.make_invites(
  how_many int default 1,
  uses_each int default 1,
  valid_days int default null,
  for_whom text default null
) returns setof text
language plpgsql security definer set search_path = public as $$
declare
  abc constant text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  b bytea;
  s text;
  i int;
  k int;
begin
  for i in 1..how_many loop
    loop
      b := uuid_send(gen_random_uuid()) || uuid_send(gen_random_uuid());
      s := '';
      -- байты 6 и 8 у UUID v4 частично фиксированы, их пропускаем
      foreach k in array array[0,1,2,3,4,5,7,9] loop
        s := s || substr(abc, (get_byte(b, k) % 32) + 1, 1);
      end loop;
      s := 'WF-' || substr(s, 1, 4) || '-' || substr(s, 5, 4);
      exit when not exists (select 1 from public.invites where code = s);
    end loop;
    insert into public.invites (code, note, max_uses, expires_at)
    values (s, for_whom, uses_each,
            case when valid_days is null then null else now() + make_interval(days => valid_days) end);
    return next s;
  end loop;
end $$;

-- Из приложения эти функции вызвать нельзя, только из SQL Editor.
revoke execute on function public.make_invites(int, int, int, text) from public, anon, authenticated;
revoke execute on function public.invite_norm(text) from public, anon, authenticated;

-- ============================================================
-- Шпаргалка (выполнять в SQL Editor по одной команде)
--
-- Один код для друга:
--   select * from make_invites(1, 1, null, 'Саша');
-- Пять одноразовых кодов, действуют 7 дней:
--   select * from make_invites(5, 1, 7);
-- Один код на 10 человек (например, для группы):
--   select * from make_invites(1, 10, 30, 'группа ИВТ-21');
--
-- Посмотреть коды и кто зарегистрировался:
--   select i.code, i.note, i.uses, i.max_uses, i.expires_at,
--          array(select u.email from auth.users u where u.id = any(i.used_by)) as emails
--     from invites i order by i.created_at desc;
--
-- Отключить код:
--   update invites set max_uses = greatest(uses, 1), expires_at = now() where code = 'WF-XXXX-XXXX';
--
-- Временно открыть регистрацию для всех (и закрыть обратно):
--   alter table auth.users disable trigger require_invite;
--   alter table auth.users enable trigger require_invite;
--
-- Важно: кнопка «Add user» в панели Supabase тоже проходит через проверку.
-- Чтобы завести аккаунт вручную, создайте код и зарегистрируйтесь с ним в приложении.
-- ============================================================
