import 'package:flutter_test/flutter_test.dart';
import 'package:mahameek/core/utils/phone_utils.dart';

void main() {
  test('Cross role auth phone logic test', () {
    // Tests are updated to use new PhoneUtils
    expect(PhoneUtils.normalize('0912345678'), '+249912345678');
  });
}
