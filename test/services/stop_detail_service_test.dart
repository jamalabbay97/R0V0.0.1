import 'package:flutter_test/flutter_test.dart';
import 'package:r0/domain/services/stop_detail_service.dart';

void main() {
  group('StopDetailService', () {
    test('reads stop details from supported legacy and localized keys', () {
      expect(StopDetailService.readDetail({'Detail': 'Hydraulic leak'}),
          'Hydraulic leak');
      expect(StopDetailService.readDetail({'Détail': 'Fuite hydraulique'}),
          'Fuite hydraulique');
      expect(StopDetailService.readDetail({'D茅tail': 'Texte encodé'}),
          'Texte encodé');
      expect(
          StopDetailService.readDetail({'detail': 'lowercase'}), 'lowercase');
    });

    test('normalizes stop details to the canonical Detail key', () {
      final normalized = StopDetailService.normalizeStopDetail({
        'Arret': 'Panne',
        'Détail': 'Flexible cassé',
      });

      expect(normalized['Arret'], 'Panne');
      expect(normalized['Detail'], 'Flexible cassé');
    });
  });
}
