import 'package:finly/core/offline/offline_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late OfflineStatus status;
  late int notified;

  setUp(() {
    status = OfflineStatus();
    notified = 0;
    status.addListener(() => notified++);
  });

  test('starts online, with nothing to say', () {
    expect(status.isOffline, isFalse);
    expect(status.isBackOnline, isFalse);
    expect(status.cachedSince, isNull);
    expect(status.refreshEpoch, 0);
  });

  group('markOffline', () {
    test('goes offline and tells the listeners', () {
      status.markOffline();

      expect(status.isOffline, isTrue);
      expect(notified, 1);
    });

    test('says nothing the second time', () {
      status.markOffline();
      status.markOffline();

      expect(notified, 1);
    });
  });

  group('markServedFromCache', () {
    final tenAm = DateTime(2026, 10, 9, 10);
    final twoPm = DateTime(2026, 10, 9, 14);

    test('goes offline and remembers how old the copy is', () {
      status.markServedFromCache(twoPm);

      expect(status.isOffline, isTrue);
      expect(status.cachedSince, twoPm);
    });

    test('keeps the oldest copy shown', () {
      status.markServedFromCache(twoPm);
      status.markServedFromCache(tenAm);
      status.markServedFromCache(twoPm);

      expect(status.cachedSince, tenAm);
    });

    test('tells the listeners only when something changed', () {
      status.markServedFromCache(tenAm);
      status.markServedFromCache(twoPm);
      status.markServedFromCache(tenAm);

      expect(notified, 1);
    });

    test('tells again when an older copy is shown', () {
      status.markServedFromCache(twoPm);
      status.markServedFromCache(tenAm);

      expect(notified, 2);
    });
  });

  group('markOnline', () {
    test('does nothing when it was online', () {
      status.markOnline();

      expect(status.isBackOnline, isFalse);
      expect(notified, 0);
    });

    test('after being offline, says the internet is back and forgets the copy', () {
      status.markServedFromCache(DateTime(2026, 10, 9, 10));

      status.markOnline();

      expect(status.isOffline, isFalse);
      expect(status.isBackOnline, isTrue);
      expect(status.cachedSince, isNull);
    });

    test('stays "back online" until the person refreshes', () {
      status.markOffline();
      status.markOnline();
      status.markOnline();

      expect(status.isBackOnline, isTrue);
    });

    test('going offline again takes the "back online" away', () {
      status.markOffline();
      status.markOnline();

      status.markOffline();

      expect(status.isBackOnline, isFalse);
      expect(status.isOffline, isTrue);
    });
  });

  group('refresh', () {
    test('asks the app to be built again and takes the "back online" away', () {
      status.markOffline();
      status.markOnline();

      status.refresh();

      expect(status.refreshEpoch, 1);
      expect(status.isBackOnline, isFalse);
    });

    test('counts each time', () {
      status.refresh();
      status.refresh();

      expect(status.refreshEpoch, 2);
    });
  });
}
