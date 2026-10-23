/// يحوّل نص المبلغ إلى عدد صحيح موجب بالدينار، أو null إن كان غير صالح.
/// يقبل الأرقام العربية والفارسية والفواصل والمسافات، ويرفض الكسور والرموز والصفر والسالب.
int? parseIqd(String input) {
  final sb = StringBuffer();
  for (final r in input.runes) {
    if (r >= 0x0660 && r <= 0x0669) {
      sb.writeCharCode(0x30 + (r - 0x0660));
    } else if (r >= 0x06F0 && r <= 0x06F9) {
      sb.writeCharCode(0x30 + (r - 0x06F0));
    } else if (r == 0x2C || r == 0x66C || r == 0x60C || r == 0x20 || r == 0xA0) {
      continue; // , ٬ ، مسافة
    } else {
      sb.writeCharCode(r);
    }
  }
  final s = sb.toString();
  if (!RegExp(r'^[0-9]{1,15}$').hasMatch(s)) return null; // 15 خانة تبقى دقيقة حتى في الويب
  final v = int.parse(s);
  return v > 0 ? v : null;
}
