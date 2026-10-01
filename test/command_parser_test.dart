import 'package:flutter_test/flutter_test.dart';
import 'package:tailor_shop_manager/voice/command_parser.dart';
import 'package:tailor_shop_manager/voice/phonetics.dart';

void main() {
  const latin = [
    VoiceCustomerRef(1, 'Jahanzeb'),
    VoiceCustomerRef(2, 'Ahmed'),
    VoiceCustomerRef(3, 'Salman'),
    VoiceCustomerRef(5, 'Mazhar'),
    VoiceCustomerRef(6, 'Ali'),
  ];
  const sindhi = [
    VoiceCustomerRef(1, 'جهانزيب'),
    VoiceCustomerRef(2, 'احمد'),
    VoiceCustomerRef(3, 'سلمان'),
  ];

  void expectCmd(
    String text,
    List<VoiceCustomerRef> customers,
    int id,
    VoiceIntent intent,
  ) {
    final cmd = VoiceCommandParser.parse(text, customers);
    expect(cmd.best?.customer.id, id, reason: text);
    expect(cmd.intent, intent, reason: text);
  }

  group('Roman Sindhi commands', () {
    test('maap / measurement', () {
      expectCmd('Jahanzeb ji maap', latin, 1, VoiceIntent.showMeasurements);
      expectCmd('Jahanzeb ji maap dikha', latin, 1, VoiceIntent.showMeasurements);
      expectCmd('Ahmed ji measurement', latin, 2, VoiceIntent.showMeasurements);
      expectCmd('Ali ji maap', latin, 6, VoiceIntent.showMeasurements);
    });

    test('order', () {
      expectCmd('Jahanzeb jo order kholo', latin, 1, VoiceIntent.openOrders);
      expectCmd('Salman jo order kholo', latin, 3, VoiceIntent.openOrders);
    });

    test('balance', () {
      expectCmd('Jahanzeb te ketro paiso baqi aa', latin, 1, VoiceIntent.showBalance);
      expectCmd('Salman te ketro paiso baqi ahe', latin, 3, VoiceIntent.showBalance);
    });
  });

  group('Urdu/Hindi style commands (original examples)', () {
    test('ka/ki forms', () {
      expectCmd('Jahanzeb ka order kholo', latin, 1, VoiceIntent.openOrders);
      expectCmd('Ahmed ka measurement dikhao', latin, 2, VoiceIntent.showMeasurements);
      expectCmd('Salman ka kitna paisa baqi hai', latin, 3, VoiceIntent.showBalance);
    });
  });

  group('Name matching', () {
    test('split and misspelled names', () {
      expectCmd('Jahan zeb ji maap dikha', latin, 1, VoiceIntent.showMeasurements);
      expectCmd('jehan zaib jo order kholo', latin, 1, VoiceIntent.openOrders);
    });

    test('a name that sounds like a command word still wins as the name', () {
      expectCmd('Mazhar ka measure dikhao', latin, 5, VoiceIntent.showMeasurements);
    });

    test('only a name', () {
      expectCmd('salman', latin, 3, VoiceIntent.none);
    });

    test('unknown customer returns no match', () {
      final cmd = VoiceCommandParser.parse('Bilal ka order kholo', latin);
      expect(cmd.hasCustomer, isFalse);
      expect(cmd.intent, VoiceIntent.openOrders);
    });

    test('same first name gives an ambiguous result', () {
      const two = [
        VoiceCustomerRef(10, 'Ahmed Khan'),
        VoiceCustomerRef(11, 'Ahmed Ali'),
      ];
      final cmd = VoiceCommandParser.parse('Ahmed ji maap', two);
      expect(cmd.isAmbiguous, isTrue);
    });

    test('exact customer wins over longer names', () {
      const two = [
        VoiceCustomerRef(10, 'Ahmed Khan'),
        VoiceCustomerRef(11, 'Ahmed'),
      ];
      final cmd = VoiceCommandParser.parse('Ahmed ji maap', two);
      expect(cmd.isAmbiguous, isFalse);
      expect(cmd.best?.customer.id, 11);
    });
  });

  group('Sindhi script', () {
    test('commands in Sindhi letters, saved names in Latin', () {
      expectCmd('جهانزيب جو آرڊر ڪولو', latin, 1, VoiceIntent.openOrders);
      expectCmd('جهانزيب جي ماپ ڏيکاريو', latin, 1, VoiceIntent.showMeasurements);
      expectCmd('جهانزيب تي ڪيترو پيسو باقي آهي', latin, 1, VoiceIntent.showBalance);
      expectCmd('احمد جي ماپ', latin, 2, VoiceIntent.showMeasurements);
      expectCmd('علي جي ماپ', latin, 6, VoiceIntent.showMeasurements);
    });

    test('Roman commands, names saved in Sindhi letters', () {
      expectCmd('Jahanzeb jo order kholo', sindhi, 1, VoiceIntent.openOrders);
      expectCmd('Ahmed ji maap', sindhi, 2, VoiceIntent.showMeasurements);
      expectCmd('Salman te ketro paiso baqi aa', sindhi, 3, VoiceIntent.showBalance);
    });
  });

  group('Hindi script', () {
    test('Devanagari output of a Hindi recogniser', () {
      expectCmd('जहांज़ेब का ऑर्डर खोलो', latin, 1, VoiceIntent.openOrders);
      expectCmd('सलमान का कितना पैसा बाकी है', latin, 3, VoiceIntent.showBalance);
      expectCmd('अहमद की माप दिखाओ', latin, 2, VoiceIntent.showMeasurements);
    });
  });

  group('Recogniser mistakes', () {
    test('mis-heard "measurement"', () {
      expectCmd('Ahmed ji meezarment', latin, 2, VoiceIntent.showMeasurements);
      expectCmd('احمد جي ميجرمنٽ', latin, 2, VoiceIntent.showMeasurements);
    });

    test('parseBest picks the alternative that finds a customer', () {
      final cmd = VoiceCommandParser.parseBest(
        ['Johan jeb jo order', 'Jahanzeb jo order kholo'],
        latin,
      );
      expect(cmd.best?.customer.id, 1);
      expect(cmd.intent, VoiceIntent.openOrders);
    });
  });

  group('Phonetics', () {
    test('skeleton is the same across scripts', () {
      expect(Phonetics.skeleton('Jahanzeb'), 'jnsb');
      expect(Phonetics.skeleton('جهانزيب'), 'jnsb');
      expect(Phonetics.skeleton('जहांज़ेब'), 'jnsb');
      expect(Phonetics.skeleton('Ahmed'), Phonetics.skeleton('احمد'));
      expect(Phonetics.skeleton('Salman'), Phonetics.skeleton('سلمان'));
    });
  });
}
