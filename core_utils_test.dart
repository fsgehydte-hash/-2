import 'package:flutter_test/flutter_test.dart';
import 'package:rayhana_app/core/idgen.dart';
import 'package:rayhana_app/core/iqd_input.dart';
import 'package:rayhana_app/core/time_util.dart';

void main() {
  group('parseIqd', () {
    test('accepts whole numbers, separators and Arabic digits', () {
      expect(parseIqd('150000'), 150000);
      expect(parseIqd('1,250,000'), 1250000);
      expect(parseIqd('١٥٠٠٠٠'), 150000);
      expect(parseIqd(' 2 500 '), 2500);
    });
    test('rejects decimals, zero, negatives, text and empty', () {
      for (final bad in ['1500.5', '0', '-5', 'abc', '', '12a', '1e5', '١٢.٥']) {
        expect(parseIqd(bad), isNull, reason: bad);
      }
    });
    test('rejects values beyond safe precision', () {
      expect(parseIqd('1234567890123456'), isNull);
      expect(parseIqd('999999999999999'), 999999999999999);
    });
  });

  group('time', () {
    test('business date follows Baghdad time (UTC+3)', () {
      expect(businessDateOf(DateTime.utc(2026, 10, 15, 20, 59)), '2026-10-15');
      expect(businessDateOf(DateTime.utc(2026, 10, 15, 21, 0)), '2026-10-16');
    });
    test('format and date arithmetic', () {
      expect(formatBaghdad(DateTime.utc(2026, 10, 15, 21, 5)), '2026-10-16 00:05');
      expect(shiftBusinessDate('2026-03-01', -1), '2026-02-28');
      expect(shiftBusinessDate('2026-12-31', 1), '2027-01-01');
      expect(monthStart('2026-10-22'), '2026-10-01');
    });
  });

  test('uuidV4 has valid shape and is unique', () {
    final re = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$');
    final ids = {for (var i = 0; i < 500; i++) uuidV4()};
    expect(ids.length, 500);
    expect(ids.every(re.hasMatch), isTrue);
  });
}
