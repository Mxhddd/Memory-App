-- Memory Garden — free Supabase backend for supporter alerts via ntfy.
--
-- Stores ONLY: who the trainee is (display name, timezone, optional WhatsApp number for the
-- cheer button), their supporters' ntfy topics, and one row per day: done yes/no + counts.
-- No scores, answers, check-ins or health information ever reach the server.
--
-- Postgres posts to ntfy by itself (pg_net), so there is no server code to host:
--   * trigger on daily_status  → "✨ done today" to supporters (once per day)
--   * pg_cron every 15 minutes → "🌙 not yet today" at each supporter's chosen local time
--                                 and a Sunday-evening weekly summary
--
-- Setup: Supabase dashboard → Database → Extensions: enable pg_net and pg_cron.
--        Authentication → Sign In / Providers: enable "Allow anonymous sign-ins".
--        Then paste this whole file into SQL Editor and run it.

create extension if not exists pg_net;
create extension if not exists pg_cron;

-- ---------------------------------------------------------------- tables

create table if not exists public.trainees (
  id              uuid primary key references auth.users (id) on delete cascade,
  display_name    text not null default 'Friend',
  mascot_name     text not null default 'Mochi',
  theme           text not null default 'midnightRaccoon',
  timezone        text not null default 'Asia/Karachi',
  nudge_whatsapp  text,                         -- digits only, for wa.me links
  paused_until    date,                         -- holidays: no "not yet" alerts until this date
  created_at      timestamptz not null default now()
);

create table if not exists public.supporters (
  id                  uuid primary key default gen_random_uuid(),
  trainee_id          uuid not null references public.trainees (id) on delete cascade,
  label               text not null,
  ntfy_topic          text not null unique check (ntfy_topic ~ '^mg-[a-z0-9]{20,}$'),
  notify_on_done      boolean not null default true,
  weekly_summary      boolean not null default true,
  missed_check_local  time not null default '20:30',
  last_missed_alert   date,
  last_weekly_alert   date,
  created_at          timestamptz not null default now()
);

create table if not exists public.daily_status (
  trainee_id    uuid not null references public.trainees (id) on delete cascade,
  day           date not null,
  done          boolean not null default false,
  sessions      int not null default 0,
  streak_weeks  int not null default 0,
  done_alerted  boolean not null default false,
  updated_at    timestamptz not null default now(),
  primary key (trainee_id, day)
);

-- ---------------------------------------------------------------- row-level security

alter table public.trainees     enable row level security;
alter table public.supporters   enable row level security;
alter table public.daily_status enable row level security;

drop policy if exists "own trainee row" on public.trainees;
create policy "own trainee row" on public.trainees
  for all using (id = auth.uid()) with check (id = auth.uid());

drop policy if exists "own supporters" on public.supporters;
create policy "own supporters" on public.supporters
  for all using (trainee_id = auth.uid()) with check (trainee_id = auth.uid());

drop policy if exists "own status" on public.daily_status;
create policy "own status" on public.daily_status
  for all using (trainee_id = auth.uid()) with check (trainee_id = auth.uid());

-- ---------------------------------------------------------------- helpers

create or replace function public.urlencode(input text) returns text
language plpgsql immutable as $$
declare
  result text := '';
  b int;
  bytes bytea := convert_to(coalesce(input, ''), 'UTF8');
begin
  for i in 0 .. length(bytes) - 1 loop
    b := get_byte(bytes, i);
    if (b between 48 and 57) or (b between 65 and 90) or (b between 97 and 122) or b in (45, 46, 95, 126) then
      result := result || chr(b);
    else
      result := result || '%' || upper(lpad(to_hex(b), 2, '0'));
    end if;
  end loop;
  return result;
end $$;

-- One ntfy message, optionally with a "view" action (the free WhatsApp cheer/nudge button).
create or replace function public.notify_ntfy(topic text, title text, message text, tags text[],
                                              action_label text default null, action_url text default null)
returns void language plpgsql security definer set search_path = public, net as $$
declare
  body jsonb := jsonb_build_object('topic', topic, 'title', title, 'message', message, 'tags', to_jsonb(tags));
begin
  if action_url is not null then
    body := body || jsonb_build_object('actions',
      jsonb_build_array(jsonb_build_object('action', 'view', 'label', action_label, 'url', action_url)));
  end if;
  perform net.http_post(
    url := 'https://ntfy.sh/',
    body := body,
    headers := '{"Content-Type": "application/json"}'::jsonb
  );
end $$;

create or replace function public.wa_link(number text, msg text) returns text
language sql immutable as $$
  select case when coalesce(number, '') = '' then null
              else 'https://wa.me/' || regexp_replace(number, '\D', '', 'g') || '?text=' || public.urlencode(msg) end
$$;

-- ---------------------------------------------------------------- "done" alerts (trigger)

create or replace function public.on_daily_status() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  t public.trainees%rowtype;
  s public.supporters%rowtype;
  raccoon boolean;
begin
  if new.done and not new.done_alerted then
    select * into t from public.trainees where id = new.trainee_id;
    raccoon := t.theme = 'midnightRaccoon';
    for s in select * from public.supporters where trainee_id = new.trainee_id and notify_on_done loop
      perform public.notify_ntfy(
        s.ntfy_topic,
        case when raccoon then '✨ ' || t.display_name || '''s den got cozier today'
             else t.display_name || ' finished today''s practice' end,
        case when raccoon then 'Quest complete! Send a little cheer?'
             else 'All done for today. A kind word goes a long way.' end,
        array[case when raccoon then 'raccoon' else 'sparkles' end],
        'Send a cheer 💌',
        public.wa_link(t.nudge_whatsapp, case when raccoon then 'Proud of you and ' || t.mascot_name || ' 💜' else 'Well done today! 🌷' end)
      );
    end loop;
    new.done_alerted := true;
  end if;
  new.updated_at := now();
  return new;
end $$;

drop trigger if exists daily_status_done on public.daily_status;
create trigger daily_status_done before insert or update on public.daily_status
  for each row execute function public.on_daily_status();

-- ---------------------------------------------------------------- "not yet" + weekly (cron)

create or replace function public.check_supporter_alerts() returns void
language plpgsql security definer set search_path = public as $$
declare
  r record;
  local_now timestamp;
  local_day date;
  days_done int;
  raccoon boolean;
begin
  for r in
    select s.*, t.display_name, t.mascot_name, t.theme, t.timezone, t.nudge_whatsapp, t.paused_until
    from public.supporters s join public.trainees t on t.id = s.trainee_id
  loop
    local_now := now() at time zone r.timezone;
    local_day := local_now::date;
    raccoon := r.theme = 'midnightRaccoon';

    -- "Not yet today" — once per day, after the chosen local time, unless paused or done.
    if local_now::time >= r.missed_check_local
       and r.last_missed_alert is distinct from local_day
       and (r.paused_until is null or r.paused_until < local_day)
       and not exists (select 1 from public.daily_status d
                       where d.trainee_id = r.trainee_id and d.day = local_day and d.done) then
      perform public.notify_ntfy(
        r.ntfy_topic,
        case when raccoon then '🌙 ' || r.mascot_name || ' is still waiting for ' || r.display_name
             else r.display_name || ' hasn''t practised yet today' end,
        'A gentle nudge might help — five minutes is plenty.',
        array['crescent_moon'],
        'Send a nudge 💌',
        public.wa_link(r.nudge_whatsapp, case when raccoon then r.mascot_name || ' misses you 🦝 five minutes tonight?' else 'Thinking of you — a few minutes of practice today? 🌷' end)
      );
      update public.supporters set last_missed_alert = local_day where id = r.id;
    end if;

    -- Sunday ~19:00 local: days practised this week (count only).
    if r.weekly_summary
       and extract(isodow from local_now) = 7
       and local_now::time >= time '19:00'
       and r.last_weekly_alert is distinct from local_day then
      select count(*) into days_done from public.daily_status d
        where d.trainee_id = r.trainee_id and d.done and d.day > local_day - 7 and d.day <= local_day;
      perform public.notify_ntfy(
        r.ntfy_topic,
        '📅 ' || r.display_name || '''s week',
        days_done || ' of 7 days practised this week' || case when days_done >= 4 then ' — weekly goal reached! 🎉' else '.' end,
        array['calendar']
      );
      update public.supporters set last_weekly_alert = local_day where id = r.id;
    end if;
  end loop;
end $$;

select cron.unschedule('memory-garden-alerts') where exists (select 1 from cron.job where jobname = 'memory-garden-alerts');
select cron.schedule('memory-garden-alerts', '*/15 * * * *', $$select public.check_supporter_alerts()$$);

-- ---------------------------------------------------------------- delete my data

create or replace function public.delete_me() returns void
language plpgsql security definer set search_path = public, auth as $$
begin
  delete from auth.users where id = auth.uid();   -- cascades to trainees, supporters, daily_status
end $$;

revoke all on function public.delete_me() from public, anon;
grant execute on function public.delete_me() to authenticated;
revoke all on function public.check_supporter_alerts() from public, anon, authenticated;
revoke all on function public.notify_ntfy(text, text, text, text[], text, text) from public, anon, authenticated;
