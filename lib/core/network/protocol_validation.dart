const int kMaxProtocolPayloadBytes = 64 * 1024;
const int kMaxProtocolIdentifierLength = 128;
const int kMaxProtocolDisplayNameLength = 80;
const int kMaxProtocolDeviceLabelLength = 80;
const int kMaxProtocolFingerprintLength = 32;
const int kMaxProtocolTextLength = 4000;
const int kMaxProtocolRequestMessageLength = 280;
const int kMaxProtocolGroupTitleLength = 80;

bool isValidProtocolIdentifier(String? value) {
  final normalized = value?.trim();
  return normalized != null &&
      normalized.isNotEmpty &&
      normalized.length <= kMaxProtocolIdentifierLength;
}

bool isValidProtocolDisplayName(String? value) {
  final normalized = value?.trim();
  return normalized != null &&
      normalized.isNotEmpty &&
      normalized.length <= kMaxProtocolDisplayNameLength;
}

bool isValidOptionalProtocolText(String? value, {required int maxLength}) {
  if (value == null) return true;
  return value.trim().length <= maxLength;
}

bool isValidProtocolPort(int? value) {
  return value != null && value >= 1 && value <= 65535;
}
