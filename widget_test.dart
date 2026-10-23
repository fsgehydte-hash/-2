import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rayhana_app/app/app.dart';
import 'package:rayhana_app/app/providers.dart';
import 'package:rayhana_app/data/demo_data.dart';
import 'package:rayhana_app/data/demo_entries.dart';
import 'package:rayhana_app/features/auth/login_screen.dart';

Widget _app(DemoStore store) => ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(DemoAuthRepository(store)),
        entriesRepositoryProvider.overrideWithValue(DemoEntriesRepository()),
        deviceRepositoryProvider.overrideWithValue(DemoDeviceRepository()),
        usersRepositoryProvider.overrideWithValue(DemoUsersRepository(store)),
      ],
      child: const RayhanaApp(),
    );

Future<void> _pump(WidgetTester t, DemoStore store) async {
  t.view.physicalSize = const Size(1200, 900);
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.reset);
  await t.pumpWidget(_app(store));
  await t.pumpAndSettle();
}

Future<void> _login(WidgetTester t, String email, [String? pw]) async {
  await t.enterText(find.byKey(const Key('email')), email);
  await t.enterText(find.byKey(const Key('password')), pw ?? DemoStore.sessionPassword);
  await t.tap(find.byKey(const Key('signin')));
  await t.pumpAndSettle();
}

void main() {
  testWidgets('login screen is Arabic and right-to-left by default', (t) async {
    await _pump(t, DemoStore());
    expect(find.text('ريحانة للتسوق المنزلي'), findsOneWidget);
    expect(find.text('تسجيل الدخول'), findsOneWidget);
    expect(Directionality.of(t.element(find.byType(LoginScreen))), TextDirection.rtl);
  });

  testWidgets('wrong password shows an error and stays on login', (t) async {
    await _pump(t, DemoStore());
    await _login(t, 'owner@demo.local', 'wrong');
    expect(find.text('البريد الإلكتروني أو كلمة المرور غير صحيحة'), findsOneWidget);
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('cashier (create-only) sees no amounts but gets action buttons', (t) async {
    await _pump(t, DemoStore());
    await _login(t, 'cashier@demo.local');
    expect(find.text('إيرادات اليوم'), findsNothing);
    expect(find.text('مصروفات اليوم'), findsNothing);
    expect(find.text('صافي الإيرادات المسجلة بعد المصروفات'), findsNothing);
    expect(find.text('تسجيل إيراد'), findsOneWidget);
    expect(find.text('المستخدمون والصلاحيات'), findsNothing);
  });

  testWidgets('viewer with view_today sees revenue only', (t) async {
    await _pump(t, DemoStore());
    await _login(t, 'viewer@demo.local');
    expect(find.text('إيرادات اليوم'), findsOneWidget);
    expect(find.text('مصروفات اليوم'), findsNothing);
    expect(find.text('صافي الإيرادات المسجلة بعد المصروفات'), findsNothing);
  });

  testWidgets('owner sees everything and the users page', (t) async {
    await _pump(t, DemoStore());
    await _login(t, 'owner@demo.local');
    expect(find.text('إيرادات اليوم'), findsOneWidget);
    expect(find.text('مصروفات اليوم'), findsOneWidget);
    expect(find.text('صافي الإيرادات المسجلة بعد المصروفات'), findsOneWidget);
    await t.tap(find.text('المستخدمون والصلاحيات'));
    await t.pumpAndSettle();
    expect(find.text('أمين صندوق تجريبي'), findsOneWidget);
  });

  testWidgets('owner grants permission and the user sees it after signing in again', (t) async {
    final store = DemoStore();
    await _pump(t, store);
    await _login(t, 'owner@demo.local');
    await t.tap(find.text('المستخدمون والصلاحيات'));
    await t.pumpAndSettle();
    await t.tap(find.text('مطّلع تجريبي'));
    await t.pumpAndSettle();
    final sw = find.widgetWithText(SwitchListTile, 'مشاهدة المصروفات');
    await t.ensureVisible(sw);
    await t.pumpAndSettle();
    await t.tap(sw);
    await t.pumpAndSettle();
    expect(store.users.firstWhere((u) => u.id == 'u-viewer').perms.length, 2);
  });

  testWidgets('sign out returns to login', (t) async {
    await _pump(t, DemoStore());
    await _login(t, 'viewer@demo.local');
    await t.tap(find.text('الإعدادات'));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('signout')));
    await t.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('cashier records a revenue through the form; owner sees the exact total', (t) async {
    await _pump(t, DemoStore());
    await _login(t, 'cashier@demo.local');
    await t.tap(find.byKey(const Key('dash-add-revenue')));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const Key('amount')), '150000');
    await t.tap(find.byKey(const Key('save')));
    await t.pumpAndSettle();
    expect(find.textContaining('R-000001'), findsOneWidget);
    // أمين الصندوق لا يرى الإجماليات
    expect(find.text('إيرادات اليوم'), findsNothing);
    await t.tap(find.text('الإعدادات'));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('signout')));
    await t.pumpAndSettle();
    await _login(t, 'owner@demo.local');
    expect(find.text('150,000 د.ع'), findsWidgets); // إيراد اليوم والصافي
  });

  testWidgets('invalid amount is rejected by the form and nothing is saved', (t) async {
    await _pump(t, DemoStore());
    await _login(t, 'cashier@demo.local');
    await t.tap(find.byKey(const Key('dash-add-revenue')));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const Key('amount')), '1500.5');
    await t.tap(find.byKey(const Key('save')));
    await t.pumpAndSettle();
    expect(find.text('أدخل مبلغاً صحيحاً (أعداد صحيحة أكبر من صفر)'), findsOneWidget);
    expect(find.textContaining('R-'), findsNothing);
  });

  testWidgets('expense list shows recorder and reference for the owner', (t) async {
    await _pump(t, DemoStore());
    await _login(t, 'owner@demo.local');
    await t.tap(find.byKey(const Key('dash-add-expense')));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const Key('amount')), '40000');
    await t.enterText(find.byKey(const Key('description')), 'نقل بضاعة');
    await t.tap(find.byKey(const Key('save')));
    await t.pumpAndSettle();
    await t.tap(find.text('المصروفات'));
    await t.pumpAndSettle();
    expect(find.textContaining('E-000001'), findsWidgets); // الرسالة المؤقتة + سطر السجل
    expect(find.textContaining('مالك تجريبي'), findsWidgets);
    expect(find.textContaining('نقل بضاعة'), findsOneWidget);
    expect(find.text('40,000 د.ع'), findsWidgets);
  });
}
