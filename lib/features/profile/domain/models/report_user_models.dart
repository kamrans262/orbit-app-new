enum ReportReason { inappropriateContent, harassment, spam, other }

extension ReportReasonPresentation on ReportReason {
  String get label {
    switch (this) {
      case ReportReason.inappropriateContent:
        return 'Inappropriate Content';
      case ReportReason.harassment:
        return 'Harassment';
      case ReportReason.spam:
        return 'Spam';
      case ReportReason.other:
        return 'Other';
    }
  }

  String get apiValue {
    switch (this) {
      case ReportReason.inappropriateContent:
        return 'inappropriate_content';
      case ReportReason.harassment:
        return 'harassment';
      case ReportReason.spam:
        return 'spam';
      case ReportReason.other:
        return 'other';
    }
  }
}

class ReportUserArgs {
  const ReportUserArgs({
    required this.userId,
    required this.displayName,
    this.avatarUrl,
  });

  final String userId;
  final String displayName;
  final String? avatarUrl;
}

class ReportRequest {
  const ReportRequest({
    required this.reportedUserId,
    required this.reason,
    this.additionalDetails,
  });

  final String reportedUserId;
  final ReportReason reason;
  final String? additionalDetails;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'reported_user_id': reportedUserId,
      'reason': reason.apiValue,
      'additional_details': additionalDetails,
    };
  }
}
