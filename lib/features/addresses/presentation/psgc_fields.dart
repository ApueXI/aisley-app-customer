import 'package:flutter/material.dart';

import '../data/psgc_loader.dart';

class PsgcFields extends StatefulWidget {
  const PsgcFields({super.key, required this.onChange, this.loader});
  final void Function(Map<String, String>) onChange;
  final PsgcLoader? loader;

  @override
  State<PsgcFields> createState() => _PsgcFieldsState();
}

class _PsgcFieldsState extends State<PsgcFields> {
  late final _loader = widget.loader ?? PsgcLoader();
  List<PsgcRegion> _regions = const [];
  PsgcRegion? _region;
  PsgcDataset? _dataset;
  PsgcNode? _province, _city, _barangay;
  bool _loading = false;
  String? _error;
  int _epoch = 0;

  @override
  void initState() {
    super.initState();
    _loadRegions();
  }

  Future<void> _loadRegions() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final regions = await _loader.regions();
      if (mounted) setState(() => _regions = regions);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Address selectors are unavailable. Enter the locality fields below manually.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _chooseRegion(PsgcRegion? region) async {
    final epoch = ++_epoch;
    setState(() {
      _region = region;
      _dataset = null;
      _province = null;
      _city = null;
      _barangay = null;
      _error = null;
      _loading = region != null;
    });
    widget.onChange({
      'region': region?.name ?? '',
      'province': '',
      'city_municipality': '',
      'barangay': '',
    });
    if (region == null) return;
    try {
      final dataset = await _loader.dataset(region);
      if (mounted && epoch == _epoch) setState(() => _dataset = dataset);
    } catch (_) {
      if (mounted && epoch == _epoch) {
        setState(
          () => _error = 'This region’s selectors are unavailable. Enter its locality fields manually.',
        );
      }
    } finally {
      if (mounted && epoch == _epoch) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dataset = _dataset;
    final cities = dataset?.citiesUnder(_province) ?? const <PsgcNode>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children:
          [
                const Text('Optional offline address selectors'),
                const Text('Review the locality names below before saving.'),
                if (_loading)
                  const LinearProgressIndicator(
                    semanticsLabel: 'Loading offline address options',
                  ),
                if (_error != null) ...[
                  Text(_error!),
                  TextButton(
                    onPressed: _region == null
                        ? _loadRegions
                        : () => _chooseRegion(_region),
                    child: const Text('Retry selectors'),
                  ),
                ],
                if (_regions.isNotEmpty)
                  DropdownButtonFormField<PsgcRegion>(
                    initialValue: _region,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Select region',
                    ),
                    items: [
                      for (final region in _regions)
                        DropdownMenuItem(
                          value: region,
                          child: Text(region.name),
                        ),
                    ],
                    onChanged: _chooseRegion,
                  ),
                if (dataset != null && dataset.provinces.isNotEmpty)
                  DropdownButtonFormField<PsgcNode>(
                    key: ValueKey(
                      'province:${_region?.code}:${_province?.code}',
                    ),
                    initialValue: _province,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Select province',
                    ),
                    items: [
                      if (dataset.directCities.isNotEmpty)
                        const DropdownMenuItem(
                          value: null,
                          child: Text('Direct regional city / municipality'),
                        ),
                      for (final province in dataset.provinces)
                        DropdownMenuItem(
                          value: province,
                          child: Text(province.name),
                        ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _province = value;
                        _city = null;
                        _barangay = null;
                      });
                      widget.onChange({
                        'province': value?.name ?? '',
                        'city_municipality': '',
                        'barangay': '',
                      });
                    },
                  ),
                if (dataset != null &&
                    _province == null &&
                    dataset.directCities.isNotEmpty) ...[
                  const Text(
                    'This city has no selected Province node. Review the required Province text below.',
                  ),
                  if (_region?.code == '1300000000')
                    TextButton(
                      onPressed: () => widget.onChange({
                        'province': 'National Capital Region (NCR)',
                      }),
                      child: const Text(
                        'Use NCR compatibility text for Province',
                      ),
                    ),
                ],
                if (cities.isNotEmpty)
                  DropdownButtonFormField<PsgcNode>(
                    key: ValueKey(
                      'city:${_region?.code}:${_province?.code}:${_city?.code}',
                    ),
                    initialValue: _city,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Select city / municipality',
                    ),
                    items: [
                      for (final city in cities)
                        DropdownMenuItem(value: city, child: Text(city.name)),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _city = value;
                        _barangay = null;
                      });
                      widget.onChange({
                        'city_municipality': value?.name ?? '',
                        'barangay': '',
                      });
                    },
                  ),
                if (_city != null && dataset != null)
                  DropdownButtonFormField<PsgcNode>(
                    key: ValueKey('barangay:${_city?.code}:${_barangay?.code}'),
                    initialValue: _barangay,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Select barangay',
                    ),
                    items: [
                      for (final barangay in dataset.barangaysUnder(_city!))
                        DropdownMenuItem(
                          value: barangay,
                          child: Text(barangay.name),
                        ),
                    ],
                    onChanged: (value) {
                      setState(() => _barangay = value);
                      widget.onChange({'barangay': value?.name ?? ''});
                    },
                  ),
              ]
              .map(
                (child) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: child,
                ),
              )
              .toList(),
    );
  }
}
