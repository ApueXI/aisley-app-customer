import '../../../core/networking/api_failure.dart';
import '../../../core/networking/wire.dart';

enum PolicyType {
  terms('terms_of_service', 'Terms of Service'),
  privacy('privacy_policy', 'Privacy Policy');

  const PolicyType(this.wire, this.label);
  final String wire, label;
  static PolicyType? fromWire(String value) {
    for (final type in values) {
      if (type.wire == value) return type;
    }
    return null;
  }
}

class PolicyVersionSummary {
  PolicyVersionSummary.parse(Object? value) {
    final wire = Wire(value);
    id = wire.uuid('id');
    version = wire.positiveInt('version');
    title = wire.string('title');
    changeSummary = wire.nullableString('change_summary');
    requiresReconsent = wire.boolean('requires_reconsent');
    publishedAt = wire.timestamp('published_at');
  }
  late final String id, title;
  late final int version;
  late final String? changeSummary;
  late final bool requiresReconsent;
  late final DateTime? publishedAt;
}

class PolicyVersion extends PolicyVersionSummary {
  PolicyVersion.parse(Object? value) : super.parse(value) {
    final wire = Wire(value);
    content = wire.string('content');
    status = wire.string('status');
  }
  late final String content, status;
}

class PublicPolicy {
  PublicPolicy.parse(Object? value) {
    final wire = Wire(value);
    type = wire.string('type');
    label = wire.string('label');
    version = PolicyVersion.parse(wire.field('version'));
  }
  late final String type, label;
  late final PolicyVersion version;
}

class PolicyHistoryVersion {
  PolicyHistoryVersion.parse(Object? value) {
    final wire = Wire(value);
    id = wire.uuid('id');
    version = wire.positiveInt('version');
    title = wire.string('title');
    status = wire.string('status');
    changeSummary = wire.nullableString('change_summary');
    publishedAt = wire.timestamp('published_at');
  }
  late final String id, title, status;
  late final int version;
  late final String? changeSummary;
  late final DateTime? publishedAt;
}

class PolicyHistory {
  PolicyHistory.parse(Object? value) {
    final wire = Wire(value);
    type = wire.string('type');
    label = wire.string('label');
    versions = wire.list('versions', PolicyHistoryVersion.parse);
  }
  late final String type, label;
  late final List<PolicyHistoryVersion> versions;
}

class AcceptedVersion {
  AcceptedVersion.parse(Object? value) {
    final wire = Wire(value);
    id = wire.uuid('id');
    version = wire.positiveInt('version');
    acceptedAt = wire.timestamp('accepted_at');
  }
  late final String id;
  late final int version;
  late final DateTime? acceptedAt;
}

class PolicyStatus {
  PolicyStatus.parse(Object? value) {
    final wire = Wire(value);
    type = wire.string('type');
    label = wire.string('label');
    required = wire.boolean('required');
    accepted = wire.boolean('accepted');
    acceptedAt = wire.timestamp('accepted_at');
    final current = wire.field('current_version'),
        previous = wire.field('accepted_version');
    currentVersion = current == null
        ? null
        : PolicyVersionSummary.parse(current);
    acceptedVersion = previous == null ? null : AcceptedVersion.parse(previous);
  }
  late final String type, label;
  late final bool required, accepted;
  late final DateTime? acceptedAt;
  late final PolicyVersionSummary? currentVersion;
  late final AcceptedVersion? acceptedVersion;
}

class ConsentStatus {
  ConsentStatus.parse(Object? value) {
    final wire = Wire(value);
    policies = wire.list('policies', PolicyStatus.parse);
    allRequiredAccepted = wire.boolean('all_required_accepted');
    // Inconsistent success cannot open protected navigation.
    if (allRequiredAccepted && policies.any((p) => p.required)) {
      throw const ApiFailure(FailureKind.decode);
    }
  }
  late final List<PolicyStatus> policies;
  late final bool allRequiredAccepted;
}

class PolicyAcceptance {
  PolicyAcceptance.parse(Object? value) {
    final wire = Wire(value);
    type = wire.string('type');
    label = wire.string('label');
    version = PolicyVersion.parse(wire.field('version'));
    acceptedAt = wire.timestamp('accepted_at');
  }
  late final String type, label;
  late final PolicyVersion version;
  late final DateTime? acceptedAt;
}
