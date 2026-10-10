import 'package:finly/core/utils/byte_format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('small sizes are in bytes', () {
    expect(formatBytes(0), '0 B');
    expect(formatBytes(512), '512 B');
    expect(formatBytes(1023), '1023 B');
  });

  test('then in kilobytes, with a comma', () {
    expect(formatBytes(1024), '1,0 KB');
    expect(formatBytes(1536), '1,5 KB');
    expect(formatBytes(1024 * 1024 - 1), '1024,0 KB');
  });

  test('then in megabytes, with a comma', () {
    expect(formatBytes(1024 * 1024), '1,0 MB');
    expect(formatBytes(3 * 1024 * 1024 + 512 * 1024), '3,5 MB');
    expect(formatBytes(30 * 1024 * 1024), '30,0 MB');
  });
}
