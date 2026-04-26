/// 단위 변환의 카테고리. 화면 상단 모달에 노출되는 순서와 동일하다.
enum ConverterCategory {
  angle,
  area,
  currency,
  data,
  energy,
  force,
  fuel,
  length,
  power,
  pressure,
  speed,
  temperature,
  time,
  mass,
  weight,
}

const Map<ConverterCategory, String> categoryLabels = {
  ConverterCategory.angle: '각도',
  ConverterCategory.area: '면적',
  ConverterCategory.currency: '통화',
  ConverterCategory.data: '데이터',
  ConverterCategory.energy: '에너지',
  ConverterCategory.force: '힘',
  ConverterCategory.fuel: '연료',
  ConverterCategory.length: '길이',
  ConverterCategory.power: '동력',
  ConverterCategory.pressure: '기압',
  ConverterCategory.speed: '속도',
  ConverterCategory.temperature: '기온',
  ConverterCategory.time: '시간',
  ConverterCategory.mass: '질량',
  ConverterCategory.weight: '무게',
};

/// 단위 변환의 공통 인터페이스. 카테고리별 베이스 단위로 일단 환산하고,
/// 다시 베이스에서 목적 단위로 환산하는 두 단계로 모든 변환을 처리한다.
/// 베이스: 길이=m, 면적=m², 데이터=byte, 에너지=J, 힘=N, 연료=km/L,
///         동력=W, 기압=Pa, 속도=m/s, 기온=K, 시간=s, 질량/무게=kg, 각도=°
abstract class UnitConverter {
  const UnitConverter();
  double toBase(double value);
  double fromBase(double value);
}

class LinearConverter extends UnitConverter {
  final double factor;
  const LinearConverter(this.factor);
  @override
  double toBase(double value) => value * factor;
  @override
  double fromBase(double value) => value / factor;
}

// 기온은 곱셈만으론 안 되고 오프셋(+273.15 등)이 필요해 별도 클래스.
class TemperatureConverter extends UnitConverter {
  final String code;
  const TemperatureConverter(this.code);
  @override
  double toBase(double value) {
    switch (code) {
      case 'C':
        return value + 273.15;
      case 'F':
        return (value - 32) * 5 / 9 + 273.15;
      case 'R':
        return value * 5 / 9;
      default:
        return value;
    }
  }

  @override
  double fromBase(double value) {
    switch (code) {
      case 'C':
        return value - 273.15;
      case 'F':
        return (value - 273.15) * 9 / 5 + 32;
      case 'R':
        return value * 9 / 5;
      default:
        return value;
    }
  }
}

// 연비는 km/L과 L/100km이 역수 관계라 단순 곱셈으로 처리할 수 없다.
class FuelConverter extends UnitConverter {
  final String code;
  const FuelConverter(this.code);
  @override
  double toBase(double value) {
    switch (code) {
      case 'kmL':
        return value;
      case 'L100km':
        return value == 0 ? 0 : 100 / value;
      case 'mpgUS':
        return value * 0.4251437075;
      case 'mpgUK':
        return value * 0.3540061857;
      default:
        return value;
    }
  }

  @override
  double fromBase(double value) {
    switch (code) {
      case 'kmL':
        return value;
      case 'L100km':
        return value == 0 ? 0 : 100 / value;
      case 'mpgUS':
        return value / 0.4251437075;
      case 'mpgUK':
        return value / 0.3540061857;
      default:
        return value;
    }
  }
}

class ConverterUnit {
  final String label;
  final UnitConverter converter;
  const ConverterUnit(this.label, this.converter);
}

const double _piApprox = 3.141592653589793;

const Map<ConverterCategory, List<ConverterUnit>> categoryUnits = {
  ConverterCategory.angle: [
    ConverterUnit('도', LinearConverter(1)),
    ConverterUnit('라디안', LinearConverter(180 / _piApprox)),
    ConverterUnit('그라드', LinearConverter(0.9)),
    ConverterUnit('분', LinearConverter(1 / 60)),
    ConverterUnit('초', LinearConverter(1 / 3600)),
  ],
  ConverterCategory.area: [
    ConverterUnit('m²', LinearConverter(1)),
    ConverterUnit('km²', LinearConverter(1000000)),
    ConverterUnit('cm²', LinearConverter(0.0001)),
    ConverterUnit('mm²', LinearConverter(0.000001)),
    ConverterUnit('ha', LinearConverter(10000)),
    ConverterUnit('평', LinearConverter(3.305785)),
    ConverterUnit('에이커', LinearConverter(4046.8564224)),
    ConverterUnit('ft²', LinearConverter(0.09290304)),
    ConverterUnit('in²', LinearConverter(0.00064516)),
    ConverterUnit('mi²', LinearConverter(2589988.110336)),
  ],
  ConverterCategory.data: [
    ConverterUnit('B', LinearConverter(1)),
    ConverterUnit('KB', LinearConverter(1000)),
    ConverterUnit('MB', LinearConverter(1000000)),
    ConverterUnit('GB', LinearConverter(1000000000)),
    ConverterUnit('TB', LinearConverter(1000000000000)),
    ConverterUnit('PB', LinearConverter(1000000000000000)),
    ConverterUnit('KiB', LinearConverter(1024)),
    ConverterUnit('MiB', LinearConverter(1048576)),
    ConverterUnit('GiB', LinearConverter(1073741824)),
    ConverterUnit('TiB', LinearConverter(1099511627776)),
    ConverterUnit('bit', LinearConverter(0.125)),
  ],
  ConverterCategory.energy: [
    ConverterUnit('J', LinearConverter(1)),
    ConverterUnit('kJ', LinearConverter(1000)),
    ConverterUnit('cal', LinearConverter(4.184)),
    ConverterUnit('kcal', LinearConverter(4184)),
    ConverterUnit('Wh', LinearConverter(3600)),
    ConverterUnit('kWh', LinearConverter(3600000)),
    ConverterUnit('BTU', LinearConverter(1055.05585)),
    ConverterUnit('eV', LinearConverter(1.602176634e-19)),
  ],
  ConverterCategory.force: [
    ConverterUnit('N', LinearConverter(1)),
    ConverterUnit('kN', LinearConverter(1000)),
    ConverterUnit('dyn', LinearConverter(0.00001)),
    ConverterUnit('lbf', LinearConverter(4.4482216152605)),
    ConverterUnit('kgf', LinearConverter(9.80665)),
  ],
  ConverterCategory.fuel: [
    ConverterUnit('km/L', FuelConverter('kmL')),
    ConverterUnit('L/100km', FuelConverter('L100km')),
    ConverterUnit('mpg(US)', FuelConverter('mpgUS')),
    ConverterUnit('mpg(UK)', FuelConverter('mpgUK')),
  ],
  ConverterCategory.length: [
    ConverterUnit('m', LinearConverter(1)),
    ConverterUnit('km', LinearConverter(1000)),
    ConverterUnit('cm', LinearConverter(0.01)),
    ConverterUnit('mm', LinearConverter(0.001)),
    ConverterUnit('μm', LinearConverter(0.000001)),
    ConverterUnit('nm', LinearConverter(0.000000001)),
    ConverterUnit('mi', LinearConverter(1609.344)),
    ConverterUnit('yd', LinearConverter(0.9144)),
    ConverterUnit('ft', LinearConverter(0.3048)),
    ConverterUnit('in', LinearConverter(0.0254)),
    ConverterUnit('해리', LinearConverter(1852)),
  ],
  ConverterCategory.power: [
    ConverterUnit('W', LinearConverter(1)),
    ConverterUnit('kW', LinearConverter(1000)),
    ConverterUnit('MW', LinearConverter(1000000)),
    ConverterUnit('hp', LinearConverter(745.6998715822702)),
    ConverterUnit('마력(메트릭)', LinearConverter(735.49875)),
    ConverterUnit('BTU/h', LinearConverter(0.29307107)),
  ],
  ConverterCategory.pressure: [
    ConverterUnit('Pa', LinearConverter(1)),
    ConverterUnit('hPa', LinearConverter(100)),
    ConverterUnit('kPa', LinearConverter(1000)),
    ConverterUnit('MPa', LinearConverter(1000000)),
    ConverterUnit('bar', LinearConverter(100000)),
    ConverterUnit('mbar', LinearConverter(100)),
    ConverterUnit('atm', LinearConverter(101325)),
    ConverterUnit('mmHg', LinearConverter(133.322387415)),
    ConverterUnit('Torr', LinearConverter(133.322387415)),
    ConverterUnit('psi', LinearConverter(6894.757293168)),
  ],
  ConverterCategory.speed: [
    ConverterUnit('m/s', LinearConverter(1)),
    ConverterUnit('km/h', LinearConverter(1 / 3.6)),
    ConverterUnit('mph', LinearConverter(0.44704)),
    ConverterUnit('ft/s', LinearConverter(0.3048)),
    ConverterUnit('knot', LinearConverter(0.5144444444)),
  ],
  ConverterCategory.temperature: [
    ConverterUnit('°C', TemperatureConverter('C')),
    ConverterUnit('°F', TemperatureConverter('F')),
    ConverterUnit('K', TemperatureConverter('K')),
    ConverterUnit('°R', TemperatureConverter('R')),
  ],
  ConverterCategory.time: [
    ConverterUnit('s', LinearConverter(1)),
    ConverterUnit('ms', LinearConverter(0.001)),
    ConverterUnit('μs', LinearConverter(0.000001)),
    ConverterUnit('min', LinearConverter(60)),
    ConverterUnit('h', LinearConverter(3600)),
    ConverterUnit('일', LinearConverter(86400)),
    ConverterUnit('주', LinearConverter(604800)),
    ConverterUnit('월', LinearConverter(2629800)),
    ConverterUnit('년', LinearConverter(31557600)),
  ],
  ConverterCategory.mass: [
    ConverterUnit('kg', LinearConverter(1)),
    ConverterUnit('g', LinearConverter(0.001)),
    ConverterUnit('mg', LinearConverter(0.000001)),
    ConverterUnit('μg', LinearConverter(0.000000001)),
    ConverterUnit('t', LinearConverter(1000)),
    ConverterUnit('lb', LinearConverter(0.45359237)),
    ConverterUnit('oz', LinearConverter(0.028349523125)),
    ConverterUnit('st', LinearConverter(6.35029318)),
    ConverterUnit('근', LinearConverter(0.6)),
    ConverterUnit('관', LinearConverter(3.75)),
  ],
  ConverterCategory.weight: [
    ConverterUnit('kg', LinearConverter(1)),
    ConverterUnit('g', LinearConverter(0.001)),
    ConverterUnit('mg', LinearConverter(0.000001)),
    ConverterUnit('t', LinearConverter(1000)),
    ConverterUnit('lb', LinearConverter(0.45359237)),
    ConverterUnit('oz', LinearConverter(0.028349523125)),
    ConverterUnit('st', LinearConverter(6.35029318)),
  ],
};
