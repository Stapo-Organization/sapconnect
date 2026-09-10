import 'package:flutter_test/flutter_test.dart';
import 'package:zooboxi_app/features/account/data/account_models.dart';
import 'package:zooboxi_app/features/checkout/presentation/checkout_screen.dart';

/// An إكسبريس basket is quoted against ONE branch — its stock, its two-hour
/// clock, its courier. Sending it outside that branch's area is not a slower
/// delivery, it is a different warehouse where the quantities the customer
/// chose may not exist. The store decides which addresses qualify; this is
/// what the app owes that answer: never choose a blocked one for them, and
/// never silently drop one from the book.

Address _address(String id, {bool serves = true, String reason = '', bool isDefault = false}) =>
    Address(
      id: id,
      name: 'محمد',
      phone: '0500000000',
      city: 'الرياض',
      addressLine: 'شارع ما',
      serves: serves,
      servesReason: reason,
      isDefault: isDefault,
    );

void main() {
  group('what the store says about an address', () {
    test('a store too old to judge is read as no objection', () {
      final address = Address.fromJson(const {
        'id': 'a1',
        'name': 'محمد',
        'phone': '05',
        'city': 'الرياض',
        'address_line': 'شارع',
      });
      expect(address.serves, isTrue);
      expect(address.servesReason, '');
    });

    test('a refusal carries its reason', () {
      final address = Address.fromJson(const {
        'id': 'a1',
        'name': 'محمد',
        'phone': '05',
        'city': 'الرياض',
        'address_line': 'شارع',
        'serves': false,
        'serves_reason': 'out_of_zone',
      });
      expect(address.serves, isFalse);
      expect(address.servesReason, 'out_of_zone');
    });

    test('an explicit yes is a yes', () {
      final address = Address.fromJson(const {
        'id': 'a1',
        'name': 'محمد',
        'phone': '05',
        'city': 'الرياض',
        'address_line': 'شارع',
        'serves': true,
      });
      expect(address.serves, isTrue);
    });
  });

  group('which address checkout opens on', () {
    test('the one the whole shop has been quoting', () {
      expect(
        preselectedAddressId(
          addresses: [_address('home', isDefault: true), _address('work')],
          defaultAddress: _address('home', isDefault: true),
          activeId: 'work',
        ),
        'work',
      );
    });

    test('never one this basket cannot be sent to', () {
      expect(
        preselectedAddressId(
          addresses: [_address('work', serves: false, reason: 'out_of_zone'), _address('home')],
          defaultAddress: null,
          activeId: 'work',
        ),
        'home',
        reason: 'the quoted address is out of the branch\'s area',
      );
    });

    test('not even when it is the default', () {
      final blocked = _address('home', serves: false, reason: 'out_of_zone', isDefault: true);
      expect(
        preselectedAddressId(
          addresses: [blocked, _address('work')],
          defaultAddress: blocked,
          activeId: null,
        ),
        'work',
      );
    });

    test('an address with no pin is not a candidate either', () {
      expect(
        preselectedAddressId(
          addresses: [_address('old', serves: false, reason: 'no_pin'), _address('new')],
          defaultAddress: null,
          activeId: 'old',
        ),
        'new',
      );
    });

    test('nothing that works is null, not a wrong guess', () {
      expect(
        preselectedAddressId(
          addresses: [
            _address('home', serves: false, reason: 'out_of_zone'),
            _address('work', serves: false, reason: 'out_of_zone'),
          ],
          defaultAddress: _address('home', serves: false, reason: 'out_of_zone'),
          activeId: 'home',
        ),
        isNull,
      );
    });

    test('an empty book is null', () {
      expect(
        preselectedAddressId(addresses: const [], defaultAddress: null, activeId: null),
        isNull,
      );
    });

    test('with nothing quoted it falls to the default, then to the first', () {
      final home = _address('home', isDefault: true);
      expect(
        preselectedAddressId(
          addresses: [_address('work'), home],
          defaultAddress: home,
          activeId: null,
        ),
        'home',
      );
      expect(
        preselectedAddressId(
          addresses: [_address('work'), _address('other')],
          defaultAddress: null,
          activeId: null,
        ),
        'work',
      );
    });
  });
}
