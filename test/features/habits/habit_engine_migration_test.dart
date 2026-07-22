import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String migration;
  late String compatibilityMigration;

  setUpAll(() {
    migration = File(
      'supabase/migrations/202607220001_habit_engine.sql',
    ).readAsStringSync().toLowerCase();
    compatibilityMigration = File(
      'supabase/migrations/202607220002_habit_engine_compatibility.sql',
    ).readAsStringSync().toLowerCase();
  });

  test('habit engine migration is additive and preserves existing data', () {
    expect(migration, isNot(contains('drop table')));
    expect(migration, isNot(contains('truncate ')));
    expect(migration, isNot(contains('disable row level security')));
    expect(migration, contains('add column if not exists category'));
    expect(migration, contains('add column if not exists completion_date'));
  });

  test('habit and completion ownership remain protected by RLS', () {
    expect(
      migration,
      contains('alter table public.habits enable row level security'),
    );
    expect(
      migration,
      contains(
        'alter table public.habit_completions enable row level security',
      ),
    );
    expect(migration, contains('using (auth.uid() = user_id)'));
    expect(migration, contains('with check (auth.uid() = user_id)'));
    expect(migration, isNot(contains('using (true)')));
    expect(migration, isNot(contains('with check (true)')));
  });

  test('completion and XP mutations are server-owned and idempotent', () {
    expect(
      migration,
      contains('habit_completions_habit_completion_date_unique'),
    );
    expect(
      migration,
      contains('on conflict (habit_id, completion_date) do nothing'),
    );
    expect(migration, contains('set_habit_completion_v2'));
    expect(migration, contains('greatest(0, total_xp - v_awarded)'));
    expect(
      migration,
      contains(
        'revoke insert, update, delete on public.habit_completions from authenticated',
      ),
    );
  });

  test('server evaluates active days in each habit timezone', () {
    expect(migration, contains("now() at time zone h.timezone"));
    expect(migration, contains('extract(isodow'));
    expect(migration, contains('any(h.active_weekdays)'));
    expect(migration, contains('habit is not active today'));
  });

  test('compatibility repair never overwrites an edited starter habit', () {
    expect(compatibilityMigration, isNot(contains('drop table')));
    expect(compatibilityMigration, isNot(contains('truncate ')));
    expect(compatibilityMigration, contains('ensure_onboarding_habits'));
    expect(compatibilityMigration, contains('do nothing;'));
    expect(
      compatibilityMigration,
      contains('delete from public.habit_completions c'),
    );
    expect(
      compatibilityMigration,
      contains('c.completion_date = v_completion_date'),
    );
  });
}
