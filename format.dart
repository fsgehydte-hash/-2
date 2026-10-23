/// تنسيق الدينار العراقي: أعداد صحيحة بفواصل آلاف، بلا كسور.
String formatIqd(int value, {required bool arabic}) {
  final neg = value < 0;
  final s = value.abs().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return '${neg ? '-' : ''}$b ${arabic ? 'د.ع' : 'IQD'}';
}
