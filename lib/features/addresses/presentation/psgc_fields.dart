import 'dart:async';

import 'package:flutter/material.dart';

import '../data/psgc_loader.dart';

typedef LocalityValuesChanged = void Function(Map<String, String> values);

class PsgcFields extends StatefulWidget {
  const PsgcFields({
    super.key,
    required this.onChange,
    this.onHydrated,
    this.initialValues = const {},
    this.fieldErrors = const {},
    this.loader,
  });
  final LocalityValuesChanged onChange;
  final LocalityValuesChanged? onHydrated;
  final Map<String, String> initialValues;
  final Map<String, String> fieldErrors;
  final PsgcLoader? loader;

  @override
  State<PsgcFields> createState() => _PsgcFieldsState();
}

class _PsgcFieldsState extends State<PsgcFields> {
  static const _ncrCode = '1300000000';
  static const _ncrChoice = 'compat:ncr';
  static const _ncrLabel = 'National Capital Region (NCR)';
  static const _localityKeys = [
    'region',
    'province',
    'city_municipality',
    'barangay',
  ];

  late final PsgcLoader _loader = widget.loader ?? PsgcLoader();
  late final Map<String, TextEditingController> _controllers = {
    for (final key in _localityKeys)
      key: TextEditingController(text: widget.initialValues[key] ?? ''),
  };
  late final Map<String, FocusNode> _focusNodes = {
    for (final key in _localityKeys) key: FocusNode(),
  };
  late final Map<String, GlobalKey<FormFieldState<String>>> _fieldKeys = {
    for (final key in _localityKeys) key: GlobalKey<FormFieldState<String>>(),
  };
  final Map<String, String> _searchText = {};
  final Map<String, String> _selected = {};
  List<PsgcRegion> _regions = const [];
  PsgcRegion? _region;
  PsgcDataset? _dataset;
  PsgcNode? _province, _city, _barangay;
  bool _unsupportedDirectCity = false;
  bool _indexLoaded = false;
  bool _datasetLoaded = false;
  bool _loading = false;
  bool _settingText = false;
  String? _error;
  int _epoch = 0;

  @override
  void initState() {
    super.initState();
    for (final key in _localityKeys) {
      _searchText[key] = _controllers[key]!.text;
      _controllers[key]!.addListener(() => _controllerChanged(key));
    }
    unawaited(_loadInitialOptions());
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    for (final node in _focusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  Future<void> _loadInitialOptions() async {
    final epoch = ++_epoch;
    setState(() {
      _loading = true;
      _error = null;
      _datasetLoaded = false;
    });
    try {
      final regions = await _loader.regions();
      if (!mounted || epoch != _epoch) return;
      _regions = regions;
      _indexLoaded = true;
      final region = _matchRegion(_controllers['region']!.text);
      if (region != null) {
        _region = region;
        _selected['region'] = region.code;
        _setText('region', region.name);
        _fieldKeys['region']!.currentState?.didChange(region.code);
        final dataset = await _loader.dataset(region);
        if (!mounted || epoch != _epoch) return;
        _dataset = dataset;
        _datasetLoaded = true;
        _hydrateDescendants(dataset);
        widget.onHydrated?.call(_displayValues);
      }
    } catch (_) {
      if (mounted && epoch == _epoch) {
        _indexLoaded = false;
        _datasetLoaded = false;
        _error = 'Address choices are unavailable. Retry before saving.';
      }
    } finally {
      if (mounted && epoch == _epoch) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _loadDataset(PsgcRegion region) async {
    final epoch = ++_epoch;
    setState(() {
      _loading = true;
      _error = null;
      _datasetLoaded = false;
    });
    try {
      final dataset = await _loader.dataset(region);
      if (!mounted || epoch != _epoch) return;
      _dataset = dataset;
      _datasetLoaded = true;
    } catch (_) {
      if (mounted && epoch == _epoch) {
        _datasetLoaded = false;
        _error = 'This region’s address choices are unavailable. Retry before saving.';
      }
    } finally {
      if (mounted && epoch == _epoch) setState(() => _loading = false);
    }
  }

  Future<void> _retry() async {
    final region = _region;
    if (_indexLoaded && region != null) {
      await _loadDataset(region);
    } else {
      await _loadInitialOptions();
    }
  }

  void _hydrateDescendants(PsgcDataset dataset) {
    final savedProvince = _controllers['province']!.text;
    if (_region?.code == _ncrCode && _sameName(savedProvince, _ncrLabel)) {
      _selected['province'] = _ncrChoice;
      _setText('province', _ncrLabel);
      _fieldKeys['province']!.currentState?.didChange(_ncrChoice);
    } else {
      _province = _matchNode(dataset.provinces, savedProvince);
      if (_province != null) {
        _selected['province'] = _province!.code;
        _setText('province', _province!.name);
        _fieldKeys['province']!.currentState?.didChange(_province!.code);
      }
    }

    final savedCity = _controllers['city_municipality']!.text;
    _city = _matchNode(_cityNodes, savedCity);
    if (_city != null) {
      _selected['city_municipality'] = _city!.code;
      _setText('city_municipality', _city!.name);
      _fieldKeys['city_municipality']!.currentState?.didChange(_city!.code);
      _unsupportedDirectCity =
          _isRegionDirect(_city!) && _region?.code != _ncrCode;
      if (_unsupportedDirectCity) {
        _province = null;
        _selected.remove('province');
        _fieldKeys['province']!.currentState?.didChange(null);
      }
      _barangay = _matchNode(
        _dataset!.barangaysUnder(_city!),
        _controllers['barangay']!.text,
      );
      if (_barangay != null) {
        _selected['barangay'] = _barangay!.code;
        _setText('barangay', _barangay!.name);
        _fieldKeys['barangay']!.currentState?.didChange(_barangay!.code);
      }
    }
  }

  List<PsgcNode> get _cityNodes {
    final dataset = _dataset;
    if (dataset == null) return const [];
    final provinceCities = _province == null
        ? const <PsgcNode>[]
        : dataset.citiesUnder(_province);
    final seen = provinceCities.map((node) => node.code).toSet();
    return [
      ...provinceCities,
      ...dataset.directCities.where((node) => !seen.contains(node.code)),
    ];
  }

  List<_LocalityChoice> _choices(String key) {
    switch (key) {
      case 'region':
        return [
          for (final region in _regions)
            _LocalityChoice(region.code, region.name),
        ];
      case 'province':
        if (_region?.code == _ncrCode) {
          return const [_LocalityChoice(_ncrChoice, _ncrLabel)];
        }
        return [
          for (final node in _dataset?.provinces ?? const <PsgcNode>[])
            _LocalityChoice(node.code, node.name, node: node),
        ];
      case 'city_municipality':
        return [
          for (final node in _cityNodes)
            _LocalityChoice(
              node.code,
              node.name,
              node: node,
              menuLabel: _isRegionDirect(node) && _region?.code != _ncrCode
                  ? '${node.name} — regional direct city'
                  : node.name,
            ),
        ];
      case 'barangay':
        return [
          for (final node
              in _city == null || _dataset == null
                  ? const <PsgcNode>[]
                  : _dataset!.barangaysUnder(_city!))
            _LocalityChoice(node.code, node.name, node: node),
        ];
      default:
        return const [];
    }
  }

  bool _enabled(String key) {
    if (key == 'region') return _indexLoaded && !_loading;
    if (!_datasetLoaded || _loading) return false;
    if (key == 'province') return _choices(key).isNotEmpty;
    if (key == 'city_municipality') return _choices(key).isNotEmpty;
    if (key == 'barangay') return _choices(key).isNotEmpty;
    return false;
  }

  String? _validate(String key, String? value) {
    if (key == 'region' && !_indexLoaded) {
      return 'Retry the bundled address choices before saving.';
    }
    if (key != 'region' && !_datasetLoaded) {
      return 'Load the selected Region’s address choices before saving.';
    }
    if (key == 'province' && _unsupportedDirectCity) {
      return 'No supported Province mapping is available for this city.';
    }
    if (key == 'province' &&
        _region?.code != _ncrCode &&
        (_dataset?.provinces.isEmpty ?? true)) {
      return 'This Region has no supported Province mapping.';
    }
    if (value == null || !_selected.containsKey(key)) {
      final requiredLabel = switch (key) {
        'region' => 'Region',
        'province' => 'Province',
        'city_municipality' => 'City or Municipality',
        _ => 'Barangay',
      };
      return widget.fieldErrors[key] ??
          'Choose a listed $requiredLabel option.';
    }
    return widget.fieldErrors[key];
  }

  String? _helper(String key) {
    if (key == 'region') {
      return 'Open the list or type to filter, then choose a Region.';
    }
    if (key == 'province' && _unsupportedDirectCity) {
      return 'This direct city has no Province entry in PSGC. Saving is unavailable.';
    }
    if (key == 'province' && _region?.code == _ncrCode) {
      return 'Choose the documented NCR compatibility option; it is not a PSGC Province.';
    }
    if (key == 'province' &&
        _datasetLoaded &&
        (_dataset?.provinces.isEmpty ?? true) &&
        (_dataset?.directCities.isNotEmpty ?? false)) {
      return 'This Region has direct cities without Province mappings; saving those addresses is unavailable.';
    }
    if (key == 'city_municipality' &&
        _choices(key).any((choice) => choice.menuLabel != choice.label)) {
      return 'Regional direct cities without a Province mapping cannot be saved.';
    }
    if (key == 'barangay') return 'Choose a Barangay within the selected city.';
    return 'Open the list or type to filter, then choose an option.';
  }

  void _controllerChanged(String key) {
    final text = _controllers[key]!.text;
    if (_settingText || _searchText[key] == text) return;
    _searchText[key] = text;
    _selected.remove(key);
    _fieldKeys[key]!.currentState?.didChange(null);
    if (key == 'region') {
      _epoch++;
      _region = null;
      _dataset = null;
      _datasetLoaded = false;
      _province = _city = _barangay = null;
      _unsupportedDirectCity = false;
      _error = null;
      _clearDescendantsAfter('region');
    } else if (key == 'province') {
      _province = _city = _barangay = null;
      _unsupportedDirectCity = false;
      _clearDescendantsAfter('province');
    } else if (key == 'city_municipality') {
      _city = _barangay = null;
      _unsupportedDirectCity = false;
      _clearDescendantsAfter('city_municipality');
    } else {
      _barangay = null;
    }
    setState(() {});
    widget.onChange(_displayValues);
  }

  void _clearDescendantsAfter(String key) {
    final start = _localityKeys.indexOf(key) + 1;
    for (final child in _localityKeys.skip(start)) {
      _selected.remove(child);
      _fieldKeys[child]!.currentState?.didChange(null);
      _setText(child, '');
    }
  }

  Future<void> _select(
    String key,
    String? value,
    FormFieldState<String> field,
  ) async {
    if (value == null) {
      _controllerChangedFromClearSelection(key, field);
      return;
    }
    final choice = _choices(key)
        .where((item) => item.value == value)
        .firstOrNull;
    if (choice == null) return;
    if (_selected[key] == value) {
      field.didChange(value);
      return;
    }

    if (key == 'region') {
      final region = _regions.where((item) => item.code == value).firstOrNull;
      if (region == null) return;
      _region = region;
      _dataset = null;
      _datasetLoaded = false;
      _province = _city = _barangay = null;
      _unsupportedDirectCity = false;
      _clearDescendantsAfter('region');
      _selected[key] = value;
      _setText(key, region.name);
      field.didChange(value);
      _error = null;
      setState(() {});
      widget.onChange(_displayValues);
      await _loadDataset(region);
      return;
    }

    if (key == 'province') {
      _city = _barangay = null;
      _unsupportedDirectCity = false;
      _clearDescendantsAfter('province');
      _province = choice.node;
      _selected[key] = value;
      _setText(key, choice.label);
      field.didChange(value);
    } else if (key == 'city_municipality') {
      _barangay = null;
      _clearDescendantsAfter('city_municipality');
      _city = choice.node;
      final isDirect = _city != null && _isRegionDirect(_city!);
      _unsupportedDirectCity = isDirect && _region?.code != _ncrCode;
      if (isDirect && _region?.code != _ncrCode) {
        _province = null;
        _selected.remove('province');
        _fieldKeys['province']!.currentState?.didChange(null);
        _setText('province', '');
      }
      _selected[key] = value;
      _setText(key, choice.label);
      field.didChange(value);
    } else {
      _barangay = choice.node;
      _selected[key] = value;
      _setText(key, choice.label);
      field.didChange(value);
    }
    setState(() {});
    widget.onChange(_displayValues);
  }

  void _controllerChangedFromClearSelection(
    String key,
    FormFieldState<String> field,
  ) {
    if (!_selected.containsKey(key)) return;
    _selected.remove(key);
    field.didChange(null);
    if (key == 'region') {
      _epoch++;
      _region = null;
      _dataset = null;
      _datasetLoaded = false;
      _province = _city = _barangay = null;
      _unsupportedDirectCity = false;
      _clearDescendantsAfter('region');
    } else if (key == 'province') {
      _province = _city = _barangay = null;
      _unsupportedDirectCity = false;
      _clearDescendantsAfter('province');
    } else if (key == 'city_municipality') {
      _city = _barangay = null;
      _unsupportedDirectCity = false;
      _clearDescendantsAfter('city_municipality');
    }
    setState(() {});
    widget.onChange(_displayValues);
  }

  void _setText(String key, String value) {
    final controller = _controllers[key]!;
    if (controller.text == value) {
      _searchText[key] = value;
      return;
    }
    _settingText = true;
    controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
    _searchText[key] = value;
    _settingText = false;
  }

  Map<String, String> get _displayValues => Map.unmodifiable({
    for (final key in _localityKeys) key: _controllers[key]!.text,
  });

  bool _isRegionDirect(PsgcNode node) =>
      _dataset?.directCities.any((city) => city.code == node.code) ?? false;

  PsgcRegion? _matchRegion(String value) {
    for (final region in _regions) {
      if (_sameName(region.name, value)) return region;
    }
    return null;
  }

  PsgcNode? _matchNode(Iterable<PsgcNode> nodes, String value) {
    for (final node in nodes) {
      if (_sameName(node.name, value)) return node;
    }
    return null;
  }

  bool _sameName(String left, String right) =>
      left.trim().toLowerCase() == right.trim().toLowerCase();

  Future<void> _handleSelection(
    String key,
    String? value,
    FormFieldState<String> field,
  ) => _select(key, value, field);

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children:
        [
              const Text('Locality'),
              const Text(
                'Choose each locality from its searchable list. Typed text is a search only.',
              ),
              if (_loading)
                const LinearProgressIndicator(
                  semanticsLabel: 'Loading bundled address choices',
                ),
              if (_error != null) ...[
                Semantics(liveRegion: true, child: Text(_error!)),
                TextButton(
                  onPressed: _retry,
                  child: const Text('Retry address choices'),
                ),
              ],
              for (final key in _localityKeys) _field(key, _label(key)),
              if (_unsupportedDirectCity)
                const Text(
                  'This regional direct city has no supported Province mapping. The saved address requires a Province, so saving is unavailable.',
                ),
            ]
            .map(
              (child) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: child,
              ),
            )
            .toList(),
  );

  String _label(String key) => switch (key) {
    'region' => 'Region',
    'province' => 'Province',
    'city_municipality' => 'City / Municipality',
    _ => 'Barangay',
  };

  Widget _field(String key, String label) => FormField<String>(
    key: _fieldKeys[key],
    initialValue: _selected[key],
    validator: (value) => _validate(key, value),
    builder: (field) => DropdownMenu<String>(
      controller: _controllers[key],
      focusNode: _focusNodes[key],
      initialSelection: field.value,
      enabled: _enabled(key),
      requestFocusOnTap: true,
      enableFilter: true,
      enableSearch: true,
      menuHeight: 320,
      expandedInsets: EdgeInsets.zero,
      label: Text(label),
      helperText: _helper(key),
      errorText: field.errorText,
      textInputAction: TextInputAction.next,
      dropdownMenuEntries: [
        for (final choice in _choices(key))
          DropdownMenuEntry<String>(
            value: choice.value,
            label: choice.label,
            labelWidget: Text(choice.menuLabel, softWrap: true),
          ),
      ],
      onSelected: (value) => _handleSelection(key, value, field),
    ),
  );
}

class _LocalityChoice {
  const _LocalityChoice(this.value, this.label, {this.node, String? menuLabel})
    : menuLabel = menuLabel ?? label;
  final String value, label, menuLabel;
  final PsgcNode? node;
}
