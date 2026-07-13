import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/features/trip_detail/trip_print_data.dart';
import 'package:tripline/models/entry.dart';

void main() {
  test('formatTravelLine 支援 submode、legacy type 與未知 type', () {
    expect(
      formatTravelLine(const Travel(type: 'transit', submode: 'hsr', min: 90)),
      '高鐵 · 90 分',
    );
    expect(
      formatTravelLine(const Travel(type: 'subway', min: 12)),
      '捷運 · 12 分',
    );
    expect(
      formatTravelLine(const Travel(type: 'gondola', min: 5)),
      'gondola · 5 分',
    );
    expect(
      formatTravelLine(const Travel(type: 'driving', min: 20)),
      '開車 · 20 分',
    );
    expect(
      formatTravelLine(const Travel(type: 'transit', sameplace: true)),
      '不需計算路程',
    );
  });
}
