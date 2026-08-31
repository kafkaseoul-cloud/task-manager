-- 배너 및 단말 관리 — Supabase 초기 설정 스크립트
-- Supabase 대시보드 > SQL Editor 에서 이 스크립트 전체를 한 번 실행하면 됩니다.
-- (개인정보나 사내 데이터가 들어있지 않으므로 그대로 커밋해도 안전합니다.)

-- 1. 데이터 테이블: 앱 전체 상태를 JSON 한 덩어리로 저장한다 (localStorage와 같은 구조).
create table if not exists app_state (
  id smallint primary key,
  data jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

-- 2. 초기 빈 상태 한 행을 만들어 둔다 (id=1 고정, 앱이 항상 이 한 행만 읽고 쓴다).
insert into app_state (id, data)
values (1, '{"billboard":{"items":[],"rounds":[]},"device":{"items":[],"rounds":[]},"launch":{"items":[]}}'::jsonb)
on conflict (id) do nothing;

-- 3. Row Level Security 활성화 + 익명(anon) 키로 읽기/쓰기를 모두 허용.
--    이 앱은 별도의 로그인 기능이 없으므로, 링크와 anon key를 아는 사람은 누구나
--    데이터를 읽고 쓸 수 있다. 사내 링크만 공유하는 용도로 충분하지만, 더 강한
--    접근 제어가 필요하면 Supabase Auth를 추가해 정책을 사용자 단위로 좁힐 수 있다.
alter table app_state enable row level security;

drop policy if exists "anon can read app_state" on app_state;
create policy "anon can read app_state"
  on app_state for select
  to anon
  using (true);

drop policy if exists "anon can update app_state" on app_state;
create policy "anon can update app_state"
  on app_state for update
  to anon
  using (true)
  with check (true);

drop policy if exists "anon can insert app_state" on app_state;
create policy "anon can insert app_state"
  on app_state for insert
  to anon
  with check (true);

-- 4. RLS 정책만으로는 부족하다 — Postgres는 테이블 자체에 대한 권한(GRANT)이 먼저 있어야
--    그 다음에 RLS 정책이 "어느 행"을 허용할지 판단한다. Supabase 대시보드 UI로 테이블을
--    만들면 이 GRANT가 자동으로 붙지만, SQL로 직접 만들 때는 명시적으로 줘야 한다.
grant usage on schema public to anon;
grant select, insert, update on app_state to anon;

-- 5. 실시간 동기화(Realtime) 활성화 — 한 사람이 저장하면 다른 사람 화면에도
--    자동으로 반영되도록 UPDATE 이벤트를 브로드캐스트한다.
alter publication supabase_realtime add table app_state;
