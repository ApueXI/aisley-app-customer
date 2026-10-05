import 'dart:convert';

import 'package:flutter/services.dart';

class PsgcRegion {
  const PsgcRegion({
    required this.code,
    required this.name,
    required this.file,
  });
  final String code, name, file;

  factory PsgcRegion.fromJson(Object? json) {
    final map = _map(json);
    return PsgcRegion(
      code: _string(map['psgc_code']),
      name: _string(map['name']),
      file: _string(map['file']),
    );
  }
}

class PsgcNode {
  const PsgcNode({
    required this.code,
    required this.name,
    required this.level,
    required this.children,
  });
  final String code, name, level;
  final List<PsgcNode> children;

  factory PsgcNode.fromJson(Object? json) {
    final map = _map(json);
    final code = _string(map['psgc_code']);
    final children = map['children'];
    if (!RegExp(r'^\d{10}$').hasMatch(code) || children is! List) {
      throw const FormatException('Invalid PSGC children.');
    }
    return PsgcNode(
      code: code,
      name: _string(map['name']),
      level: _string(map['geographic_level']),
      children: List.unmodifiable(children.map(PsgcNode.fromJson)),
    );
  }
}

class PsgcDataset {
  const PsgcDataset({required this.region, required this.children});
  final PsgcNode region;
  final List<PsgcNode> children;

  void validateHierarchy() {
    if (region.level != 'region' || children.isEmpty) {
      throw const FormatException('PSGC region has no selectable localities.');
    }
    final codes = <String>{};
    void visit(PsgcNode node, PsgcNode? parent) {
      if (!codes.add(node.code)) {
        throw const FormatException('PSGC node codes must be unique.');
      }
      final allowed = switch (parent?.level) {
        null => node.level == 'region',
        'region' =>
          node.level == 'province' ||
              node.level == 'city' ||
              node.level == 'municipality',
        'province' => node.level == 'city' || node.level == 'municipality',
        'city' || 'municipality' =>
          node.level == 'barangay' || node.level == 'sub_municipality',
        'sub_municipality' => node.level == 'barangay',
        _ => false,
      };
      if (!allowed) {
        throw const FormatException('Invalid PSGC parent and child levels.');
      }
      if (node.level == 'province' &&
          !node.children.any(
            (child) => child.level == 'city' || child.level == 'municipality',
          )) {
        throw const FormatException('PSGC Province has no selectable cities.');
      }
      if ((node.level == 'city' || node.level == 'municipality') &&
          barangaysUnder(node).isEmpty) {
        throw const FormatException('PSGC city has no selectable Barangays.');
      }
      if (node.level == 'sub_municipality' && node.children.isEmpty) {
        throw const FormatException('PSGC sub-municipality has no Barangays.');
      }
      for (final child in node.children) {
        visit(child, node);
      }
    }

    visit(region, null);
    if (provinces.isEmpty && directCities.isEmpty) {
      throw const FormatException('PSGC region has no selectable localities.');
    }
  }

  List<PsgcNode> get provinces =>
      children.where((node) => node.level == 'province').toList();
  List<PsgcNode> get directCities => children
      .where((node) => node.level == 'city' || node.level == 'municipality')
      .toList();
  List<PsgcNode> barangaysUnder(PsgcNode city) {
    final result = <PsgcNode>[];
    void visit(PsgcNode node) {
      if (node.level == 'barangay') result.add(node);
      for (final child in node.children) {
        visit(child);
      }
    }

    for (final child in city.children) {
      visit(child);
    }
    return List.unmodifiable(result);
  }

  List<PsgcNode> citiesUnder(PsgcNode? province) {
    final source = province?.children ?? children;
    return source
        .where((node) => node.level == 'city' || node.level == 'municipality')
        .toList();
  }
}

class PsgcLoader {
  PsgcLoader({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;
  final AssetBundle _bundle;
  List<PsgcRegion>? _regions;
  final _datasets = <String, PsgcDataset>{};

  Future<List<PsgcRegion>> regions() async {
    if (_regions != null) return _regions!;
    final decoded = jsonDecode(
      await _bundle.loadString('assets/psgc/list-of-all-regions.json'),
    );
    if (decoded is! List || decoded.length != _allowedRegionalFiles.length) {
      throw const FormatException('Invalid or incomplete PSGC index.');
    }
    final regions = decoded.map(PsgcRegion.fromJson).toList(growable: false);
    if (regions.map((region) => region.code).toSet().length != regions.length ||
        regions.map((region) => region.file).toSet().length != regions.length ||
        regions.any(
          (region) =>
              !_allowedRegionalFiles.contains(region.file) ||
              !RegExp(r'^\d{10}$').hasMatch(region.code) ||
              region.name.trim().isEmpty ||
              !region.file.startsWith('${region.code}-'),
        )) {
      throw const FormatException('Invalid or incomplete PSGC index.');
    }
    _regions = List.unmodifiable(regions);
    return _regions!;
  }

  Future<PsgcDataset> dataset(PsgcRegion region) async {
    if (!_allowedRegionalFiles.contains(region.file) ||
        !RegExp(r'^\d{10}$').hasMatch(region.code)) {
      throw const FormatException('Unsupported PSGC region asset.');
    }
    final existing = _datasets[region.code];
    if (existing != null) return existing;
    final decoded = jsonDecode(
      await _bundle.loadString('assets/psgc/${region.file}'),
    );
    final root = _map(decoded);
    final regionJson = root['region'];
    final node = PsgcNode.fromJson(regionJson);
    if (node.level != 'region' || node.code != region.code) {
      throw const FormatException('PSGC region does not match the index.');
    }
    final dataset = PsgcDataset(region: node, children: node.children);
    dataset.validateHierarchy();
    _datasets[region.code] = dataset;
    return dataset;
  }
}

Map<String, dynamic> _map(Object? value) {
  if (value is Map<String, dynamic>) return value;
  throw const FormatException('Invalid PSGC object.');
}

String _string(Object? value) {
  if (value is String && value.trim().isNotEmpty) return value;
  throw const FormatException('Invalid PSGC string.');
}

const _allowedRegionalFiles = <String>{
  '0100000000-region-i-ilocos-region/addresses.json',
  '0200000000-region-ii-cagayan-valley/addresses.json',
  '0300000000-region-iii-central-luzon/addresses.json',
  '0400000000-region-iv-a-calabarzon/addresses.json',
  '0500000000-region-v-bicol-region/addresses.json',
  '0600000000-region-vi-western-visayas/addresses.json',
  '0700000000-region-vii-central-visayas/addresses.json',
  '0800000000-region-viii-eastern-visayas/addresses.json',
  '0900000000-region-ix-zamboanga-peninsula/addresses.json',
  '1000000000-region-x-northern-mindanao/addresses.json',
  '1100000000-region-xi-davao-region/addresses.json',
  '1200000000-region-xii-soccsksargen/addresses.json',
  '1300000000-national-capital-region-ncr/addresses.json',
  '1400000000-cordillera-administrative-region-car/addresses.json',
  '1600000000-region-xiii-caraga/addresses.json',
  '1700000000-mimaropa-region/addresses.json',
  '1800000000-negros-island-region-nir/addresses.json',
  '1900000000-bangsamoro-autonomous-region-in-muslim-mindanao-barmm/addresses.json',
};
