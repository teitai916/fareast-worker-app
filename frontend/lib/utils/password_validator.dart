/// 6位數字密碼複雜度校驗（與後端 PasswordValidator 邏輯一致，僅作前端體驗提示）
///
/// 返回錯誤提示文字；若密碼符合要求則返回 null。
String? validatePasswordComplexity(
  String pwd, {
  String? phone,
  String? birthDate,
}) {
  if (pwd.isEmpty || pwd.length < 6) {
    return '密碼長度至少為6位';
  }
  if (!RegExp(r'^\d{6}$').hasMatch(pwd)) {
    return '密碼必須為6位純數字';
  }

  // 全同數字：000000 / 111111 / ...
  if (pwd.split('').every((c) => c == pwd[0])) {
    return '密碼過於簡單，請勿使用重複數字';
  }

  // 等差序列：012345 / 123456 / 654321 ...
  final step = pwd.codeUnitAt(1) - pwd.codeUnitAt(0);
  var isArithmetic = true;
  for (var i = 2; i < pwd.length; i++) {
    if (pwd.codeUnitAt(i) - pwd.codeUnitAt(i - 1) != step) {
      isArithmetic = false;
      break;
    }
  }
  if (isArithmetic) {
    return '密碼過於簡單，請勿使用連續數字';
  }

  // 常見弱密碼黑名單（標準檔，與後端一致）
  const weakPasswords = {
    '123456', '111111', '000000', '123123', '112233', '123321',
    '121212', '654321', '123454', '222222', '333333', '444444',
  };
  if (weakPasswords.contains(pwd)) {
    return '該密碼過於常見，請更換其他密碼';
  }

  // 與手機號後6位相同
  if (phone != null && phone.length >= 6) {
    final last6 = phone.substring(phone.length - 6);
    if (pwd == last6) {
      return '密碼不能與手機號後6位相同';
    }
  }

  // 與出生日期後6位相同（MMDDYY 或 YYMMDD）
  if (birthDate != null && birthDate.isNotEmpty) {
    final digits = birthDate.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 8) {
      final mmddyy = digits.substring(4, 6) + digits.substring(6, 8) + digits.substring(2, 4);
      final yymmdd = digits.substring(2, 4) + digits.substring(4, 6) + digits.substring(6, 8);
      if (pwd == mmddyy || pwd == yymmdd) {
        return '密碼不能與出生日期後6位相同';
      }
    } else if (digits.length == 6) {
      if (pwd == digits) {
        return '密碼不能與出生日期後6位相同';
      }
    }
  }

  return null;
}
