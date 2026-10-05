import 'package:flutter/material.dart';

import '../../../core/ui/form_page.dart';
import '../data/psgc_loader.dart';

class PsgcFields extends StatefulWidget {
  const PsgcFields({
    super.key,
    required this.onChange,
    this.initialValues = const {},
    this.fieldErrors = const {},
    this.loader,
  });
  final void Function(Map<String, String>) onChange;
  final Map<String, String> initialValues;
  final Map<String, String> fieldErrors;
  final PsgcLoader? loader;

  @override
  State<PsgcFields> createState() => _PsgcFieldsState();
}

class _PsgcFieldsState extends State<PsgcFields> {
  late final _loader = widget.loader ?? PsgcLoader();
  late final Map<String, String> _values = {
    for (final key in _localityKeys) key: widget.initialValues[key] ?? '',
  };
  List<PsgcRegion> _regions = const [];
  PsgcRegion? _region;
  PsgcDataset? _dataset;
  PsgcNode? _province, _city;
  bool _loading = false;
  String? _error;
  int _epoch = 0;

  static const _localityKeys = [
    'region',
    'province',
    'city_municipality',
    'barangay',
  ];

  @override
  void initState() {
    super.initState();
    _loadInitialOptions();
  }

  bool _sameValues(Map<String, String> left, Map<String, String> right) =>
      _localityKeys.every((key) => left[key] == right[key]);

  Future<void> _loadInitialOptions() async {
    final epoch = ++_epoch;
    final initialRegionName = _values['region']!;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final regions = await _loader.regions();
      if (!mounted || epoch != _epoch) return;
      _regions = regions;
      final region = _values['region'] == initialRegionName
          ? _matchRegion(initialRegionName)
          : null;
      _region = region;
      if (region != null) {
        final dataset = await _loader.dataset(region);
        if (!mounted || epoch != _epoch) return;
        _dataset = dataset;
        _province = _matchNode(dataset.provinces, _values['province']!);
        _city = _matchNode(
          dataset.citiesUnder(_province),
          _values['city_municipality']!,
        );
      }
    } catch (_) {
      if (mounted && epoch == _epoch) {
        _error = 'Offline address suggestions are unavailable. Enter each locality manually.';
      }
    } finally {
      if (mounted && epoch == _epoch) {
        setState(() => _loading = false);
      }
    }
  }

  PsgcRegion? _matchRegion(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized.isEmpty) return null;
    for (final region in _regions) {
      if (region.name.trim().toLowerCase() == normalized) return region;
    }
    return null;
  }

  PsgcNode? _matchNode(Iterable<PsgcNode> nodes, String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized.isEmpty) return null;
    for (final node in nodes) {
      if (node.name.trim().toLowerCase() == normalized) return node;
    }
    return null;
  }

  List<String> _suggestions(String key, String query) {
    Iterable<String> source = const [];
    if (key == 'region') {
      source = _regions.map((region) => region.name);
    } else if (key == 'province' && _dataset != null) {
      source = _dataset!.provinces.map((node) => node.name);
      if (_region?.code == '1300000000') {
        source = [...source, 'National Capital Region (NCR)'];
      }
    } else if (key == 'city_municipality' && _dataset != null) {
      source = _dataset!.citiesUnder(_province).map((node) => node.name);
    } else if (key == 'barangay' && _city != null && _dataset != null) {
      source = _dataset!.barangaysUnder(_city!).map((node) => node.name);
    }
    final normalized = query.trim().toLowerCase();
    return source
        .where(
          (value) =>
              normalized.isEmpty || value.toLowerCase().contains(normalized),
        )
        .toList(growable: false);
  }

  void _typed(String key, String value) {
    if (_values[key] == value) return;
    final changingRegion = key == 'region' && _regions.isNotEmpty;
    if (changingRegion) _epoch++;
    setState(() {
      if (changingRegion) {
        _loading = false;
        _error = null;
      }
      _values[key] = value;
      if (key == 'region' &&
          _region?.name.trim().toLowerCase() != value.trim().toLowerCase()) {
        _region = null;
        _dataset = null;
        _province = null;
        _city = null;
        _values['province'] = '';
        _values['city_municipality'] = '';
        _values['barangay'] = '';
      } else if (key == 'province' &&
          _province?.name.trim().toLowerCase() != value.trim().toLowerCase()) {
        _province = null;
        _city = null;
        _values['city_municipality'] = '';
        _values['barangay'] = '';
      } else if (key == 'city_municipality' &&
          _city?.name.trim().toLowerCase() != value.trim().toLowerCase()) {
        _city = null;
        _values['barangay'] = '';
      }
    });
    widget.onChange(Map.unmodifiable(_values));
  }

  Future<void> _selected(String key, String value) async {
    final before = Map<String, String>.of(_values);
    setState(() {
      _values[key] = value;
      if (key == 'region') {
        _region = _matchRegion(value);
        _dataset = null;
        _province = null;
        _city = null;
        _values['province'] = '';
        _values['city_municipality'] = '';
        _values['barangay'] = '';
      } else if (key == 'province') {
        _province = _matchNode(_dataset?.provinces ?? const [], value);
        _city = null;
        _values['city_municipality'] = '';
        _values['barangay'] = '';
      } else if (key == 'city_municipality') {
        _city = _matchNode(_dataset?.citiesUnder(_province) ?? const [], value);
        _values['barangay'] = '';
      }
    });
    widget.onChange(Map.unmodifiable(_values));
    if (key == 'region' && _region != null) await _loadDataset(_region!);
    if (!_sameValues(before, _values)) setState(() {});
  }

  Future<void> _loadDataset(PsgcRegion region) async {
    final epoch = ++_epoch;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final dataset = await _loader.dataset(region);
      if (mounted && epoch == _epoch) setState(() => _dataset = dataset);
    } catch (_) {
      if (mounted && epoch == _epoch) {
        setState(
          () => _error = 'This region’s offline suggestions are unavailable. Enter the locality manually.',
        );
      }
    } finally {
      if (mounted && epoch == _epoch) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children:
        [
              const Text('Locality'),
              const Text(
                'Type a locality or choose a filtered offline suggestion.',
              ),
              if (_loading)
                const LinearProgressIndicator(
                  semanticsLabel: 'Loading offline address suggestions',
                ),
              if (_error != null) ...[
                Text(_error!),
                TextButton(
                  onPressed: _loadInitialOptions,
                  child: const Text('Retry suggestions'),
                ),
              ],
              _field('region', 'Region'),
              _field('province', 'Province'),
              _field('city_municipality', 'City / Municipality'),
              _field('barangay', 'Barangay'),
            ]
            .map(
              (child) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: child,
              ),
            )
            .toList(),
  );

  Widget _field(String key, String label) => Autocomplete<String>(
    key: ValueKey(
      'psgc-$key-${_region?.code}-${_province?.code}-${_city?.code}',
    ),
    initialValue: TextEditingValue(text: _values[key] ?? ''),
    optionsBuilder: (value) => _suggestions(key, value.text),
    onSelected: (value) => _selected(key, value),
    fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) =>
        TextFormField(
          controller: controller,
          focusNode: focusNode,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(labelText: label),
          onChanged: (value) => _typed(key, value),
          validator: (value) => requiredText(value) ?? widget.fieldErrors[key],
        ),
  );
}
