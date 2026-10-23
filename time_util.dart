/// الوقت يُخزَّن موحّداً (UTC) ويُعرض ويُحسب يوم العمل بتوقيت بغداد (UTC+3 دون تغيير صيفي).
const _baghdad = Duration(hours: 3);

String _two(int n) => n.toString().padLeft(2, '0');

DateTime nowUtc() => DateTime.now().toUtc();

String businessDateOf(DateTime utc) {
  final d = utc.toUtc().add(_baghdad);
  return '${d.year.toString().padLeft(4, '0')}-${_two(d.month)}-${_two(d.day)}';
}

String todayBusinessDate() => businessDateOf(nowUtc());

String formatBaghdad(DateTime utc) {
  final d = utc.toUtc().add(_baghdad);
  return '${businessDateOf(utc)} ${_two(d.hour)}:${_two(d.minute)}';
}

String shiftBusinessDate(String date, int days) {
  final p = date.split('-');
  final d = DateTime.utc(int.parse(p[0]), int.parse(p[1]), int.parse(p[2])).add(Duration(days: days));
  return '${d.year.toString().padLeft(4, '0')}-${_two(d.month)}-${_two(d.day)}';
}

String monthStart(String date) => '${date.substring(0, 8)}01';
