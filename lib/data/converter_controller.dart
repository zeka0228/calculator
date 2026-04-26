import 'package:flutter/foundation.dart';
import 'converter_data.dart';

/// 변환 화면의 사용자 선택 상태. 카테고리·양쪽 단위 인덱스·활성 줄을 보관한다.
/// `editingSource`는 호스트 계산기의 입력값(expression)이 source/target 어느 쪽에
/// 매핑되는지를 의미하며, 화면의 주황색 밑줄 위치와 swap 동작에 모두 영향을 준다.
class ConverterController extends ChangeNotifier {
  ConverterCategory _category = ConverterCategory.length;
  int _sourceUnitIndex = 0;
  int _targetUnitIndex = 1;
  bool _editingSource = true;

  ConverterCategory get category => _category;
  int get sourceUnitIndex => _sourceUnitIndex;
  int get targetUnitIndex => _targetUnitIndex;
  bool get editingSource => _editingSource;

  void setCategory(ConverterCategory cat) {
    if (_category == cat) return;
    _category = cat;
    _sourceUnitIndex = 0;
    _targetUnitIndex = 1;
    notifyListeners();
  }

  void cycleUnit({
    required bool isSource,
    required int delta,
    required int total,
  }) {
    if (total == 0) return;
    if (isSource) {
      _sourceUnitIndex =
          ((_sourceUnitIndex + delta) % total + total) % total;
    } else {
      _targetUnitIndex =
          ((_targetUnitIndex + delta) % total + total) % total;
    }
    notifyListeners();
  }

  void setUnitIndex({required bool isSource, required int index}) {
    if (isSource) {
      if (_sourceUnitIndex == index) return;
      _sourceUnitIndex = index;
    } else {
      if (_targetUnitIndex == index) return;
      _targetUnitIndex = index;
    }
    notifyListeners();
  }

  // 단위 인덱스만 바꾸면 표시 값이 두 줄 모두 동시에 흔들린다.
  // editingSource까지 같이 뒤집어야 사용자가 입력 중이던 숫자가 자연스럽게 다른 줄로 이동한다.
  void swap() {
    final tmp = _sourceUnitIndex;
    _sourceUnitIndex = _targetUnitIndex;
    _targetUnitIndex = tmp;
    _editingSource = !_editingSource;
    notifyListeners();
  }

  void setEditingSource(bool source) {
    if (_editingSource == source) return;
    _editingSource = source;
    notifyListeners();
  }
}
