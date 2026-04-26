import 'package:flutter/foundation.dart';
import 'converter_data.dart';

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

  void setEditingSource(bool source) {
    if (_editingSource == source) return;
    _editingSource = source;
    notifyListeners();
  }
}
